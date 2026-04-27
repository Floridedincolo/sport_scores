import 'package:flutter/foundation.dart';
import '../models/fixture.dart';
import '../models/league.dart';
import '../models/sport.dart';
import '../services/api/sport_api_factory.dart';

enum LoadingState { idle, loading, loaded, error }

class FixturesProvider extends ChangeNotifier {
  final SportApiFactory _apiFactory;

  FixturesProvider(this._apiFactory);

  LoadingState _liveState = LoadingState.idle;
  LoadingState _dateState = LoadingState.idle;
  String? _errorMessage;

  List<Fixture> _liveFixtures = [];
  List<Fixture> _dateFixtures = [];
  DateTime _selectedDate = DateTime.now();
  League? _selectedLeague;

  LoadingState get liveState => _liveState;
  LoadingState get dateState => _dateState;
  String? get errorMessage => _errorMessage;
  List<Fixture> get liveFixtures => _liveFixtures;
  DateTime get selectedDate => _selectedDate;
  League? get selectedLeague => _selectedLeague;

  /// All fixtures for the selected date.
  List<Fixture> get dateFixtures => _dateFixtures;

  /// Fixtures filtered by selected league (or all if no league selected).
  List<Fixture> get filteredFixtures {
    if (_selectedLeague == null) return _dateFixtures;
    return _dateFixtures.where((f) => f.league.id == _selectedLeague!.id).toList();
  }

  /// Filtered fixtures grouped by league, popular leagues first.
  Map<League, List<Fixture>> get filteredByLeague {
    final map = <League, List<Fixture>>{};
    for (final f in filteredFixtures) {
      map.putIfAbsent(f.league, () => []).add(f);
    }
    final popular = _popularLeagueIds[_currentSport] ?? {};
    final sortedEntries = map.entries.toList()..sort((a, b) {
      final aPop = popular.contains(a.key.id);
      final bPop = popular.contains(b.key.id);
      if (aPop && !bPop) return -1;
      if (!aPop && bPop) return 1;
      return a.key.name.compareTo(b.key.name);
    });
    return Map.fromEntries(sortedEntries);
  }

  // Popular league IDs per sport (API-Sports IDs) — shown first in filters
  static const _popularLeagueIds = <SportType, Set<int>>{
    // Liga I (283) listed first so Superliga României appears at top.
    SportType.football: {283, 39, 140, 135, 78, 61, 2, 3, 848},
    SportType.basketball: {12},
    SportType.hockey: {57},
    SportType.baseball: {1},
    SportType.formula1: {1},
    // EHF Champions League Men/Women (1, 2) + EHF EURO (3, 4) + popular leagues
    SportType.handball: {1, 2, 3, 4, 29, 30, 31, 34, 35, 120},
    SportType.tennis: {},
  };

  /// All distinct leagues from the loaded date fixtures, popular ones first.
  List<League> get availableLeagues {
    final seen = <int>{};
    final leagues = <League>[];
    for (final f in _dateFixtures) {
      if (seen.add(f.league.id)) {
        leagues.add(f.league);
      }
    }
    final popular = _popularLeagueIds[_currentSport] ?? {};
    leagues.sort((a, b) {
      final aPop = popular.contains(a.id);
      final bPop = popular.contains(b.id);
      if (aPop && !bPop) return -1;
      if (!aPop && bPop) return 1;
      return a.name.compareTo(b.name);
    });
    return leagues;
  }

  SportType _currentSport = SportType.football;

  void selectDate(DateTime date) {
    _selectedDate = date;
    _selectedLeague = null;
    notifyListeners();
  }

  void selectLeague(League? league) {
    _selectedLeague = league;
    notifyListeners();
  }

  Future<void> fetchLiveFixtures(SportType sport) async {
    _liveState = LoadingState.loading;
    notifyListeners();
    try {
      _liveFixtures = switch (sport) {
        SportType.football => await _apiFactory.football.getLiveFixtures(),
        SportType.basketball => await _apiFactory.basketball.getLiveGames(),
        SportType.hockey => await _apiFactory.hockey.getLiveGames(),
        SportType.baseball => await _apiFactory.baseball.getLiveGames(),
        SportType.formula1 => await _apiFactory.formula1.getLiveRaces(),
        SportType.handball => await _apiFactory.handball.getLiveGames(),
        SportType.tennis => await _apiFactory.sportsApiPro.getLiveFixtures(SportType.tennis),
      };
      _liveFixtures = _liveFixtures.where((f) => f.status.isLive).toList();
      _liveState = LoadingState.loaded;
    } catch (e) {
      _liveState = LoadingState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> fetchDateFixtures(SportType sport, {DateTime? date}) async {
    _currentSport = sport;
    if (date != null) {
      _selectedDate = date;
      _selectedLeague = null;
    }
    _dateState = LoadingState.loading;
    notifyListeners();
    try {
      _dateFixtures = switch (sport) {
        SportType.football =>
          await _apiFactory.football.getFixturesByDate(_selectedDate),
        SportType.basketball =>
          await _apiFactory.basketball.getGamesByDate(_selectedDate),
        SportType.hockey =>
          await _apiFactory.hockey.getGamesByDate(_selectedDate),
        SportType.baseball =>
          await _apiFactory.baseball.getGamesByDate(_selectedDate),
        SportType.formula1 =>
          await _apiFactory.formula1.getRacesByDate(_selectedDate),
        SportType.handball =>
          await _apiFactory.handball.getGamesByDate(_selectedDate),
        SportType.tennis =>
          await _apiFactory.sportsApiPro.getFixturesByDate(SportType.tennis, _selectedDate),
      };
      _dateState = LoadingState.loaded;
    } catch (e) {
      _dateState = LoadingState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Fetch all F1 races for the season (for Upcoming/Finished view).
  Future<void> fetchAllF1Races() async {
    _currentSport = SportType.formula1;
    _dateState = LoadingState.loading;
    notifyListeners();
    try {
      final now = DateTime.now();
      final season = now.year > 2024 ? 2024 : now.year;
      final data = await _apiFactory.formula1.getAllRaces(season);
      _dateFixtures = data;
      _dateState = LoadingState.loaded;
    } catch (e) {
      _dateState = LoadingState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> refreshAll(SportType sport) async {
    await Future.wait([
      fetchLiveFixtures(sport),
      sport == SportType.formula1
          ? fetchAllF1Races()
          : fetchDateFixtures(sport),
    ]);
  }
}
