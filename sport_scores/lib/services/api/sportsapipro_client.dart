import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/fixture.dart';
import '../../models/fixture_event.dart';
import '../../models/sport.dart';
import '../../utils/team_matching.dart';

/// Client for SportsAPIPro V2 API — provides play-by-play incidents
/// for basketball, hockey, baseball, and football across ALL leagues.
class SportsApiProClient {
  final http.Client _client = http.Client();
  static const _apiKey = '3d662fb3-8f17-4291-ba83-a168a0d728f3';

  // In-memory cache of schedule responses. The free API has a tight daily
  // quota (~100 req/day per sport) so we must not re-fetch the same
  // `/schedule/{date}` url for every fixture detail the user opens.
  static final Map<String, _CachedResponse> _cache = {};
  static const _cacheTtl = Duration(minutes: 5);

  /// Sport slug used in the V2 API subdomain.
  static String _sportSlug(SportType sport) {
    return switch (sport) {
      SportType.football => 'football',
      SportType.basketball => 'basketball',
      SportType.hockey => 'hockey',
      SportType.baseball => 'baseball',
      SportType.formula1 => 'motorsport',
      SportType.tennis => 'tennis',
      SportType.handball => 'handball',
    };
  }

  /// Base URL for a given sport.
  static String _baseUrl(SportType sport) =>
      'https://v2.${_sportSlug(sport)}.sportsapipro.com/api';

  /// Generic GET request with API key header. Retries on 503/429 up to 3 attempts.
  /// Caches responses (both success and failure) for `_cacheTtl` so we don't
  /// re-hit the same URL within a short window — critical for the tight daily
  /// quota on `/schedule/{date}`.
  Future<Map<String, dynamic>?> _get(String url, {int attempt = 1}) async {
    // Serve from cache if fresh
    final cached = _cache[url];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    try {
      final response = await _client
          .get(Uri.parse(url), headers: {'x-api-key': _apiKey})
          .timeout(const Duration(seconds: 10));

      // Retry on transient server errors
      if ((response.statusCode == 503 || response.statusCode == 429) &&
          attempt < 3) {
        final delay = Duration(milliseconds: 500 * attempt);
        debugPrint(
            'SportsAPIPro: HTTP ${response.statusCode}, retrying in ${delay.inMilliseconds}ms (attempt $attempt)');
        await Future.delayed(delay);
        return _get(url, attempt: attempt + 1);
      }

      if (response.statusCode != 200) {
        debugPrint('SportsAPIPro: HTTP ${response.statusCode} for $url');
        // Cache the negative result briefly so we don't hammer on failures.
        _cache[url] = _CachedResponse(null, DateTime.now().add(_cacheTtl));
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        debugPrint('SportsAPIPro: API error: ${data['error']}');
        _cache[url] = _CachedResponse(null, DateTime.now().add(_cacheTtl));
        return null;
      }
      final payload = data['data'] as Map<String, dynamic>?;
      _cache[url] = _CachedResponse(payload, DateTime.now().add(_cacheTtl));
      return payload;
    } catch (e) {
      debugPrint('SportsAPIPro: Error fetching $url: $e');
      return null;
    }
  }

  /// Look up the SportsAPIPro event ID for an API-Sports fixture
  /// by matching team names from the schedule for that date.
  Future<int?> _lookupEventId(Fixture fixture, SportType sport) async {
    final base = _baseUrl(sport);
    final fixHome = fixture.homeTeam.name;
    final fixAway = fixture.awayTeam.name;

    debugPrint('SportsAPIPro: Looking up $fixHome vs $fixAway');

    for (final date in TeamMatching.datesToTry(fixture.date)) {
      final dateStr = TeamMatching.formatDate(date);
      final data = await _get('$base/schedule/$dateStr');
      if (data == null) continue;

      final events = data['events'] as List? ?? [];
      for (final e in events) {
        if (e is! Map<String, dynamic>) continue;
        final home = e['homeTeam']?['name'] as String? ?? '';
        final away = e['awayTeam']?['name'] as String? ?? '';

        if (TeamMatching.teamsMatch(fixHome, home) &&
            TeamMatching.teamsMatch(fixAway, away)) {
          final id = e['id'] as int?;
          debugPrint('SportsAPIPro: Matched! ID=$id ($home vs $away)');
          return id;
        }
      }
    }

    debugPrint('SportsAPIPro: No match found for $fixHome vs $fixAway');
    return null;
  }

