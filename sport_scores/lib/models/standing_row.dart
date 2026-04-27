class StandingRow {
  final int rank;
  final int teamId;
  final String teamName;
  final String? teamLogo;
  final int played;
  final int? win;
  final int? draw;
  final int? lose;
  final int? goalsFor;
  final int? goalsAgainst;
  final int? points;
  final String? form;
  final String? group;

  const StandingRow({
    required this.rank,
    required this.teamId,
    required this.teamName,
    this.teamLogo,
    required this.played,
    this.win,
    this.draw,
    this.lose,
    this.goalsFor,
    this.goalsAgainst,
    this.points,
    this.form,
    this.group,
  });

  /// API-Sports football `/standings` row.
  factory StandingRow.fromFootballJson(Map<String, dynamic> json) {
    final team = json['team'] as Map<String, dynamic>? ?? {};
    final all = json['all'] as Map<String, dynamic>? ?? {};
    final goals = all['goals'] as Map<String, dynamic>? ?? {};
    return StandingRow(
      rank: json['rank'] as int? ?? 0,
      teamId: team['id'] as int? ?? 0,
      teamName: team['name'] as String? ?? '?',
      teamLogo: team['logo'] as String?,
      played: all['played'] as int? ?? 0,
      win: all['win'] as int?,
      draw: all['draw'] as int?,
      lose: all['lose'] as int?,
      goalsFor: goals['for'] as int?,
      goalsAgainst: goals['against'] as int?,
      points: json['points'] as int?,
      form: json['form'] as String?,
      group: json['group'] as String?,
    );
  }

  /// API-Sports generic (basketball/baseball/hockey/handball) `/standings` row.
  factory StandingRow.fromGenericJson(Map<String, dynamic> json) {
    final team = json['team'] as Map<String, dynamic>? ?? {};
    final games = json['games'] as Map<String, dynamic>? ?? {};
    final win = games['win'] as Map<String, dynamic>?;
    final lose = games['lose'] as Map<String, dynamic>?;
    final draw = games['draw'] as Map<String, dynamic>?;
    int? toInt(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }

    return StandingRow(
      rank: toInt(json['position']) ?? toInt(json['rank']) ?? 0,
      teamId: toInt(team['id']) ?? 0,
      teamName: team['name'] as String? ?? '?',
      teamLogo: team['logo'] as String?,
      played: toInt(games['played']) ?? 0,
      win: toInt(win?['total']) ?? toInt(win),
      draw: toInt(draw?['total']) ?? toInt(draw),
      lose: toInt(lose?['total']) ?? toInt(lose),
      points: toInt(json['points']),
      group: json['group'] as String?,
    );
  }
}
