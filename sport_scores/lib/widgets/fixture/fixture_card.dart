import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/fixture.dart';
import '../../models/sport.dart';
import '../../utils/date_utils.dart';
import 'live_badge.dart';
import 'score_display.dart';

class FixtureCard extends StatelessWidget {
  final Fixture fixture;
  final VoidCallback? onTap;

  const FixtureCard({
    super.key,
    required this.fixture,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: fixture.status.isLive
                ? AppColors.live.withValues(alpha: 0.3)
                : AppColors.border,
            width: 0.5,
          ),
        ),
        child: fixture.sport == SportType.formula1
            ? _F1Layout(fixture: fixture)
            : Row(
                children: [
                  Expanded(
                    child: _TeamColumn(
                      name: fixture.homeTeam.name,
                      logo: fixture.homeTeam.logo,
                      alignment: CrossAxisAlignment.end,
                      sport: fixture.sport,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _CenterSection(fixture: fixture),
                  ),
                  Expanded(
                    child: _TeamColumn(
                      name: fixture.awayTeam.name,
                      logo: fixture.awayTeam.logo,
                      alignment: CrossAxisAlignment.start,
                      sport: fixture.sport,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _F1Layout extends StatelessWidget {
  final Fixture fixture;

  const _F1Layout({required this.fixture});

  @override
  Widget build(BuildContext context) {
    final raceType = fixture.awayTeam.name; // "Race", "1st Qualifying", etc.
    final circuit = fixture.homeTeam.name;   // "Albert Park Circuit", etc.

    return Row(
      children: [
        // Circuit icon
        Icon(
          _raceTypeIcon(raceType),
          size: 28,
          color: _raceTypeColor(raceType),
        ),
        const SizedBox(width: 14),
        // Race info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                raceType,
                style: TextStyle(
                  color: _raceTypeColor(raceType),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                circuit,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Status badge
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (fixture.status.isLive)
              const LiveBadge()
            else if (fixture.status.isFinished)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'FT',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppDateUtils.formatDate(fixture.date),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              )
            else ...[
              Text(
                _formatTime(fixture.date),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                AppDateUtils.formatDate(fixture.date),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _formatTime(DateTime date) {
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  IconData _raceTypeIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('race') || lower.contains('sprint')) return Icons.flag;
    if (lower.contains('qualifying')) return Icons.timer;
    if (lower.contains('practice') || lower.contains('free')) return Icons.speed;
    return Icons.sports_motorsports;
  }

  Color _raceTypeColor(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('race')) return Colors.red;
    if (lower.contains('sprint')) return Colors.orange;
    if (lower.contains('qualifying')) return Colors.amber;
    return AppColors.textSecondary;
  }
}

class _TeamColumn extends StatelessWidget {
  final String name;
  final String? logo;
  final CrossAxisAlignment alignment;
  final SportType sport;

  const _TeamColumn({
    required this.name,
    this.logo,
    required this.alignment,
    required this.sport,
  });

  @override
  Widget build(BuildContext context) {
    // Tennis has no logos/icons — only names. Center the name vertically
    // so it aligns with the score instead of sticking to the top.
    final isTennis = sport == SportType.tennis;
    return Column(
      crossAxisAlignment: alignment,
      mainAxisAlignment:
          isTennis ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        if (!isTennis) ...[
          if (logo != null)
            CachedNetworkImage(
              imageUrl: logo!,
              width: 28,
              height: 28,
              placeholder: (_, __) => const SizedBox(width: 28, height: 28),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.shield, size: 28, color: AppColors.textSecondary),
            )
          else
            const Icon(Icons.shield, size: 28, color: AppColors.textSecondary),
          const SizedBox(height: 6),
        ],
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignment == CrossAxisAlignment.end
              ? TextAlign.right
              : TextAlign.left,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CenterSection extends StatelessWidget {
  final Fixture fixture;

  const _CenterSection({required this.fixture});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (fixture.status.isLive) ...[
          const LiveBadge(),
          const SizedBox(height: 4),
        ],
        ScoreDisplay(fixture: fixture),
        if (fixture.status.isLive && fixture.elapsed != null) ...[
          const SizedBox(height: 2),
          Text(
            _liveElapsedLabel(fixture),
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (fixture.status.isFinished) ...[
          const SizedBox(height: 2),
          Text(
            fixture.status.display,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
        if (fixture.status.isNotStarted) ...[
          const SizedBox(height: 2),
          Text(
            AppDateUtils.formatDate(fixture.date),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}

/// Builds the live elapsed label for a fixture. For sports where `elapsed`
/// is per-period (basketball, hockey, baseball, handball), prefixes the
/// period code (Q1/Q2/P3/IN5...) so the user doesn't think it's total
/// match time.
String _liveElapsedLabel(Fixture fixture) {
  final elapsed = fixture.elapsed;
  final detail = fixture.statusDetail;
  final perPeriod = fixture.sport == SportType.basketball ||
      fixture.sport == SportType.hockey ||
      fixture.sport == SportType.baseball ||
      fixture.sport == SportType.handball;

  if (perPeriod && detail != null && detail.isNotEmpty) {
    return elapsed != null ? "$detail · $elapsed'" : detail;
  }
  return elapsed != null ? "$elapsed'" : '';
}
