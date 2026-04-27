import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/fixture.dart';
import '../../../models/match_statistics.dart';

class StatsSection extends StatelessWidget {
  final MatchStatistics stats;
  final Fixture fixture;

  const StatsSection({super.key, required this.stats, required this.fixture});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'STATISTICS',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fixture.homeTeam.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    fixture.awayTeam.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          for (final pair in stats.pairs) _StatRow(pair: pair),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final StatPair pair;

  const _StatRow({required this.pair});

  @override
  Widget build(BuildContext context) {
    final showBar = pair.homeRatio != null && pair.awayRatio != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  pair.homeValue,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  pair.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  pair.awayValue,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (showBar) ...[
            const SizedBox(height: 6),
            _RatioBar(home: pair.homeRatio!, away: pair.awayRatio!),
          ],
        ],
      ),
    );
  }
}

class _RatioBar extends StatelessWidget {
  final double home;
  final double away;
  const _RatioBar({required this.home, required this.away});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            Expanded(
              flex: (home * 1000).round().clamp(0, 1000),
              child: Container(color: AppColors.accent),
            ),
            const SizedBox(width: 2),
            Expanded(
              flex: (away * 1000).round().clamp(0, 1000),
              child: Container(color: AppColors.live),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
          initiallyExpanded: true,
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textSecondary,
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          children: [child],
        ),
      ),
    );
  }
}
