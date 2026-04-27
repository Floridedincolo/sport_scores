import 'package:flutter_test/flutter_test.dart';
import 'package:sport_scores/models/favorite.dart';
import 'package:sport_scores/models/fixture.dart';
import 'package:sport_scores/models/league.dart';
import 'package:sport_scores/models/match_snapshot.dart';
import 'package:sport_scores/models/score.dart';
import 'package:sport_scores/models/sport.dart';
import 'package:sport_scores/models/team.dart';
import 'package:sport_scores/services/favorites_service.dart';
import 'package:sport_scores/services/live_monitor_service.dart';
import 'package:sport_scores/services/match_snapshot_service.dart';

/// Fake favorites service care nu deschide Hive — returnează ce punem în constructor.
class _FakeFavoritesService implements FavoritesService {
  _FakeFavoritesService(this._favs);
  final List<Favorite> _favs;

  @override
  List<Favorite> getAll() => _favs;

  @override
  Future<void> init() async {}

  @override
  bool isFavorite(SportType sport, int id) =>
      _favs.any((f) => f.sport == sport && f.entityId == id);

  @override
  Future<void> add(Favorite favorite) async => _favs.add(favorite);

  @override
  Future<void> remove(SportType sport, FavoriteType type, int id) async =>
      _favs.removeWhere(
          (f) => f.sport == sport && f.type == type && f.entityId == id);

  @override
  Future<void> toggle(Favorite favorite) async {}
}

/// Fake snapshot service în memorie.
class _FakeSnapshotService implements MatchSnapshotService {
  final Map<String, MatchSnapshot> _store = {};

  @override
  Future<void> init() async {}

  @override
  MatchSnapshot? get(int sportIndex, int matchId) =>
      _store[MatchSnapshot.keyFor(sportIndex, matchId)];

  @override
  Future<void> save(MatchSnapshot snapshot) async {
    _store[snapshot.compositeKey] = snapshot;
  }

  @override
  Future<void> remove(int sportIndex, int matchId) async {
    _store.remove(MatchSnapshot.keyFor(sportIndex, matchId));
  }

  @override
  List<MatchSnapshot> getAll() => _store.values.toList();
}

Fixture _makeFootballFixture({
  required int id,
  required int homeScore,
  required int awayScore,
  required FixtureStatus status,
}) {
  return Fixture(
    id: id,
    sport: SportType.football,
    league: const League(id: 1, name: 'Test League', sport: SportType.football),
    homeTeam: const Team(id: 10, name: 'Home FC'),
    awayTeam: const Team(id: 20, name: 'Away FC'),
    score: Score(homeTotal: homeScore, awayTotal: awayScore),
    date: DateTime(2026, 4, 24, 20, 0),
    status: status,
  );
}

Favorite _favMatch(int id, SportType sport) => Favorite.match(
      sport: sport,
      matchId: id,
      displayName: 'Home FC vs Away FC',
    );

