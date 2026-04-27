import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/fixture.dart';
import '../../models/fixture_event.dart';
import '../../models/league.dart';
import '../../models/h2h_entry.dart';
import '../../models/match_statistics.dart';
import '../../models/sport.dart';
import '../../models/standing_row.dart';
import '../../utils/team_matching.dart';
import 'api_client.dart';
import 'odds_api_client.dart';
import 'standings_parser.dart';

class BasketballApi {
  final ApiClient _client;
  final OddsApiClient? _oddsApi;
  final http.Client _nbaClient = http.Client();

  BasketballApi(this._client, {OddsApiClient? oddsApi}) : _oddsApi = oddsApi;

  Future<List<League>> getLeagues() async {
    final data = await _client.get(
      SportType.basketball,
      '/leagues',
      cacheTtl: const Duration(hours: 24),
    );
    return data
        .map((json) =>
            League.fromBasketballJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Fixture>> getGamesByDate(DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final data = await _client.get(
      SportType.basketball,
      '/games',
      params: {'date': dateStr},
    );
    final primary = data
        .map((json) =>
            Fixture.fromBasketballJson(json as Map<String, dynamic>))
        .toList();
    if (primary.isNotEmpty) return primary;

    // Fallback to The Odds API when API-Sports returns nothing for this date.
    if (_oddsApi != null && _oddsApi.isConfigured) {
      debugPrint('BasketballApi: primary empty, falling back to Odds API');
      final fallback = await _oddsApi.getScores(SportType.basketball);
      return fallback.where((f) {
        return f.date.year == date.year &&
            f.date.month == date.month &&
            f.date.day == date.day;
      }).toList();
    }
    return primary;
  }

  Future<List<Fixture>> getLiveGames() async {
    // Basketball API doesn't support 'live' parameter, fetch today's games instead
    return getGamesByDate(DateTime.now());
  }

  Future<List<Fixture>> getGamesByLeague(int leagueId, dynamic season) async {
    final data = await _client.get(
      SportType.basketball,
      '/games',
      params: {
        'league': leagueId.toString(),
        'season': '$season',
      },
      cacheTtl: const Duration(minutes: 5),
    );
    return data
        .map((json) =>
            Fixture.fromBasketballJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Fixture> getGameById(int gameId) async {
    final data = await _client.get(
      SportType.basketball,
      '/games',
      params: {'id': gameId.toString()},
      cacheTtl: const Duration(seconds: 60),
    );
    if (data.isEmpty) throw ApiException('Game not found');
    return Fixture.fromBasketballJson(data.first as Map<String, dynamic>);
  }

  Future<MatchStatistics> getGameStatistics(int gameId) async {
    final data = await _client.get(
      SportType.basketball,
      '/games/statistics/teams',
      params: {'id': gameId.toString()},
      cacheTtl: const Duration(minutes: 2),
    );
    return MatchStatistics.fromTeamGameStats(data);
  }

  Future<List<H2HEntry>> getHeadToHead(int homeId, int awayId) async {
    final data = await _client.get(
      SportType.basketball,
      '/games',
      params: {'h2h': '$homeId-$awayId'},
      cacheTtl: const Duration(hours: 1),
    );
    return data
        .map((j) => H2HEntry.fromGenericGameJson(j as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<StandingRow>> getStandings(int leagueId, dynamic season) async {
    final data = await _client.get(
      SportType.basketball,
      '/standings',
      params: {
        'league': leagueId.toString(),
        'season': '$season',
      },
      cacheTtl: const Duration(hours: 1),
    );
    return parseGenericStandings(data);
  }

  /// Look up the NBA game ID by matching team names from the API-Sports fixture
  /// against the NBA schedule endpoint.
  Future<String?> _lookupNbaGameId(Fixture fixture) async {
    try {
      // ESPN endpoint only covers NBA regular season — skip other leagues.
      final leagueName = fixture.league.name.toLowerCase();
      if (!leagueName.contains('nba') || leagueName.contains('summer')) {
        return null;
      }
      final fixHome = fixture.homeTeam.name;
      final fixAway = fixture.awayTeam.name;
      debugPrint('NBA lookup: Looking for $fixHome vs $fixAway');

      for (final date in TeamMatching.datesToTry(fixture.date)) {
        final dateStr = TeamMatching.formatDate(date);
        debugPrint('NBA lookup: Trying date $dateStr');

        // Use NBA scoreboard endpoint
        final formatted = dateStr.replaceAll('-', '');
        final response = await _nbaClient.get(
          Uri.parse('https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard?dates=$formatted'),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          debugPrint('NBA lookup: ESPN API returned status ${response.statusCode}');
          continue;
        }

        final body = jsonDecode(response.body) as Map<String, dynamic>?;
        final events = body?['events'] as List?;
        if (events == null || events.isEmpty) continue;

        debugPrint('NBA lookup: Found ${events.length} games on $dateStr');

        for (final event in events) {
          if (event is! Map<String, dynamic>) continue;
          final competitions = event['competitions'] as List?;
          if (competitions == null || competitions.isEmpty) continue;

          final comp = competitions[0] as Map<String, dynamic>;
          final competitors = comp['competitors'] as List?;
          if (competitors == null || competitors.length < 2) continue;

          String espnHome = '';
          String espnAway = '';
          for (final c in competitors) {
            if (c is! Map<String, dynamic>) continue;
            final team = c['team'] as Map<String, dynamic>?;
            final name = team?['displayName'] as String? ?? team?['name'] as String? ?? '';
            if (c['homeAway'] == 'home') {
              espnHome = name;
            } else {
              espnAway = name;
            }
          }

          if (TeamMatching.teamsMatch(fixHome, espnHome) &&
              TeamMatching.teamsMatch(fixAway, espnAway)) {
            final gameId = event['id'] as String?;
            debugPrint('NBA lookup: Found match! $espnHome vs $espnAway, gameId=$gameId');
            return gameId;
          }
        }
      }
      debugPrint('NBA lookup: No matching game found');
      return null;
    } catch (e) {
      debugPrint('NBA lookup: Error - $e');
      return null;
    }
  }

  Future<List<FixtureEvent>> getPlayByPlayFromFixture(Fixture fixture) async {
    final gameId = await _lookupNbaGameId(fixture);
    if (gameId == null) return [];
    return getPlayByPlay(gameId);
  }

  Future<List<FixtureEvent>> getPlayByPlay(String gameId) async {
    try {
      debugPrint('NBA playByPlay: Fetching for gameId=$gameId');
      final response = await _nbaClient.get(
        Uri.parse('https://site.api.espn.com/apis/site/v2/sports/basketball/nba/summary?event=$gameId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('NBA playByPlay: API returned status ${response.statusCode}');
        return [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Build team ID → name map from boxscore
      final teamNames = <String, String>{};
      final boxTeams = (json['boxscore'] as Map<String, dynamic>?)?['teams'] as List?;
      if (boxTeams != null) {
        for (final t in boxTeams) {
          if (t is Map<String, dynamic>) {
            final team = t['team'] as Map<String, dynamic>?;
            final id = team?['id']?.toString();
            final name = team?['displayName'] as String? ?? team?['abbreviation'] as String? ?? '';
            if (id != null) teamNames[id] = name;
          }
        }
      }

      final plays = json['plays'] as List?;
      if (plays == null || plays.isEmpty) {
        debugPrint('NBA playByPlay: No plays found');
        return [];
      }

      debugPrint('NBA playByPlay: Parsing ${plays.length} plays');

      // Filter to scoring plays only to keep it manageable
      final events = plays
          .whereType<Map<String, dynamic>>()
          .where((p) => p['scoringPlay'] == true)
          .map((play) {
            // Inject team name from our map
            final teamId = play['team']?['id']?.toString();
            if (teamId != null && teamNames.containsKey(teamId)) {
              play['team'] = {...(play['team'] as Map<String, dynamic>? ?? {}), 'displayName': teamNames[teamId]};
            }
            return FixtureEvent.fromNbaJson(play);
          })
          .toList();

      debugPrint('NBA playByPlay: Filtered to ${events.length} key events');
      return events;
    } catch (e) {
      debugPrint('NBA playByPlay: Error - $e');
      return [];
    }
  }
}
