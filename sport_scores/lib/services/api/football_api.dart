import '../../models/fixture.dart';
import '../../models/fixture_event.dart';
import '../../models/h2h_entry.dart';
import '../../models/league.dart';
import '../../models/match_statistics.dart';
import '../../models/sport.dart';
import '../../models/standing_row.dart';
import 'api_client.dart';

class FootballApi {
  final ApiClient _client;

  FootballApi(this._client);

  Future<List<League>> getLeagues() async {
    final data = await _client.get(
      SportType.football,
      '/leagues',
      cacheTtl: const Duration(hours: 24),
    );
    return data
        .map((json) => League.fromFootballJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<League?> getLeagueById(int leagueId) async {
    final data = await _client.get(
      SportType.football,
      '/leagues',
      params: {'id': leagueId.toString()},
      cacheTtl: const Duration(hours: 24),
    );
    if (data.isEmpty) return null;
    return League.fromFootballJson(data.first as Map<String, dynamic>);
  }

  Future<List<Fixture>> getFixturesByDate(DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final data = await _client.get(
      SportType.football,
      '/fixtures',
      params: {'date': dateStr},
    );
    return data
        .map((json) => Fixture.fromFootballJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Fixture>> getLiveFixtures() async {
    final data = await _client.get(
      SportType.football,
      '/fixtures',
      params: {'live': 'all'},
      cacheTtl: const Duration(seconds: 30),
    );
    return data
        .map((json) => Fixture.fromFootballJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Fixture>> getFixturesByLeague(int leagueId, int season) async {
    final data = await _client.get(
      SportType.football,
      '/fixtures',
      params: {
        'league': leagueId.toString(),
        'season': season.toString(),
      },
      cacheTtl: const Duration(minutes: 5),
    );
    return data
        .map((json) => Fixture.fromFootballJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<FixtureEvent>> getFixtureEvents(int fixtureId) async {
    final data = await _client.get(
      SportType.football,
      '/fixtures/events',
      params: {'fixture': fixtureId.toString()},
      cacheTtl: const Duration(seconds: 60),
    );
    return data
        .map((json) =>
            FixtureEvent.fromFootballJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<MatchStatistics> getFixtureStatistics(int fixtureId) async {
    final data = await _client.get(
      SportType.football,
      '/fixtures/statistics',
      params: {'fixture': fixtureId.toString()},
      cacheTtl: const Duration(minutes: 2),
    );
    return MatchStatistics.fromFootballJson(data);
  }

  Future<List<H2HEntry>> getHeadToHead(int homeId, int awayId) async {
    // Free plan doesn't allow `last` — fetch all and slice client-side.
    final data = await _client.get(
      SportType.football,
      '/fixtures/headtohead',
      params: {
        'h2h': '$homeId-$awayId',
      },
      cacheTtl: const Duration(hours: 1),
    );
    return data
        .map((j) => H2HEntry.fromFootballJson(j as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<StandingRow>> getStandings(int leagueId, int season) async {
    final data = await _client.get(
      SportType.football,
      '/standings',
      params: {
        'league': leagueId.toString(),
        'season': season.toString(),
      },
      cacheTtl: const Duration(hours: 1),
    );
    if (data.isEmpty) return [];
    final league = (data.first as Map<String, dynamic>)['league']
        as Map<String, dynamic>?;
    final groups = league?['standings'] as List?;
    if (groups == null || groups.isEmpty) return [];
    final rows = <StandingRow>[];
    for (final group in groups) {
      if (group is List) {
        for (final r in group) {
          if (r is Map<String, dynamic>) {
            rows.add(StandingRow.fromFootballJson(r));
          }
        }
      }
    }
    return rows;
  }

  Future<Fixture> getFixtureById(int fixtureId) async {
    final data = await _client.get(
      SportType.football,
      '/fixtures',
      params: {'id': fixtureId.toString()},
      cacheTtl: const Duration(seconds: 60),
    );
    if (data.isEmpty) throw ApiException('Fixture not found');
    return Fixture.fromFootballJson(data.first as Map<String, dynamic>);
  }
}
