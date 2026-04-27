import 'package:flutter/foundation.dart';
import '../models/fixture.dart';
import '../models/fixture_event.dart';
import '../models/h2h_entry.dart';
import '../models/match_statistics.dart';
import '../models/sport.dart';
import '../models/standing_row.dart';
import '../services/api/espn_standings_client.dart';
import '../services/api/sport_api_factory.dart';
import 'fixtures_provider.dart';

class FixtureDetailProvider extends ChangeNotifier {
  final SportApiFactory _apiFactory;

  FixtureDetailProvider(this._apiFactory);

  LoadingState _state = LoadingState.idle;
  String? _errorMessage;
  Fixture? _fixture;
  List<FixtureEvent> _events = [];
  MatchStatistics? _stats;
  List<H2HEntry> _h2h = [];
  List<StandingRow> _standings = [];
  String? _standingsSeason;

  LoadingState get state => _state;
  String? get errorMessage => _errorMessage;
  Fixture? get fixture => _fixture;
  List<FixtureEvent> get events => _events;
  MatchStatistics? get stats => _stats;
  List<H2HEntry> get h2h => _h2h;
  List<StandingRow> get standings => _standings;
  String? get standingsSeason => _standingsSeason;

  Future<void> fetchDetail(SportType sport, int fixtureId, {Fixture? initialFixture}) async {
    // Reset previous fixture's data so the UI doesn't show stale info
    _fixture = initialFixture;
    _events = [];
    _stats = null;
    _h2h = [];
    _standings = [];
    _standingsSeason = null;
    _errorMessage = null;
    _state = LoadingState.loading;
    notifyListeners();
    try {
      switch (sport) {
        case SportType.football:
          _fixture = await _apiFactory.football.getFixtureById(fixtureId);
          List<FixtureEvent> apiEvents = [];
          try {
            apiEvents = await _apiFactory.football.getFixtureEvents(fixtureId);
          } catch (e) {
            debugPrint('Football: API-Sports events error: $e');
          }
          if (apiEvents.isNotEmpty) {
            _events = apiEvents;
          } else {
            debugPrint('Football: No API-Sports events, trying SportsAPIPro...');
            try {
              _events = await _apiFactory.sportsApiPro.getIncidents(_fixture!, sport);
              debugPrint('Football: SportsAPIPro returned ${_events.length} events');
            } catch (e) {
              debugPrint('Football: SportsAPIPro error: $e');
              _events = [];
            }
          }
        case SportType.basketball:
          _fixture = await _apiFactory.basketball.getGameById(fixtureId);
          _events = await _fetchEventsWithFallback(_fixture!, sport);
        case SportType.hockey:
          _fixture = await _apiFactory.hockey.getGameById(fixtureId);
          _events = await _fetchEventsWithFallback(_fixture!, sport);
        case SportType.baseball:
          _fixture = await _apiFactory.baseball.getGameById(fixtureId);
          _events = await _fetchEventsWithFallback(_fixture!, sport);
        case SportType.formula1:
          _fixture = await _apiFactory.formula1.getRaceById(fixtureId);
          try {
            debugPrint('F1: ${_fixture!.league.name} - ${_fixture!.awayTeam.name}');
            _events = await _apiFactory.formula1.getF1EventsFromFixture(_fixture!);
            debugPrint('F1: Loaded ${_events.length} events');
          } catch (e) {
            debugPrint('F1: Error fetching events: $e');
            _events = [];
          }
        case SportType.handball:
          _fixture = await _apiFactory.handball.getGameById(fixtureId);
          _events = await _fetchEventsWithFallback(_fixture!, sport);
        case SportType.tennis:
          // Tennis has no API-Sports endpoint; use the initial fixture passed in
          _fixture = initialFixture;
          if (_fixture != null) {
            try {
              _events = await _apiFactory.sportsApiPro.getIncidents(_fixture!, sport);
            } catch (e) {
              debugPrint('Tennis: SportsAPIPro error: $e');
              _events = [];
            }
          }
      }
      _state = LoadingState.loaded;
      notifyListeners();

      // Fetch supplementary data (stats / H2H / standings) in parallel
      // after the main load. Each is best-effort — failures are logged
      // and the rest of the UI keeps working.
      if (_fixture != null) {
        unawaited(_fetchSupplementary(sport, fixtureId, _fixture!));
      }
    } catch (e) {
      _state = LoadingState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> _fetchSupplementary(
      SportType sport, int fixtureId, Fixture fixture) async {
    Future<void> safe(String label, Future<void> Function() task) async {
      try {
        await task();
      } catch (e) {
        debugPrint('$label error: $e');
      }
    }

    final futures = <Future<void>>[];

    switch (sport) {
      case SportType.football:
        futures.add(safe('Football stats', () async {
          final s = await _apiFactory.football.getFixtureStatistics(fixtureId);
          if (s.isNotEmpty) _stats = s;
        }));
        futures.add(safe('Football h2h', () async {
          _h2h = await _apiFactory.football
              .getHeadToHead(fixture.homeTeam.id, fixture.awayTeam.id);
        }));
        // Free plan covers 2022-2024 only — try current then fall back.
        final preferred = fixture.league.currentSeason ?? fixture.date.year;
        final seasonsToTry = <int>{preferred, 2024, 2023, 2022}.toList();
        futures.add(safe('Football standings', () async {
          // Try ESPN first — free, current season, no plan limits.
          if (EspnStandingsClient.footballSlug(fixture.league.id) != null) {
            try {
              final espn = await _apiFactory.espnStandings
                  .getFootballStandings(fixture.league.id);
              if (espn.isNotEmpty) {
                _standings = espn;
                _standingsSeason = 'current';
                return;
              }
            } catch (_) {/* fall through to API-Sports */}
          }
          // Fallback: API-Sports (limited to 2022-2024 on free plan).
          for (final s in seasonsToTry) {
            try {
              final list = await _apiFactory.football
                  .getStandings(fixture.league.id, s);
              if (list.isNotEmpty) {
                _standings = list;
                _standingsSeason = '$s/${(s + 1) % 100}';
                return;
              }
            } catch (_) {/* try next */}
          }
        }));
      case SportType.basketball:
        final baseYear = fixture.league.currentSeason ?? fixture.date.year;
        // Free plan supports older seasons only — try current first, fall back.
        final seasons = <String>{
          '$baseYear-${baseYear + 1}',
          '${baseYear - 1}-$baseYear',
          '2024-2025',
          '2023-2024',
          '2022-2023',
        }.toList();
        futures.add(safe('Basketball stats', () async {
          final s = await _apiFactory.basketball.getGameStatistics(fixtureId);
          if (s.isNotEmpty) _stats = s;
        }));
        futures.add(safe('Basketball standings', () async {
          // ESPN NBA standings — free, current season.
          final leagueName = fixture.league.name.toLowerCase();
          if (leagueName.contains('nba') && !leagueName.contains('summer')) {
            try {
              final espn = await _apiFactory.espnStandings.getNbaStandings();
              if (espn.isNotEmpty) {
                _standings = espn;
                _standingsSeason = 'current';
                return;
              }
            } catch (_) {/* fall through */}
          }
          // Fallback: API-Sports (free plan covers older seasons only).
          for (final s in seasons) {
            try {
              final list = await _apiFactory.basketball
                  .getStandings(fixture.league.id, s);
              if (list.isNotEmpty) {
                _standings = list;
                _standingsSeason = s;
                return;
              }
            } catch (_) {/* try next */}
          }
        }));
        futures.add(safe('Basketball h2h', () async {
          final list = await _apiFactory.basketball.getHeadToHead(
              fixture.homeTeam.id, fixture.awayTeam.id);
          _h2h = list.take(10).toList();
        }));
      case SportType.baseball:
        futures.add(safe('Baseball stats', () async {
          final s = await _apiFactory.baseball.getGameStatistics(fixtureId);
          if (s.isNotEmpty) _stats = s;
        }));
        futures.add(safe('Baseball standings', () async {
          final leagueName = fixture.league.name.toLowerCase();
          if (leagueName.contains('mlb') ||
              leagueName.contains('major league')) {
            try {
              final espn = await _apiFactory.espnStandings.getMlbStandings();
              if (espn.isNotEmpty) {
                _standings = espn;
                _standingsSeason = 'current';
                return;
              }
            } catch (_) {/* fall through */}
          }
          _standings = await _apiFactory.baseball
              .getStandings(fixture.league.id, fixture.date.year);
        }));
      case SportType.hockey:
        futures.add(safe('Hockey stats', () async {
          final s = await _apiFactory.hockey.getGameStatistics(fixtureId);
          if (s.isNotEmpty) _stats = s;
        }));
        futures.add(safe('Hockey standings', () async {
          final leagueName = fixture.league.name.toLowerCase();
          if (leagueName.contains('nhl')) {
            try {
              final espn = await _apiFactory.espnStandings.getNhlStandings();
              if (espn.isNotEmpty) {
                _standings = espn;
                _standingsSeason = 'current';
                return;
              }
            } catch (_) {/* fall through */}
          }
          _standings = await _apiFactory.hockey
              .getStandings(fixture.league.id, fixture.date.year);
        }));
      case SportType.handball:
        futures.add(safe('Handball stats', () async {
          final s = await _apiFactory.handball.getGameStatistics(fixtureId);
          if (s.isNotEmpty) _stats = s;
        }));
        futures.add(safe('Handball standings', () async {
          _standings = await _apiFactory.handball
              .getStandings(fixture.league.id, fixture.date.year);
        }));
      case SportType.formula1:
      case SportType.tennis:
        // No supplementary endpoints supported.
        break;
    }

    await Future.wait(futures);
    notifyListeners();
  }

  /// Try the original free API first, then fall back to SportsAPIPro.
  Future<List<FixtureEvent>> _fetchEventsWithFallback(
      Fixture fixture, SportType sport) async {
    final sportName = sport.name;
    debugPrint('$sportName: ${fixture.homeTeam.name} vs ${fixture.awayTeam.name}');

    // 1. Try the original free API first
    List<FixtureEvent> events = [];
    try {
      events = switch (sport) {
        SportType.basketball =>
          await _apiFactory.basketball.getPlayByPlayFromFixture(fixture),
        SportType.hockey =>
          await _apiFactory.hockey.getPlayByPlayFromFixture(fixture),
        SportType.baseball =>
          await _apiFactory.baseball.getPlayByPlayFromFixture(fixture),
        _ => <FixtureEvent>[],
      };
      debugPrint('$sportName: Free API returned ${events.length} events');
    } catch (e) {
      debugPrint('$sportName: Free API error: $e');
    }

    // 2. If free API returned events, use them
    if (events.isNotEmpty) return events;

    // 3. Fall back to SportsAPIPro
    debugPrint('$sportName: Trying SportsAPIPro fallback...');
    try {
      events = await _apiFactory.sportsApiPro.getIncidents(fixture, sport);
      debugPrint('$sportName: SportsAPIPro returned ${events.length} events');
    } catch (e) {
      debugPrint('$sportName: SportsAPIPro error: $e');
    }

    return events;
  }

  void clear() {
    _fixture = null;
    _events = [];
    _stats = null;
    _h2h = [];
    _standings = [];
    _state = LoadingState.idle;
    notifyListeners();
  }
}

void unawaited(Future<void> future) {
  // Intentionally fire-and-forget; errors are caught inside.
}
