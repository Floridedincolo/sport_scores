import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/fixture.dart';
import '../../../models/sport.dart';
import '../../../models/standing_row.dart';

class StandingsSection extends StatelessWidget {
  final List<StandingRow> rows;
  final Fixture fixture;
  final String? season;

  const StandingsSection({
    super.key,
    required this.rows,
    required this.fixture,
    this.season,
  });

  @override
  Widget build(BuildContext context) {
    final showDraw = fixture.sport == SportType.football ||
        rows.any((r) => (r.draw ?? 0) > 0);

    // Group rows by `group` (e.g. "Group A" / "Group B"); fall back to a single
    // unnamed group when the API returns flat standings.
    final groups = <String, List<StandingRow>>{};
    for (final r in rows) {
      final key = r.group?.trim().isNotEmpty == true ? r.group!.trim() : '';
      groups.putIfAbsent(key, () => []).add(r);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: false,
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textSecondary,
          title: Text(
            season != null && season!.isNotEmpty
                ? 'STANDINGS · $season'
                : 'STANDINGS',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          children: [
            for (final entry in groups.entries) ...[
              if (entry.key.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _StandingsTable(
                  rows: entry.value,
                  fixture: fixture,
                  showDraw: showDraw,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StandingsTable extends StatelessWidget {
  final List<StandingRow> rows;
  final Fixture fixture;
  final bool showDraw;

  const _StandingsTable({
    required this.rows,
    required this.fixture,
    required this.showDraw,
  });

  bool _isMatchTeam(StandingRow r) {
    if (r.teamId == fixture.homeTeam.id || r.teamId == fixture.awayTeam.id) {
      return true;
    }
    final name = r.teamName.toLowerCase();
    final home = fixture.homeTeam.name.toLowerCase();
    final away = fixture.awayTeam.name.toLowerCase();
    return name == home ||
        name == away ||
        (home.isNotEmpty && name.contains(home)) ||
        (away.isNotEmpty && name.contains(away)) ||
        (name.isNotEmpty && home.contains(name)) ||
        (name.isNotEmpty && away.contains(name));
  }

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columnSpacing: 12,
      horizontalMargin: 12,
      headingRowHeight: 32,
      dataRowMinHeight: 32,
      dataRowMaxHeight: 36,
      headingTextStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      dataTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12,
      ),
      columns: [
        const DataColumn(label: Text('#')),
        const DataColumn(label: Text('Team')),
        const DataColumn(label: Text('P'), numeric: true),
        const DataColumn(label: Text('W'), numeric: true),
        if (showDraw) const DataColumn(label: Text('D'), numeric: true),
        const DataColumn(label: Text('L'), numeric: true),
        const DataColumn(label: Text('Pts'), numeric: true),
      ],
      rows: [
        for (final r in rows)
          DataRow(
            color: WidgetStateProperty.resolveWith((_) {
              if (_isMatchTeam(r)) {
                return AppColors.accent.withValues(alpha: 0.15);
              }
              return null;
            }),
            cells: [
              DataCell(Text(r.rank.toString())),
              DataCell(SizedBox(
                width: 140,
                child: Text(
                  r.teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )),
              DataCell(Text(r.played.toString())),
              DataCell(Text((r.win ?? 0).toString())),
              if (showDraw) DataCell(Text((r.draw ?? 0).toString())),
              DataCell(Text((r.lose ?? 0).toString())),
              DataCell(Text((r.points ?? 0).toString())),
            ],
          ),
      ],
    );
  }
}
