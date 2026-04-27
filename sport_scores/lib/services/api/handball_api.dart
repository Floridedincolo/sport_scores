import '../../models/fixture.dart';
import '../../models/league.dart';
import '../../models/match_statistics.dart';
import '../../models/sport.dart';
import '../../models/standing_row.dart';
import 'api_client.dart';
import 'standings_parser.dart';

class HandballApi {
  final ApiClient _client;

  HandballApi(this._client);

  Future<List<League>> getLeagues() async {
    final data = await _client.get(
      SportType.handball,
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
        sport: SportType.handball,
      );
    }).toList();
  }

  Future<List<Fixture>> getGamesByDate(DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final data = await _client.get(
      SportType.handball,
      '/games',
      params: {'date': dateStr},
    );
    return data
        .map((json) => Fixture.fromHandballJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Fixture>> getLiveGames() async {
    return getGamesByDate(DateTime.now());
  }

  Future<List<Fixture>> getGamesByLeague(int leagueId, int season) async {
    final data = await _client.get(
      SportType.handball,
      '/games',
      params: {
        'league': leagueId.toString(),
        'season': season.toString(),
      },
      cacheTtl: const Duration(minutes: 5),
    );
    return data
        .map((json) => Fixture.fromHandballJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<MatchStatistics> getGameStatistics(int gameId) async {
    final data = await _client.get(
      SportType.handball,
      '/games/statistics/teams',
      params: {'id': gameId.toString()},
      cacheTtl: const Duration(minutes: 2),
    );
    return MatchStatistics.fromTeamGameStats(data);
  }

  Future<List<StandingRow>> getStandings(int leagueId, int season) async {
    final data = await _client.get(
      SportType.handball,
      '/standings',
      params: {
        'league': leagueId.toString(),
        'season': season.toString(),
      },
      cacheTtl: const Duration(hours: 1),
    );
    return parseGenericStandings(data);
  }

  Future<Fixture> getGameById(int gameId) async {
    final data = await _client.get(
      SportType.handball,
      '/games',
      params: {'id': gameId.toString()},
      cacheTtl: const Duration(seconds: 60),
    );
    if (data.isEmpty) throw ApiException('Game not found');
    return Fixture.fromHandballJson(data.first as Map<String, dynamic>);
  }
}
