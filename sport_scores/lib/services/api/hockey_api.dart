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

class HockeyApi {
  final ApiClient _client;
  final OddsApiClient? _oddsApi;
  final http.Client _nhlClient = http.Client();

  HockeyApi(this._client, {OddsApiClient? oddsApi}) : _oddsApi = oddsApi;

  Future<List<League>> getLeagues() async {
    final data = await _client.get(
      SportType.hockey,
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
        sport: SportType.hockey,
      );
    }).toList();
  }

  Future<List<Fixture>> getGamesByDate(DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final data = await _client.get(
      SportType.hockey,
      '/games',
      params: {'date': dateStr},
    );
    final primary = data
        .map((json) => Fixture.fromHockeyJson(json as Map<String, dynamic>))
        .toList();
    if (primary.isNotEmpty) return primary;

    // Fallback to The Odds API when API-Sports returns nothing.
    if (_oddsApi != null && _oddsApi.isConfigured) {
      debugPrint('HockeyApi: primary empty, falling back to Odds API');
      final fallback = await _oddsApi.getScores(SportType.hockey);
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
      SportType.hockey,
      '/games',
      params: {
        'league': leagueId.toString(),
        'season': season.toString(),
      },
      cacheTtl: const Duration(minutes: 5),
    );
    return data
        .map((json) => Fixture.fromHockeyJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Fixture> getGameById(int gameId) async {
    final data = await _client.get(
      SportType.hockey,
      '/games',
      params: {'id': gameId.toString()},
      cacheTtl: const Duration(seconds: 60),
    );
    if (data.isEmpty) throw ApiException('Game not found');
    return Fixture.fromHockeyJson(data.first as Map<String, dynamic>);
  }

  Future<MatchStatistics> getGameStatistics(int gameId) async {
    final data = await _client.get(
      SportType.hockey,
      '/games/statistics/teams',
      params: {'id': gameId.toString()},
      cacheTtl: const Duration(minutes: 2),
    );
    return MatchStatistics.fromTeamGameStats(data);
  }

  Future<List<StandingRow>> getStandings(int leagueId, int season) async {
    final data = await _client.get(
      SportType.hockey,
      '/standings',
      params: {
        'league': leagueId.toString(),
        'season': season.toString(),
      },
      cacheTtl: const Duration(hours: 1),
    );
    return parseGenericStandings(data);
  }

  /// Look up the NHL game ID by matching team names from the API-Sports fixture
  /// against the NHL schedule endpoint.
  Future<int?> _lookupNhlGameId(Fixture fixture) async {
    try {
      // NHL endpoint only covers NHL — skip other leagues (KHL, Liiga, etc.).
      if (!fixture.league.name.toLowerCase().contains('nhl')) {
        return null;
      }
      final fixHome = fixture.homeTeam.name;
      final fixAway = fixture.awayTeam.name;
      debugPrint('NHL lookup: Looking for $fixHome vs $fixAway');

      for (final date in TeamMatching.datesToTry(fixture.date)) {
        final dateStr = TeamMatching.formatDate(date);
        debugPrint('NHL lookup: Trying date $dateStr');

        final response = await _nhlClient.get(
          Uri.parse('https://api-web.nhle.com/v1/schedule/$dateStr'),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          debugPrint('NHL lookup: API returned status ${response.statusCode}');
          continue;
        }

        final body = jsonDecode(response.body) as Map<String, dynamic>?;
        final gameWeek = body?['gameWeek'] as List?;
        if (gameWeek == null || gameWeek.isEmpty) continue;

        for (final day in gameWeek) {
          if (day is! Map<String, dynamic>) continue;
          final games = day['games'] as List?;
          if (games == null) continue;

          for (final game in games) {
            if (game is! Map<String, dynamic>) continue;
            final homeTeam = game['homeTeam'] as Map<String, dynamic>?;
            final awayTeam = game['awayTeam'] as Map<String, dynamic>?;
            final homePlace = homeTeam?['placeName']?['default'] as String? ?? '';
            final homeCommon = homeTeam?['commonName']?['default'] as String? ?? '';
            final homeName = '$homePlace $homeCommon'.trim();
            final awayPlace = awayTeam?['placeName']?['default'] as String? ?? '';
            final awayCommon = awayTeam?['commonName']?['default'] as String? ?? '';
            final awayName = '$awayPlace $awayCommon'.trim();
            debugPrint('NHL lookup: Checking $homeName vs $awayName');

            if (TeamMatching.teamsMatch(fixHome, homeName) &&
                TeamMatching.teamsMatch(fixAway, awayName)) {
              final nhlGameId = game['id'] as int?;
              debugPrint('NHL lookup: Found match! $homeName vs $awayName, gameId=$nhlGameId');
              return nhlGameId;
            }
          }
        }
      }
      debugPrint('NHL lookup: No matching game found');
      return null;
    } catch (e) {
      debugPrint('NHL lookup: Error - $e');
      return null;
    }
  }

  Future<List<FixtureEvent>> getPlayByPlayFromFixture(Fixture fixture) async {
    final gameId = await _lookupNhlGameId(fixture);
    if (gameId == null) return [];
    return getPlayByPlay(gameId);
  }

  Future<List<FixtureEvent>> getPlayByPlay(int gameId) async {
    try {
      debugPrint('NHL playByPlay: Fetching for gameId=$gameId');
      final response = await _nhlClient.get(
        Uri.parse('https://api-web.nhle.com/v1/gamecenter/$gameId/play-by-play'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('NHL playByPlay: API returned status ${response.statusCode}');
        return [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final plays = json['plays'] as List?;
      if (plays == null || plays.isEmpty) {
        debugPrint('NHL playByPlay: No plays found');
        return [];
      }

      debugPrint('NHL playByPlay: Parsing ${plays.length} plays');

      // Filter to key events: goals, penalties, shots on goal, period starts
      final events = plays
          .whereType<Map<String, dynamic>>()
          .where((p) {
            final typeCode = p['typeCode'] as int? ?? 0;
            // 505=goal, 509=penalty, 506=faceoff-won (period start), 508=stoppage
            return typeCode == 505 || typeCode == 509 || typeCode == 502;
          })
          .map((play) => FixtureEvent.fromNhlJson(play))
          .toList();

      debugPrint('NHL playByPlay: Filtered to ${events.length} key events');
      return events;
    } catch (e) {
      debugPrint('NHL playByPlay: Error - $e');
      return [];
    }
  }
}