void main() {
  group('LiveMonitorService.checkOnce', () {
    test('niciun favorit → nu face niciun fetch', () async {
      var fetchCalls = 0;
      final monitor = LiveMonitorService(
        favorites: _FakeFavoritesService([]),
        snapshots: _FakeSnapshotService(),
        liveFetcher: (sport) async {
          fetchCalls++;
          return [];
        },
        fixtureByIdFetcher: (s, id) async => null,
        notifier: (_) async {},
      );

      await monitor.checkOnce();

      expect(fetchCalls, 0);
    });

    test('scor crescut pe echipa gazdă → notificare de gol pentru gazdă',
        () async {
      final snaps = _FakeSnapshotService();
      // Snapshot anterior: 0-0 în prima repriză.
      await snaps.save(MatchSnapshot(
        sportIndex: SportType.football.index,
        matchId: 100,
        homeScore: 0,
        awayScore: 0,
        statusCode: '1H',
        notifiedEventIds: [],
        lastUpdated: DateTime.now(),
      ));

      final events = <MatchEvent>[];
      final monitor = LiveMonitorService(
        favorites: _FakeFavoritesService([_favMatch(100, SportType.football)]),
        snapshots: snaps,
        liveFetcher: (sport) async => [
          _makeFootballFixture(
            id: 100,
            homeScore: 1,
            awayScore: 0,
            status: FixtureStatus.firstHalf,
          ),
        ],
        fixtureByIdFetcher: (s, id) async => null,
        notifier: (e) async => events.add(e),
      );

      await monitor.checkOnce();

      expect(events.length, 1);
      expect(events.first.kind, MatchEventKind.goal);
      expect(events.first.scoredByHome, true);

      // Snapshot-ul nou persistă scorul 1-0.
      final saved = snaps.get(SportType.football.index, 100);
      expect(saved?.homeScore, 1);
      expect(saved?.awayScore, 0);
    });

    test('fără snapshot anterior + meci deja LIVE → kickoff, nu gol', () async {
      final snaps = _FakeSnapshotService();
      final events = <MatchEvent>[];
      final monitor = LiveMonitorService(
        favorites: _FakeFavoritesService([_favMatch(200, SportType.football)]),
        snapshots: snaps,
        liveFetcher: (sport) async => [
          _makeFootballFixture(
            id: 200,
            homeScore: 1,
            awayScore: 0,
            status: FixtureStatus.firstHalf,
          ),
        ],
        fixtureByIdFetcher: (s, id) async => null,
        notifier: (e) async => events.add(e),
      );

      await monitor.checkOnce();

      // Fără snapshot anterior nu știm "când" s-a dat golul, deci NU emitem
      // un eveniment de gol — doar kickoff-ul.
      expect(events.map((e) => e.kind), [MatchEventKind.kickoff]);
    });

    test('trecere la HT → notificare halftime', () async {
      final snaps = _FakeSnapshotService();
      await snaps.save(MatchSnapshot(
        sportIndex: SportType.football.index,
        matchId: 300,
        homeScore: 1,
        awayScore: 1,
        statusCode: '1H',
        notifiedEventIds: [],
        lastUpdated: DateTime.now(),
      ));

      final events = <MatchEvent>[];
      final monitor = LiveMonitorService(
        favorites: _FakeFavoritesService([_favMatch(300, SportType.football)]),
        snapshots: snaps,
        liveFetcher: (sport) async => [
          _makeFootballFixture(
            id: 300,
            homeScore: 1,
            awayScore: 1,
            status: FixtureStatus.halftime,
          ),
        ],
        fixtureByIdFetcher: (s, id) async => null,
        notifier: (e) async => events.add(e),
      );

      await monitor.checkOnce();

      expect(events.map((e) => e.kind), [MatchEventKind.halftime]);
    });

    test('snapshot LIVE + meci lipsă din răspuns + fetch FT → fullTime',
        () async {
      final snaps = _FakeSnapshotService();
      await snaps.save(MatchSnapshot(
        sportIndex: SportType.football.index,
        matchId: 400,
        homeScore: 2,
        awayScore: 1,
        statusCode: '2H',
        notifiedEventIds: [],
        lastUpdated: DateTime.now(),
      ));

      final events = <MatchEvent>[];
      final monitor = LiveMonitorService(
        favorites: _FakeFavoritesService([_favMatch(400, SportType.football)]),
        snapshots: snaps,
        // Meciul nu mai e în lista live.
        liveFetcher: (sport) async => [],
        // Fetch-ul individual îl găsește deja FT.
        fixtureByIdFetcher: (s, id) async => _makeFootballFixture(
          id: 400,
          homeScore: 2,
          awayScore: 1,
          status: FixtureStatus.finished,
        ),
        notifier: (e) async => events.add(e),
      );

      await monitor.checkOnce();

      expect(events.map((e) => e.kind), [MatchEventKind.fullTime]);
      final saved = snaps.get(SportType.football.index, 400);
      expect(saved?.statusCode, 'FT');
    });

    test('un singur request per sport, chiar dacă 2 meciuri favorite din acel sport',
        () async {
      var fetchCount = 0;
      final snaps = _FakeSnapshotService();
      final monitor = LiveMonitorService(
        favorites: _FakeFavoritesService([
          _favMatch(1, SportType.football),
          _favMatch(2, SportType.football),
        ]),
        snapshots: snaps,
        liveFetcher: (sport) async {
          fetchCount++;
          return [];
        },
        fixtureByIdFetcher: (s, id) async => null,
        notifier: (_) async {},
      );

      await monitor.checkOnce();

      expect(fetchCount, 1);
    });
  });
}
