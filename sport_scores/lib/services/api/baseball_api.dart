import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/fixture.dart';
import '../../models/fixture_event.dart';
import '../../models/league.dart';
import '../../models/match_statistics.dart';
import '../../models/sport.dart';
import '../../models/standing_row.dart';
import '../../utils/team_matching.dart';
import 'api_client.dart';
import 'odds_api_client.dart';
import 'standings_parser.dart';

class BaseballApi {
  final ApiClient _client;
  final OddsApiClient? _oddsApi;
  final http.Client _mlbClient = http.Client();

  BaseballApi(this._client, {OddsApiClient? oddsApi}) : _oddsApi = oddsApi;

  Future<List<League>> getLeagues() async {
    final data = await _client.get(
      SportType.baseball,
      '/leagues',
      cacheTtl: const Duration(hours: 24),
    );
    return data.map((json) {
      final j = json as Map<String, dynamic>;
      final id = j['id'];
      return League(
        id: id is String ? int.tryParse(id) ?? 0 : (id as int? ?? 0),
        name: j['name'] as String? ?? 'Unknown',
        country: j['country']?['name'] as String?,
        logo: j['logo'] as String?,
        countryFlag: j['country']?['flag'] as String?,
        sport: SportType.baseball,
      );
    }).toList();
  }

  Future<List<Fixture>> getGamesByDate(DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final data = await _client.get(
      SportType.baseball,
      '/games',
      params: {'date': dateStr},
    );
    for (final json in data) {
      final j = json as Map<String, dynamic>;
      final teams = j['teams'] as Map<String, dynamic>?;
      final home = teams?['home']?['name'] ?? '?';
      final away = teams?['away']?['name'] ?? '?';
      final status = j['status']?['short'] ?? '?';
      final scores = j['scores'];
      debugPrint('API-Sports game: $home vs $away | status=$status | scores=$scores');
    }
    final primary = data
        .map((json) => Fixture.fromBaseballJson(json as Map<String, dynamic>))
        .toList();
    if (primary.isNotEmpty) return primary;

    // Fallback to The Odds API when API-Sports returns nothing.
    if (_oddsApi != null && _oddsApi.isConfigured) {
      debugPrint('BaseballApi: primary empty, falling back to Odds API');
      final fallback = await _oddsApi.getScores(SportType.baseball);
      return fallback.where((f) {
        return f.date.year == date.year &&
            f.date.month == date.month &&
            f.date.day == date.day;
      }).toList();
    }
    return primary;
  }

  Future<List<Fixture>> getLiveGames() async {
    return getGamesByDate(DateTime.now());
  }

