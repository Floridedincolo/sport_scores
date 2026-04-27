class Score {
  final int? homeTotal;
  final int? awayTotal;
  final Map<String, List<int?>>? periods;

  const Score({
    this.homeTotal,
    this.awayTotal,
    this.periods,
  });

  static int? _safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  factory Score.fromFootballJson(Map<String, dynamic> json) {
    final goals = json['goals'] as Map<String, dynamic>?;
    final score = json['score'] as Map<String, dynamic>?;

    Map<String, List<int?>>? periods;
    if (score != null) {
      periods = {};
      for (final entry in score.entries) {
        if (entry.value is Map<String, dynamic>) {
          final p = entry.value as Map<String, dynamic>;
          periods[entry.key] = [_safeInt(p['home']), _safeInt(p['away'])];
        }
      }
    }

    return Score(
      homeTotal: _safeInt(goals?['home']),
      awayTotal: _safeInt(goals?['away']),
      periods: periods,
    );
  }

  factory Score.fromBasketballJson(Map<String, dynamic> json) {
    final scores = json['scores'] as Map<String, dynamic>?;
    if (scores == null) return const Score();

    final home = scores['home'] as Map<String, dynamic>?;
    final away = scores['away'] as Map<String, dynamic>?;

    Map<String, List<int?>>? periods;
    if (home != null && away != null) {
      periods = {};
      for (final key in ['quarter_1', 'quarter_2', 'quarter_3', 'quarter_4', 'over_time']) {
        if (home[key] != null || away[key] != null) {
          periods[key] = [_safeInt(home[key]), _safeInt(away[key])];
        }
      }
    }

    return Score(
      homeTotal: _safeInt(home?['total']),
      awayTotal: _safeInt(away?['total']),
      periods: periods,
    );
  }
}
