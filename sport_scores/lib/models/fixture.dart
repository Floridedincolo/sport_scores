import 'sport.dart';
import 'league.dart';
import 'team.dart';
import 'score.dart';

enum FixtureStatus {
  notStarted,
  firstHalf,
  halftime,
  secondHalf,
  finished,
  overtime,
  penalties,
  postponed,
  cancelled,
  suspended,
  interrupted,
  breakTime,
  live,
}

extension FixtureStatusExtension on FixtureStatus {
  bool get isLive {
    return this == FixtureStatus.firstHalf ||
        this == FixtureStatus.secondHalf ||
        this == FixtureStatus.halftime ||
        this == FixtureStatus.overtime ||
        this == FixtureStatus.penalties ||
        this == FixtureStatus.breakTime ||
        this == FixtureStatus.live;
  }

  bool get isFinished => this == FixtureStatus.finished;
  bool get isNotStarted => this == FixtureStatus.notStarted;

  String get display {
    return switch (this) {
      FixtureStatus.notStarted => 'NS',
      FixtureStatus.firstHalf => '1H',
      FixtureStatus.halftime => 'HT',
      FixtureStatus.secondHalf => '2H',
      FixtureStatus.finished => 'FT',
      FixtureStatus.overtime => 'OT',
      FixtureStatus.penalties => 'PEN',
      FixtureStatus.postponed => 'PST',
      FixtureStatus.cancelled => 'CAN',
      FixtureStatus.suspended => 'SUSP',
      FixtureStatus.interrupted => 'INT',
      FixtureStatus.breakTime => 'BT',
      FixtureStatus.live => 'LIVE',
    };
  }
}

class Fixture {
  final int id;
  final SportType sport;
  final League league;
  final Team homeTeam;
  final Team awayTeam;
  final Score score;
  final DateTime date;
  final FixtureStatus status;
  final String? venue;
  final int? elapsed;
  /// Raw short-status code from the API (e.g. "Q3", "P2", "IN5").
  /// Used to display period/quarter context alongside `elapsed`
  /// for sports where `elapsed` is per-period rather than cumulative.
  final String? statusDetail;

  const Fixture({
    required this.id,
    required this.sport,
    required this.league,
    required this.homeTeam,
    required this.awayTeam,
    required this.score,
    required this.date,
    required this.status,
    this.venue,
    this.elapsed,
    this.statusDetail,
  });

  factory Fixture.fromFootballJson(Map<String, dynamic> json) {
    final fixture = json['fixture'] as Map<String, dynamic>;
    final teams = json['teams'] as Map<String, dynamic>;
    final leagueJson = json['league'] as Map<String, dynamic>;

    return Fixture(
      id: fixture['id'] as int,
      sport: SportType.football,
      league: League(
        id: leagueJson['id'] as int,
        name: leagueJson['name'] as String? ?? 'Unknown',
        country: leagueJson['country'] as String?,
        logo: leagueJson['logo'] as String?,
        countryFlag: leagueJson['flag'] as String?,
        sport: SportType.football,
        currentSeason: leagueJson['season'] as int?,
      ),
      homeTeam: Team.fromJson(teams['home'] as Map<String, dynamic>),
      awayTeam: Team.fromJson(teams['away'] as Map<String, dynamic>),
      score: Score.fromFootballJson(json),
      date: DateTime.parse(fixture['date'] as String),
      status: _parseFootballStatus(
          fixture['status']?['short'] as String? ?? 'NS'),
      venue: fixture['venue']?['name'] as String?,
      elapsed: fixture['status']?['elapsed'] as int?,
    );
  }

  factory Fixture.fromBasketballJson(Map<String, dynamic> json) {
    final teams = json['teams'] as Map<String, dynamic>;
    final leagueJson = json['league'] as Map<String, dynamic>;
    final timerVal = json['status']?['timer'];
    final shortStatus = json['status']?['short'] as String? ?? 'NS';

    return Fixture(
      id: _parseId(json['id']),
      sport: SportType.basketball,
      league: League(
        id: _parseId(leagueJson['id']),
        name: leagueJson['name'] as String? ?? 'Unknown',
        country: leagueJson['country'] as String?,
        logo: leagueJson['logo'] as String?,
        sport: SportType.basketball,
      ),
      homeTeam: Team.fromJson(teams['home'] as Map<String, dynamic>),
      awayTeam: Team.fromJson(teams['away'] as Map<String, dynamic>),
      score: Score.fromBasketballJson(json),
      date: DateTime.parse(json['date'] as String),
      status: _parseBasketballStatus(shortStatus),
      elapsed: timerVal is int ? timerVal : (timerVal is String ? int.tryParse(timerVal) : null),
      statusDetail: shortStatus,
    );
  }

