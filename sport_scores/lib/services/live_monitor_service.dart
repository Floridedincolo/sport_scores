import 'package:flutter/foundation.dart';

import '../models/favorite.dart';
import '../models/fixture.dart';
import '../models/fixture_event.dart';
import '../models/match_snapshot.dart';
import '../models/sport.dart';
import 'api/api_client.dart';
import 'api/sport_api_factory.dart';
import 'favorites_service.dart';
import 'match_snapshot_service.dart';
import 'notification_service.dart';

/// Semnătura pentru a aduce lista de meciuri "live" pentru un sport.
typedef LiveFetcher = Future<List<Fixture>> Function(SportType sport);

/// Semnătura pentru a aduce un singur meci după id (pentru confirmare FT).
typedef FixtureByIdFetcher = Future<Fixture?> Function(
    SportType sport, int id);

/// Semnătura pentru a aduce evenimentele (cartonașe/incidente) unui meci de
/// fotbal. Returnează listă goală dacă sportul nu suportă.
typedef EventsFetcher = Future<List<FixtureEvent>> Function(int fixtureId);

/// Sender injectabil pentru notificări — implicit [NotificationService].
typedef MatchNotifier = Future<void> Function(MatchEvent event);

/// Tipurile de evenimente care declanșează notificări.
enum MatchEventKind { goal, kickoff, halftime, fullTime, incident }

class MatchEvent {
  final MatchEventKind kind;
  final Fixture fixture;
  final String displayName;
  final bool? scoredByHome;
  final String? incidentDescription;

  MatchEvent({
    required this.kind,
    required this.fixture,
    required this.displayName,
    this.scoredByHome,
    this.incidentDescription,
  });
}

/// Monitorul care compară starea curentă a meciurilor favorite cu ultimul
/// snapshot și emite notificări pentru schimbări.
///
/// Constructorul primar ([LiveMonitorService.fromApiFactory]) este folosit în
/// producție cu [SportApiFactory]. Constructorul de bază primește fetcher-i
/// injectabili ca să fie ușor de testat fără să mock-uim tot stack-ul de API.
class LiveMonitorService {
  final FavoritesService favorites;
  final MatchSnapshotService snapshots;
  final LiveFetcher _liveFetcher;
  final FixtureByIdFetcher _fixtureByIdFetcher;
  final EventsFetcher? _footballEventsFetcher;
  final MatchNotifier _notify;

  LiveMonitorService({
    required this.favorites,
    required this.snapshots,
    required LiveFetcher liveFetcher,
    required FixtureByIdFetcher fixtureByIdFetcher,
    EventsFetcher? footballEventsFetcher,
    MatchNotifier? notifier,
  })  : _liveFetcher = liveFetcher,
        _fixtureByIdFetcher = fixtureByIdFetcher,
        _footballEventsFetcher = footballEventsFetcher,
        _notify = notifier ?? _defaultNotifier;

  /// Construcție uzuală din [SportApiFactory] — leagă automat fetcher-ii.
  factory LiveMonitorService.fromApiFactory({
    required FavoritesService favorites,
    required MatchSnapshotService snapshots,
    required SportApiFactory apiFactory,
    MatchNotifier? notifier,
  }) {
    return LiveMonitorService(
      favorites: favorites,
      snapshots: snapshots,
      liveFetcher: (sport) => _fetchLiveFromFactory(apiFactory, sport),
      fixtureByIdFetcher: (sport, id) =>
          _fetchFixtureByIdFromFactory(apiFactory, sport, id),
      footballEventsFetcher: apiFactory.football.getFixtureEvents,
      notifier: notifier,
    );
  }

  static Future<List<Fixture>> _fetchLiveFromFactory(
      SportApiFactory apiFactory, SportType sport) {
    switch (sport) {
      case SportType.football:
        return apiFactory.football.getLiveFixtures();
      case SportType.basketball:
        return apiFactory.basketball.getLiveGames();
      case SportType.hockey:
        return apiFactory.hockey.getLiveGames();
      case SportType.baseball:
        return apiFactory.baseball.getLiveGames();
      case SportType.handball:
        return apiFactory.handball.getLiveGames();
      case SportType.formula1:
        return apiFactory.formula1.getLiveRaces();
      case SportType.tennis:
        // Tennis folosește SportsAPIPro; nu îl monitorizăm aici.
        return Future.value(<Fixture>[]);
    }
  }