  /// Fetch fixtures for a date (used for sports without API-Sports, e.g., tennis).
  Future<List<Fixture>> getFixturesByDate(SportType sport, DateTime date) async {
    final base = _baseUrl(sport);
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final data = await _get('$base/schedule/$dateStr');
    if (data == null) return [];

    final events = data['events'] as List? ?? [];
    return events
        .whereType<Map<String, dynamic>>()
        .map((e) => Fixture.fromSportsApiProJson(e, sport))
        .toList();
  }

  /// Fetch live fixtures (used for sports without API-Sports).
  Future<List<Fixture>> getLiveFixtures(SportType sport) async {
    final base = _baseUrl(sport);
    final data = await _get('$base/live');
    if (data == null) return [];

    final events = data['events'] as List? ?? [];
    return events
        .whereType<Map<String, dynamic>>()
        .map((e) => Fixture.fromSportsApiProJson(e, sport))
        .toList();
  }

  /// Fetch play-by-play incidents for a fixture.
  /// Returns empty list if no incidents found.
  Future<List<FixtureEvent>> getIncidents(
      Fixture fixture, SportType sport) async {
    // Don't use for F1
    if (sport == SportType.formula1) return [];

    // Tennis uses a completely different endpoint (point-by-point) and
    // incident structure, so route it separately.
    if (sport == SportType.tennis) {
      return getTennisPointByPoint(fixture);
    }

    final eventId = await _lookupEventId(fixture, sport);
    if (eventId == null || eventId == 0) return [];

    final base = _baseUrl(sport);
    final data = await _get('$base/match/$eventId/incidents');
    if (data == null) return [];

    final incidents = data['incidents'] as List? ?? [];
    debugPrint(
        'SportsAPIPro: ${incidents.length} incidents for event $eventId');

    final events = <FixtureEvent>[];
    for (final inc in incidents) {
      if (inc is! Map<String, dynamic>) continue;
      final event = _parseIncident(inc, sport);
      if (event != null) events.add(event);
    }

    return events;
  }

  /// Fetch tennis point-by-point data. Tennis has no `/incidents` endpoint.
  /// Returns one FixtureEvent per game, grouped under period headers per set.
  Future<List<FixtureEvent>> getTennisPointByPoint(Fixture fixture) async {
    final base = _baseUrl(SportType.tennis);
    final data = await _get('$base/match/${fixture.id}/point-by-point');
    if (data == null) return [];

    final pbp = data['pointByPoint'] as List? ?? [];
    final events = <FixtureEvent>[];

    // The API returns sets in reverse order (latest first). Walk chronologically.
    final sortedSets = pbp.whereType<Map<String, dynamic>>().toList()
      ..sort((a, b) => ((a['set'] as int?) ?? 0).compareTo((b['set'] as int?) ?? 0));

    for (final setData in sortedSets) {
      final setNum = setData['set'] as int? ?? 0;
      final games = (setData['games'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) => ((a['game'] as int?) ?? 0).compareTo((b['game'] as int?) ?? 0));

      // Period header for the set, with final set score if available.
      final lastGame = games.isNotEmpty ? games.last : null;
      final setScore = lastGame != null
          ? '${lastGame['score']?['homeScore'] ?? ''} - ${lastGame['score']?['awayScore'] ?? ''}'
          : '';
      events.add(FixtureEvent(
        elapsed: setNum,
        type: 'Period',
        detail: 'Set $setNum',
        comments: setScore,
      ));

      for (final game in games) {
        final gameNum = game['game'] as int? ?? 0;
        final score = game['score'] as Map<String, dynamic>?;
        final homeScore = score?['homeScore'];
        final awayScore = score?['awayScore'];
        final serving = score?['serving'] as int?;
        final serverLabel = serving == 1
            ? fixture.homeTeam.name
            : serving == 2
                ? fixture.awayTeam.name
                : null;
        events.add(FixtureEvent(
          elapsed: setNum,
          type: 'Game',
          detail: 'Game $gameNum${serverLabel != null ? ' · serve: $serverLabel' : ''}',
          comments: '$homeScore - $awayScore',
        ));
      }
    }

    return events;
  }