  factory Fixture.fromHockeyJson(Map<String, dynamic> json) {
    final teams = json['teams'] as Map<String, dynamic>;
    final leagueJson = json['league'] as Map<String, dynamic>? ?? {};
    final scores = json['scores'] as Map<String, dynamic>?;

    int? homeTotal;
    int? awayTotal;
    if (scores != null) {
      homeTotal = _safeInt(scores['home']);
      awayTotal = _safeInt(scores['away']);
    }

    return Fixture(
      id: _parseId(json['id']),
      sport: SportType.hockey,
      league: League(
        id: _parseId(leagueJson['id']),
        name: leagueJson['name'] as String? ?? 'Unknown',
        country: leagueJson['country'] as String?,
        logo: leagueJson['logo'] as String?,
        sport: SportType.hockey,
      ),
      homeTeam: Team.fromJson(teams['home'] as Map<String, dynamic>),
      awayTeam: Team.fromJson(teams['away'] as Map<String, dynamic>),
      score: Score(homeTotal: homeTotal, awayTotal: awayTotal),
      date: DateTime.parse(json['date'] as String? ?? json['time'] as String? ?? DateTime.now().toIso8601String()),
      status: _parseGenericStatus(json['status']?['short'] as String? ?? 'NS'),
      elapsed: _safeInt(json['timer']),
      statusDetail: json['status']?['short'] as String?,
    );
  }

  factory Fixture.fromBaseballJson(Map<String, dynamic> json) {
    final teams = json['teams'] as Map<String, dynamic>;
    final leagueJson = json['league'] as Map<String, dynamic>? ?? {};
    final scores = json['scores'] as Map<String, dynamic>?;

    int? homeTotal;
    int? awayTotal;
    Map<String, List<int?>>? periods;
    if (scores != null) {
      final homeScores = scores['home'] as Map<String, dynamic>?;
      final awayScores = scores['away'] as Map<String, dynamic>?;
      homeTotal = _safeInt(homeScores?['total']);
      awayTotal = _safeInt(awayScores?['total']);

      periods = {};
      for (final key in ['innings_1', 'innings_2', 'innings_3', 'innings_4', 'innings_5',
                          'innings_6', 'innings_7', 'innings_8', 'innings_9']) {
        final h = _safeInt(homeScores?[key]);
        final a = _safeInt(awayScores?[key]);
        if (h != null || a != null) {
          periods[key] = [h, a];
        }
      }
    }

    return Fixture(
      id: _parseId(json['id']),
      sport: SportType.baseball,
      league: League(
        id: _parseId(leagueJson['id']),
        name: leagueJson['name'] as String? ?? 'Unknown',
        country: leagueJson['country'] as String?,
        logo: leagueJson['logo'] as String?,
        sport: SportType.baseball,
      ),
      homeTeam: Team.fromJson(teams['home'] as Map<String, dynamic>),
      awayTeam: Team.fromJson(teams['away'] as Map<String, dynamic>),
      score: Score(homeTotal: homeTotal, awayTotal: awayTotal, periods: periods),
      date: DateTime.parse(json['date'] as String? ?? json['time'] as String? ?? DateTime.now().toIso8601String()),
      status: _parseGenericStatus(json['status']?['short'] as String? ?? 'NS'),
      statusDetail: json['status']?['short'] as String?,
    );
  }

  factory Fixture.fromFormula1Json(Map<String, dynamic> json) {
    final competition = json['competition'] as Map<String, dynamic>? ?? {};
    final circuit = json['circuit'] as Map<String, dynamic>? ?? {};

    // F1 races don't have home/away teams — use circuit/competition info
    final raceName = json['type'] as String? ?? 'Race';

    return Fixture(
      id: _parseId(json['id']),
      sport: SportType.formula1,
      league: League(
        id: _parseId(competition['id']),
        name: competition['name'] as String? ?? 'Formula 1',
        country: competition['location']?['country'] as String?,
        logo: null,
        sport: SportType.formula1,
      ),
      homeTeam: Team(
        id: _parseId(circuit['id']),
        name: circuit['name'] as String? ?? raceName,
        logo: circuit['image'] as String?,
      ),
      awayTeam: Team(
        id: 0,
        name: raceName,
      ),
      score: const Score(),
      date: DateTime.parse(json['date'] as String? ?? DateTime.now().toIso8601String()),
      status: _parseF1Status(json['status'] as String? ?? 'Scheduled'),
      venue: circuit['name'] as String?,
    );
  }