  Future<List<Fixture>> getGamesByLeague(int leagueId, int season) async {
    final data = await _client.get(
      SportType.baseball,
      '/games',
      params: {
        'league': leagueId.toString(),
        'season': season.toString(),
      },
      cacheTtl: const Duration(minutes: 5),
    );
    return data
        .map((json) => Fixture.fromBaseballJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Fixture> getGameById(int gameId) async {
    final data = await _client.get(
      SportType.baseball,
      '/games',
      params: {'id': gameId.toString()},
      cacheTtl: const Duration(seconds: 60),
    );
    if (data.isEmpty) throw ApiException('Game not found');
    final raw = data.first as Map<String, dynamic>;
    debugPrint('API-Sports raw: status=${raw['status']} scores=${raw['scores']}');
    return Fixture.fromBaseballJson(raw);
  }


  Future<MatchStatistics> getGameStatistics(int gameId) async {
    final data = await _client.get(
      SportType.baseball,
      '/games/statistics/teams',
      params: {'id': gameId.toString()},
      cacheTtl: const Duration(minutes: 2),
    );
    return MatchStatistics.fromTeamGameStats(data);
  }

  Future<List<StandingRow>> getStandings(int leagueId, int season) async {
    final data = await _client.get(
      SportType.baseball,
      '/standings',
      params: {
        'league': leagueId.toString(),
        'season': season.toString(),
      },
      cacheTtl: const Duration(hours: 1),
    );
    return parseGenericStandings(data);
  }

  Future<int?> _lookupGamePk(Fixture fixture) async {
    try {
      // statsapi.mlb.com only covers MLB — skip other leagues (NPB, KBO, etc.).
      final leagueName = fixture.league.name.toLowerCase();
      if (!leagueName.contains('mlb') && !leagueName.contains('major league')) {
        return null;
      }
      debugPrint('MLB lookup: Looking for ${fixture.homeTeam.name} vs ${fixture.awayTeam.name}');

      final fixHome = fixture.homeTeam.name.toLowerCase();
      final fixAway = fixture.awayTeam.name.toLowerCase();

      for (final date in TeamMatching.datesToTry(fixture.date)) {
        final dateStr = TeamMatching.formatDate(date);
        debugPrint('MLB lookup: Trying date $dateStr');

        final response = await _mlbClient.get(
          Uri.parse('https://statsapi.mlb.com/api/v1/schedule?sportId=1,11,12,13,14&date=$dateStr'),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw ApiException('MLB API request timeout'),
        );

        if (response.statusCode != 200) {
          debugPrint('MLB lookup: API returned status ${response.statusCode}');
          continue;
        }

        final body = jsonDecode(response.body) as Map<String, dynamic>?;
        final dates = body?['dates'] as List?;
        if (dates == null || dates.isEmpty) continue;

        final allGames = <Map<String, dynamic>>[];
        for (final d in dates) {
          if (d is Map<String, dynamic>) {
            final games = d['games'] as List? ?? [];
            for (final g in games) {
              if (g is Map<String, dynamic>) allGames.add(g);
            }
          }
        }
        debugPrint('MLB lookup: Found ${allGames.length} games on $dateStr');

        for (final game in allGames) {
          final homeTeam = game['teams']?['home']?['team']?['name'] as String? ?? '';
          final awayTeam = game['teams']?['away']?['team']?['name'] as String? ?? '';

          if (TeamMatching.teamsMatch(fixHome, homeTeam.toLowerCase()) &&
              TeamMatching.teamsMatch(fixAway, awayTeam.toLowerCase())) {
            final gamePk = game['gamePk'] as int?;
            debugPrint('MLB lookup: Found match! $homeTeam vs $awayTeam, gamePk=$gamePk');
            return gamePk;
          }
        }
      }
      debugPrint('MLB lookup: No matching game found for "$fixHome" vs "$fixAway"');
      return null;
    } catch (e) {
      debugPrint('MLB lookup: Error - $e');
      return null;
    }
  }

  Future<List<FixtureEvent>> getPlayByPlayFromFixture(Fixture fixture) async {
    final gamePk = await _lookupGamePk(fixture);
    if (gamePk == null) return [];
    return getPlayByPlay(gamePk);
  }

  Future<List<FixtureEvent>> getPlayByPlay(int gamePk) async {
    try {
      debugPrint('MLB playByPlay: Fetching for gamePk=$gamePk');
      final response = await _mlbClient.get(
        Uri.parse('https://statsapi.mlb.com/api/v1/game/$gamePk/playByPlay'),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw ApiException('MLB API request timeout'),
      );

      if (response.statusCode != 200) {
        debugPrint('MLB playByPlay: API returned status ${response.statusCode}');
        throw ApiException('Failed to fetch MLB play-by-play: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final playEvents = json['allPlays'] as List?;

      if (playEvents == null) {
        debugPrint('MLB playByPlay: No allPlays field found');
        debugPrint('MLB playByPlay: JSON keys=${json.keys.toList()}');
        return [];
      }

      debugPrint('MLB playByPlay: Parsing ${playEvents.length} plays');
      final events = playEvents
          .whereType<Map<String, dynamic>>()
          .map((event) => FixtureEvent.fromMlbJson(event))
          .toList();

      debugPrint('MLB playByPlay: Successfully parsed ${events.length} events');
      return events;
    } catch (e) {
      debugPrint('MLB playByPlay: Error - $e');
      throw ApiException('Error fetching MLB play-by-play: $e');
    }
  }
}