  /// Parse a single incident into a FixtureEvent.
  FixtureEvent? _parseIncident(Map<String, dynamic> inc, SportType sport) {
    final incType = inc['incidentType'] as String? ?? '';

    if (incType == 'period') {
      return _parsePeriodIncident(inc, sport);
    } else if (incType == 'goal') {
      return _parseGoalIncident(inc, sport);
    } else if (incType == 'suspension') {
      return _parseSuspensionIncident(inc);
    } else if (incType == 'substitution') {
      return _parseSubstitutionIncident(inc);
    } else if (incType == 'card') {
      return _parseCardIncident(inc);
    } else if (incType == 'varDecision') {
      return _parseVarIncident(inc);
    }

    return null;
  }

  FixtureEvent _parsePeriodIncident(
      Map<String, dynamic> inc, SportType sport) {
    final text = inc['text'] as String? ?? '';
    return FixtureEvent(
      elapsed: inc['time'] as int?,
      type: 'Period',
      detail: text,
      comments:
          '${inc['homeScore'] ?? ''} - ${inc['awayScore'] ?? ''}',
    );
  }

  FixtureEvent _parseGoalIncident(
      Map<String, dynamic> inc, SportType sport) {
    final from = inc['from'] as String? ?? '';
    final player = inc['player'] as Map<String, dynamic>?;
    final playerName = player?['shortName'] as String? ??
        player?['name'] as String?;
    final isHome = inc['isHome'] as bool? ?? false;
    final homeScore = inc['homeScore'];
    final awayScore = inc['awayScore'];
    final time = inc['time'] as int?;

    // Determine display type based on sport and shot type
    final String displayType;
    if (sport == SportType.basketball) {
      displayType = switch (from) {
        'threepoints' => 'Three Pointer',
        'twopoints' => 'Field Goal',
        'onepoint' => 'Free Throw',
        _ => 'Score',
      };
    } else if (sport == SportType.hockey) {
      displayType = 'Goal';
    } else if (sport == SportType.baseball) {
      displayType = 'Run';
    } else {
      displayType = 'Goal';
    }

    return FixtureEvent(
      elapsed: time,
      type: displayType,
      detail: playerName ?? (isHome ? 'Home' : 'Away'),
      playerName: playerName,
      teamName: isHome ? 'home' : 'away',
      comments: '$homeScore - $awayScore',
    );
  }

  FixtureEvent _parseSuspensionIncident(Map<String, dynamic> inc) {
    final player = inc['player'] as Map<String, dynamic>?;
    final playerName = player?['shortName'] as String? ??
        player?['name'] as String?;
    final time = inc['time'] as int?;
    final length = inc['length'] as int?;
    final reason = inc['reason'] as String?;

    return FixtureEvent(
      elapsed: time,
      type: 'Penalty',
      detail: reason ?? 'Penalty',
      playerName: playerName,
      comments: length != null ? '$length min' : null,
    );
  }

  FixtureEvent _parseSubstitutionIncident(Map<String, dynamic> inc) {
    final playerIn = inc['playerIn'] as Map<String, dynamic>?;
    final playerOut = inc['playerOut'] as Map<String, dynamic>?;
    final nameIn = playerIn?['shortName'] as String? ?? playerIn?['name'] as String? ?? '?';
    final nameOut = playerOut?['shortName'] as String? ?? playerOut?['name'] as String? ?? '?';
    final time = inc['time'] as int?;

    return FixtureEvent(
      elapsed: time,
      type: 'subst',
      detail: '$nameIn for $nameOut',
      playerName: nameIn,
    );
  }

  FixtureEvent _parseCardIncident(Map<String, dynamic> inc) {
    final player = inc['player'] as Map<String, dynamic>?;
    final playerName = player?['shortName'] as String? ?? player?['name'] as String?;
    final time = inc['time'] as int?;
    final cardType = inc['incidentClass'] as String? ?? '';

    return FixtureEvent(
      elapsed: time,
      type: cardType.toLowerCase().contains('red') ? 'Red Card' : 'Yellow Card',
      detail: playerName ?? 'Unknown',
      playerName: playerName,
    );
  }

  FixtureEvent _parseVarIncident(Map<String, dynamic> inc) {
    final time = inc['time'] as int?;
    final confirmed = inc['confirmed'] as bool? ?? false;

    return FixtureEvent(
      elapsed: time,
      type: 'VAR',
      detail: confirmed ? 'Decision confirmed' : 'Decision overturned',
    );
  }
}

class _CachedResponse {
  final Map<String, dynamic>? data;
  final DateTime expiresAt;

  _CachedResponse(this.data, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
