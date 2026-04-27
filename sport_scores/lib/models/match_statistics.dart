class StatPair {
  final String label;
  final String homeValue;
  final String awayValue;
  /// 0..1 if numeric/percent representation makes sense for bar rendering.
  final double? homeRatio;
  final double? awayRatio;

  const StatPair({
    required this.label,
    required this.homeValue,
    required this.awayValue,
    this.homeRatio,
    this.awayRatio,
  });
}

class MatchStatistics {
  final List<StatPair> pairs;

  const MatchStatistics({required this.pairs});

  bool get isEmpty => pairs.isEmpty;
  bool get isNotEmpty => pairs.isNotEmpty;

  /// API-Sports football: response is a list with two team blocks, each having
  /// `statistics: [{type, value}, ...]`.
  factory MatchStatistics.fromFootballJson(List<dynamic> data) {
    if (data.length < 2) return const MatchStatistics(pairs: []);
    final home = data[0] as Map<String, dynamic>;
    final away = data[1] as Map<String, dynamic>;
    final homeStats = (home['statistics'] as List?) ?? [];
    final awayStats = (away['statistics'] as List?) ?? [];

    final awayMap = <String, dynamic>{};
    for (final s in awayStats) {
      if (s is Map<String, dynamic>) {
        awayMap[s['type'] as String? ?? ''] = s['value'];
      }
    }

    final pairs = <StatPair>[];
    for (final s in homeStats) {
      if (s is! Map<String, dynamic>) continue;
      final type = s['type'] as String? ?? '';
      final h = s['value'];
      final a = awayMap[type];
      final hStr = _format(h);
      final aStr = _format(a);
      if (hStr == '-' && aStr == '-') continue;
      final ratios = _ratios(h, a);
      pairs.add(StatPair(
        label: type,
        homeValue: hStr,
        awayValue: aStr,
        homeRatio: ratios?[0],
        awayRatio: ratios?[1],
      ));
    }
    return MatchStatistics(pairs: pairs);
  }

  /// API-Sports basketball/baseball/hockey/handball: `/games/statistics/teams`.
  /// Response is a list of two team blocks; each block has flat fields.
  factory MatchStatistics.fromTeamGameStats(List<dynamic> data) {
    if (data.length < 2) return const MatchStatistics(pairs: []);
    final home = data[0] as Map<String, dynamic>;
    final away = data[1] as Map<String, dynamic>;

    // Skip team object, pull other top-level scalar/string fields.
    final pairs = <StatPair>[];
    final keys = <String>{...home.keys, ...away.keys}
      ..removeAll(['team', 'game']);
    for (final key in keys) {
      final h = home[key];
      final a = away[key];
      // Recursively unwrap nested {total: x, ...} maps
      final hVal = _unwrap(h);
      final aVal = _unwrap(a);
      final hStr = _format(hVal);
      final aStr = _format(aVal);
      if (hStr == '-' && aStr == '-') continue;
      final ratios = _ratios(hVal, aVal);
      pairs.add(StatPair(
        label: _humanize(key),
        homeValue: hStr,
        awayValue: aStr,
        homeRatio: ratios?[0],
        awayRatio: ratios?[1],
      ));
    }
    return MatchStatistics(pairs: pairs);
  }

  static dynamic _unwrap(dynamic v) {
    if (v is Map && v.containsKey('total')) return v['total'];
    return v;
  }

  static String _format(dynamic v) {
    if (v == null) return '-';
    if (v is num) return v.toString();
    if (v is String) return v.isEmpty ? '-' : v;
    return v.toString();
  }

  static List<double>? _ratios(dynamic h, dynamic a) {
    final hn = _toNum(h);
    final an = _toNum(a);
    if (hn == null || an == null) return null;
    final total = hn + an;
    if (total <= 0) return [0, 0];
    return [hn / total, an / total];
  }

  static double? _toNum(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final cleaned = v.replaceAll('%', '').trim();
      return double.tryParse(cleaned);
    }
    return null;
  }

  static String _humanize(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