  /// Handball from API-Sports (same structure as hockey)
  factory Fixture.fromHandballJson(Map<String, dynamic> json) {
    final teams = json['teams'] as Map<String, dynamic>;
    final leagueJson = json['league'] as Map<String, dynamic>? ?? {};
    final scores = json['scores'] as Map<String, dynamic>?;

    int? homeTotal;
    int? awayTotal;
    if (scores != null) {
      homeTotal = _safeInt(scores['home']);
      awayTotal = _safeInt(scores['away']);
    }

    return Fixture(
      id: _parseId(json['id']),
      sport: SportType.handball,
      league: League(
        id: _parseId(leagueJson['id']),
        name: leagueJson['name'] as String? ?? 'Unknown',
        country: json['country']?['name'] as String?,
        logo: leagueJson['logo'] as String?,
        sport: SportType.handball,
      ),
      homeTeam: Team.fromJson(teams['home'] as Map<String, dynamic>),
      awayTeam: Team.fromJson(teams['away'] as Map<String, dynamic>),
      score: Score(homeTotal: homeTotal, awayTotal: awayTotal),
      date: DateTime.parse(json['date'] as String? ?? DateTime.now().toIso8601String()),
      status: _parseGenericStatus(json['status']?['short'] as String? ?? 'NS'),
      statusDetail: json['status']?['short'] as String?,
    );
  }

  /// The Odds API (https://the-odds-api.com) — used as fallback when
  /// API-Sports returns no events. Payload has string team names, optional
  /// `scores` list ([{name, score}, ...]) and a `completed` boolean.
  factory Fixture.fromOddsApiJson(Map<String, dynamic> json, SportType sport) {
    final rawId = json['id'];
    final id = rawId is String
        ? rawId.hashCode & 0x7fffffff
        : _parseId(rawId);

    final homeName = json['home_team'] as String? ?? 'Home';
    final awayName = json['away_team'] as String? ?? 'Away';
    final commence = json['commence_time'] as String?;
    final completed = json['completed'] as bool? ?? false;
    final sportTitle = json['sport_title'] as String? ?? sport.name;

    int? homeScore;
    int? awayScore;
    final scoresList = json['scores'];
    if (scoresList is List) {
      for (final s in scoresList) {
        if (s is! Map<String, dynamic>) continue;
        final name = s['name'] as String?;
        final scoreStr = s['score']?.toString();
        final score = scoreStr != null ? int.tryParse(scoreStr) : null;
        if (name == null || score == null) continue;
        if (name == homeName) {
          homeScore = score;
        } else if (name == awayName) {
          awayScore = score;
        }
      }
    }

    final date = commence != null ? DateTime.parse(commence) : DateTime.now();
    final FixtureStatus status;
    if (completed) {
      status = FixtureStatus.finished;
    } else if (scoresList is List &&
        scoresList.isNotEmpty &&
        date.isBefore(DateTime.now())) {
      status = FixtureStatus.live;
    } else {
      status = FixtureStatus.notStarted;
    }

    return Fixture(
      id: id,
      sport: sport,
      league: League(
        id: 0,
        name: sportTitle,
        sport: sport,
      ),
      homeTeam: Team(id: homeName.hashCode & 0x7fffffff, name: homeName),
      awayTeam: Team(id: awayName.hashCode & 0x7fffffff, name: awayName),
      score: Score(homeTotal: homeScore, awayTotal: awayScore),
      date: date,
      status: status,
    );
  }

