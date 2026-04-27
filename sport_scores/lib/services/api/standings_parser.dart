import '../../models/standing_row.dart';

/// API-Sports basketball/baseball/hockey/handball `/standings` endpoint can return:
///   - a flat list of group/league wrappers each containing nested rows, or
///   - a list of rows directly.
/// This walks the structure defensively to extract a flat list of rows.
List<StandingRow> parseGenericStandings(List<dynamic> data) {
  final rows = <StandingRow>[];

  void visit(dynamic node) {
    if (node is Map<String, dynamic>) {
      if (node.containsKey('team') && node.containsKey('games')) {
        rows.add(StandingRow.fromGenericJson(node));
      } else if (node.containsKey('team') &&
          (node.containsKey('position') || node.containsKey('rank'))) {
        rows.add(StandingRow.fromGenericJson(node));
      } else {
        for (final v in node.values) {
          visit(v);
        }
      }
    } else if (node is List) {
      for (final v in node) {
        visit(v);
      }
    }
  }

  visit(data);
  rows.sort((a, b) {
    final g = (a.group ?? '').compareTo(b.group ?? '');
    if (g != 0) return g;
    return a.rank.compareTo(b.rank);
  });
  return rows;
}
