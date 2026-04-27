class H2HEntry {
  final DateTime date;
  final String leagueName;
  final String homeName;
  final String awayName;
  final int? homeScore;
  final int? awayScore;
  final String? homeLogo;
  final String? awayLogo;

  const H2HEntry({
    required this.date,
    required this.leagueName,
    required this.homeName,
    required this.awayName,
    this.homeScore,
    this.awayScore,
    this.homeLogo,
    this.awayLogo,
  });

  factory H2HEntry.fromFootballJson(Map<String, dynamic> json) {
    final fixture = json['fixture'] as Map<String, dynamic>? ?? {};
    final teams = json['teams'] as Map<String, dynamic>? ?? {};
    final goals = json['goals'] as Map<String, dynamic>? ?? {};
    final league = json['league'] as Map<String, dynamic>? ?? {};
    final home = teams['home'] as Map<String, dynamic>? ?? {};
    final away = teams['away'] as Map<String, dynamic>? ?? {};
    return H2HEntry(
      date: DateTime.tryParse(fixture['date'] as String? ?? '') ??
          DateTime.now(),
      leagueName: league['name'] as String? ?? '',
      homeName: home['name'] as String? ?? '?',
      awayName: away['name'] as String? ?? '?',
      homeScore: goals['home'] as int?,
      awayScore: goals['away'] as int?,
      homeLogo: home['logo'] as String?,
      awayLogo: away['logo'] as String?,
    );
  }

  /// Basketball / baseball / hockey / handball API-Sports games payload.
  factory H2HEntry.fromGenericGameJson(Map<String, dynamic> json) {
    final teams = json['teams'] as Map<String, dynamic>? ?? {};
    final scores = json['scores'] as Map<String, dynamic>? ?? {};
    final league = json['league'] as Map<String, dynamic>? ?? {};
    final home = teams['home'] as Map<String, dynamic>? ?? {};
    final away = teams['away'] as Map<String, dynamic>? ?? {};
    final homeScores = scores['home'];
    final awayScores = scores['away'];
    int? hScore;
    int? aScore;
    if (homeScores is Map<String, dynamic>) {
      hScore = (homeScores['total'] as num?)?.toInt();
    } else if (homeScores is num) {
      hScore = homeScores.toInt();
    }
    if (awayScores is Map<String, dynamic>) {
      aScore = (awayScores['total'] as num?)?.toInt();
    } else if (awayScores is num) {
      aScore = awayScores.toInt();
    }
    return H2HEntry(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      leagueName: league['name'] as String? ?? '',
      homeName: home['name'] as String? ?? '?',
      awayName: away['name'] as String? ?? '?',
      homeScore: hScore,
      awayScore: aScore,
      homeLogo: home['logo'] as String?,
      awayLogo: away['logo'] as String?,
    );
  }
}