  /// Tennis/generic from SportsAPIPro V2 events
  factory Fixture.fromSportsApiProJson(Map<String, dynamic> json, SportType sport) {
    final homeTeam = json['homeTeam'] as Map<String, dynamic>? ?? {};
    final awayTeam = json['awayTeam'] as Map<String, dynamic>? ?? {};
    final tournament = json['tournament'] as Map<String, dynamic>? ?? {};
    final category = tournament['category'] as Map<String, dynamic>? ?? {};
    final homeScore = json['homeScore'] as Map<String, dynamic>?;
    final awayScore = json['awayScore'] as Map<String, dynamic>?;
    final status = json['status'] as Map<String, dynamic>? ?? {};
    final startTimestamp = json['startTimestamp'] as int?;

    // For tennis, group by category (ATP / WTA / Challenger / etc.) instead of
    // by individual tournament so the home screen can split ATP vs WTA cleanly.
    final League league;
    if (sport == SportType.tennis) {
      final categoryName = category['name'] as String? ?? 'Other';
      league = League(
        id: _parseId(category['id']),
        name: categoryName,
        country: null,
        logo: null,
        sport: sport,
      );
    } else {
      league = League(
        id: _parseId(tournament['uniqueTournament']?['id'] ?? tournament['id']),
        name: tournament['name'] as String? ?? 'Unknown',
        country: category['name'] as String?,
        logo: null,
        sport: sport,
      );
    }

    return Fixture(
      id: _parseId(json['id']),
      sport: sport,
      league: league,
      homeTeam: Team(
        id: _parseId(homeTeam['id']),
        name: homeTeam['name'] as String? ?? 'Player 1',
        logo: null,
      ),
      awayTeam: Team(
        id: _parseId(awayTeam['id']),
        name: awayTeam['name'] as String? ?? 'Player 2',
        logo: null,
      ),
      score: Score(
        homeTotal: _safeInt(homeScore?['current']),
        awayTotal: _safeInt(awayScore?['current']),
      ),
      date: startTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(startTimestamp * 1000, isUtc: true)
          : DateTime.now(),
      status: _parseSportsApiProStatus(status['type'] as String? ?? 'notstarted'),
    );
  }

  static FixtureStatus _parseSportsApiProStatus(String type) {
    return switch (type) {
      'finished' => FixtureStatus.finished,
      'inprogress' => FixtureStatus.live,
      'notstarted' => FixtureStatus.notStarted,
      'canceled' || 'cancelled' => FixtureStatus.cancelled,
      'postponed' => FixtureStatus.postponed,
      _ => FixtureStatus.notStarted,
    };
  }

  static int? _safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  static int _parseId(dynamic id) {
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    return 0;
  }

  static FixtureStatus _parseFootballStatus(String short) {
    return switch (short) {
      'TBD' || 'NS' => FixtureStatus.notStarted,
      '1H' => FixtureStatus.firstHalf,
      'HT' => FixtureStatus.halftime,
      '2H' => FixtureStatus.secondHalf,
      'FT' || 'AET' => FixtureStatus.finished,
      'ET' => FixtureStatus.overtime,
      'P' || 'PEN' => FixtureStatus.penalties,
      'PST' => FixtureStatus.postponed,
      'CANC' => FixtureStatus.cancelled,
      'SUSP' => FixtureStatus.suspended,
      'INT' => FixtureStatus.interrupted,
      'BT' => FixtureStatus.breakTime,
      'LIVE' => FixtureStatus.live,
      _ => FixtureStatus.notStarted,
    };
  }

  static FixtureStatus _parseBasketballStatus(String short) {
    return switch (short) {
      'NS' => FixtureStatus.notStarted,
      'Q1' || 'Q2' || 'Q3' || 'Q4' => FixtureStatus.live,
      'HT' => FixtureStatus.halftime,
      'BT' => FixtureStatus.breakTime,
      'OT' => FixtureStatus.overtime,
      'FT' || 'AOT' => FixtureStatus.finished,
      'POST' => FixtureStatus.postponed,
      'CANC' => FixtureStatus.cancelled,
      _ => FixtureStatus.notStarted,
    };
  }

  static FixtureStatus _parseGenericStatus(String short) {
    return switch (short) {
      'NS' || 'TBD' => FixtureStatus.notStarted,
      'P1' || 'P2' || 'P3' || 'Q1' || 'Q2' || 'Q3' || 'Q4' => FixtureStatus.live,
      'IN1' || 'IN2' || 'IN3' || 'IN4' || 'IN5' || 'IN6' || 'IN7' || 'IN8' || 'IN9' => FixtureStatus.live,
      'HT' => FixtureStatus.halftime,
      'BT' => FixtureStatus.breakTime,
      'OT' => FixtureStatus.overtime,
      'FT' || 'AOT' || 'AP' => FixtureStatus.finished,
      'POST' || 'PST' => FixtureStatus.postponed,
      'CANC' => FixtureStatus.cancelled,
      'SUSP' => FixtureStatus.suspended,
      _ => FixtureStatus.notStarted,
    };
  }

  static FixtureStatus _parseF1Status(String status) {
    return switch (status.toLowerCase()) {
      'completed' || 'finished' => FixtureStatus.finished,
      'live' || 'in progress' => FixtureStatus.live,
      'cancelled' => FixtureStatus.cancelled,
      'postponed' => FixtureStatus.postponed,
      _ => FixtureStatus.notStarted,
    };
  }
}