  static Future<Fixture?> _fetchFixtureByIdFromFactory(
      SportApiFactory apiFactory, SportType sport, int id) async {
    try {
      switch (sport) {
        case SportType.football:
          return await apiFactory.football.getFixtureById(id);
        case SportType.basketball:
          return await apiFactory.basketball.getGameById(id);
        case SportType.hockey:
          return await apiFactory.hockey.getGameById(id);
        case SportType.baseball:
          return await apiFactory.baseball.getGameById(id);
        case SportType.handball:
          return await apiFactory.handball.getGameById(id);
        case SportType.formula1:
          return await apiFactory.formula1.getRaceById(id);
        case SportType.tennis:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  static Future<void> _defaultNotifier(MatchEvent e) async {
    final f = e.fixture;
    switch (e.kind) {
      case MatchEventKind.goal:
        await NotificationService.showGoal(
          matchId: f.id,
          homeTeam: f.homeTeam.name,
          awayTeam: f.awayTeam.name,
          homeScore: f.score.homeTotal ?? 0,
          awayScore: f.score.awayTotal ?? 0,
          scoredByHome: e.scoredByHome ?? true,
        );
      case MatchEventKind.kickoff:
        await NotificationService.showKickoff(
          matchId: f.id,
          displayName: e.displayName,
        );
      case MatchEventKind.halftime:
        await NotificationService.showStatusChange(
          matchId: f.id,
          displayName: e.displayName,
          statusLabel: 'Pauză',
        );
      case MatchEventKind.fullTime:
        await NotificationService.showStatusChange(
          matchId: f.id,
          displayName: e.displayName,
          statusLabel: 'Final',
        );
      case MatchEventKind.incident:
        await NotificationService.showIncident(
          matchId: f.id,
          displayName: e.displayName,
          description: e.incidentDescription ?? 'Incident',
        );
    }
  }

  /// O iterație completă. Se așteaptă să fie apelată periodic (2 min).
  /// Nu aruncă excepții — orice eroare per-sport este logată și ignorată.
  Future<void> checkOnce() async {
    // Reîncărcăm din SharedPreferences ca să vedem mutațiile făcute din
    // celălalt izolat (UI ↔ background) între cicluri.
    await favorites.reload();
    await snapshots.reload();

    final allFavorites = favorites.getAll();
    final matchFavs =
        allFavorites.where((f) => f.type == FavoriteType.match).toList();

    if (matchFavs.isEmpty) {
      debugPrint('[LiveMonitor] Nu sunt meciuri favorite, skip.');
      return;
    }

    // Grupează favoritele pe sport — un request per sport per ciclu.
    final Map<SportType, List<Favorite>> bySport = {};
    for (final f in matchFavs) {
      bySport.putIfAbsent(f.sport, () => []).add(f);
    }

    for (final entry in bySport.entries) {
      await _checkSport(entry.key, entry.value);
    }
  }

  Future<void> _checkSport(SportType sport, List<Favorite> favs) async {
    List<Fixture> live;
    try {
      live = await _liveFetcher(sport);
    } on RateLimitException {
      debugPrint('[LiveMonitor] Rate limit atins, skip sport=$sport.');
      return;
    } catch (e) {
      debugPrint('[LiveMonitor] Eroare la fetch live pentru $sport: $e');
      return;
    }

    final liveById = {for (final f in live) f.id: f};

    for (final fav in favs) {
      final fixture = liveById[fav.entityId];
      if (fixture == null) {
        await _maybeHandleFinishedMatch(fav);
        continue;
      }
      await _diffAndNotify(fav, fixture);
    }
  }

  /// Când un meci favorit NU e în lista live: poate nu a început încă, sau
  /// deja s-a terminat. Dacă snapshot-ul arată că era live, confirmăm FT
  /// printr-un fetch individual.
  Future<void> _maybeHandleFinishedMatch(Favorite fav) async {
    final snap = snapshots.get(fav.sportIndex, fav.entityId);
    if (snap == null) return;
    if (!_statusCodeIsLive(snap.statusCode)) return;

    final fixture = await _fixtureByIdFetcher(fav.sport, fav.entityId);
    if (fixture == null) return;
    if (!fixture.status.isFinished) return;

    await _emit(MatchEvent(
      kind: MatchEventKind.fullTime,
      fixture: fixture,
      displayName: fav.displayName,
    ));
    await snapshots.save(
      MatchSnapshot(
        sportIndex: fav.sportIndex,
        matchId: fav.entityId,
        homeScore: fixture.score.homeTotal,
        awayScore: fixture.score.awayTotal,
        statusCode: fixture.status.display,
        notifiedEventIds: snap.notifiedEventIds,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  Future<void> _diffAndNotify(Favorite fav, Fixture fixture) async {
    final prev = snapshots.get(fav.sportIndex, fav.entityId);
    final newStatus = fixture.status.display;
    final newHome = fixture.score.homeTotal;
    final newAway = fixture.score.awayTotal;

    // 1) Kick-off: NS/lipsă snapshot → live.
    final wasNotStartedOrMissing =
        prev == null || prev.statusCode == 'NS' || prev.statusCode == 'TBD';
    if (wasNotStartedOrMissing && fixture.status.isLive) {
      await _emit(MatchEvent(
        kind: MatchEventKind.kickoff,
        fixture: fixture,
        displayName: fav.displayName,
      ));
    }

    // 2) Schimbări de status: → HT sau → FT.
    if (prev != null && prev.statusCode != newStatus) {
      if (fixture.status == FixtureStatus.halftime) {
        await _emit(MatchEvent(
          kind: MatchEventKind.halftime,
          fixture: fixture,
          displayName: fav.displayName,
        ));
      } else if (fixture.status.isFinished) {
        await _emit(MatchEvent(
          kind: MatchEventKind.fullTime,
          fixture: fixture,
          displayName: fav.displayName,
        ));
      }
    }

    // 3) Gol / punct: scorul s-a schimbat (doar dacă aveam snapshot anterior).
    final prevHome = prev?.homeScore;
    final prevAway = prev?.awayScore;
    if (prev != null &&
        newHome != null &&
        newAway != null &&
        (prevHome != newHome || prevAway != newAway)) {
      if (newHome > (prevHome ?? 0)) {
        await _emit(MatchEvent(
          kind: MatchEventKind.goal,
          fixture: fixture,
          displayName: fav.displayName,
          scoredByHome: true,
        ));
      }
      if (newAway > (prevAway ?? 0)) {
        await _emit(MatchEvent(
          kind: MatchEventKind.goal,
          fixture: fixture,
          displayName: fav.displayName,
          scoredByHome: false,
        ));
      }
    }

    // 4) Cartonașe/incidente pentru fotbal: doar dacă s-a schimbat ceva,
    //    ca să nu facem un request în plus la fiecare ciclu.
    List<String> notifiedEventIds = prev?.notifiedEventIds ?? <String>[];
    final shouldFetchIncidents = fav.sport == SportType.football &&
        _footballEventsFetcher != null &&
        fixture.status.isLive &&
        prev != null &&
        (prev.statusCode != newStatus ||
            prev.homeScore != newHome ||
            prev.awayScore != newAway);

    if (shouldFetchIncidents) {
      try {
        final events = await _footballEventsFetcher(fixture.id);
        final newCards = events.where((e) => e.isCard).toList();
        final updated = List<String>.from(notifiedEventIds);
        for (final ev in newCards) {
          final id = _eventFingerprint(ev);
          if (updated.contains(id)) continue;
          updated.add(id);
          final who = ev.playerName ?? ev.teamName ?? 'Cartonaș';
          final colour = ev.detail ?? 'Cartonaș';
          await _emit(MatchEvent(
            kind: MatchEventKind.incident,
            fixture: fixture,
            displayName: fav.displayName,
            incidentDescription: '$colour — $who',
          ));
        }
        notifiedEventIds = updated;
      } catch (e) {
        debugPrint('[LiveMonitor] Eroare la fetch events: $e');
      }
    }

    // 5) Persistă snapshot-ul nou pentru ciclul următor.
    await snapshots.save(
      MatchSnapshot(
        sportIndex: fav.sportIndex,
        matchId: fav.entityId,
        homeScore: newHome,
        awayScore: newAway,
        statusCode: newStatus,
        notifiedEventIds: notifiedEventIds,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  Future<void> _emit(MatchEvent event) async {
    try {
      await _notify(event);
    } catch (e) {
      debugPrint('[LiveMonitor] Eroare trimitere notificare: $e');
    }
  }

  static String _eventFingerprint(FixtureEvent e) {
    return '${e.type}|${e.detail ?? ''}|${e.elapsed ?? ''}|${e.playerName ?? ''}';
  }

  static bool _statusCodeIsLive(String code) {
    return code == '1H' ||
        code == '2H' ||
        code == 'HT' ||
        code == 'OT' ||
        code == 'PEN' ||
        code == 'BT' ||
        code == 'LIVE';
  }
}
