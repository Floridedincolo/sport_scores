import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/fixture.dart';

class ScoreDisplay extends StatelessWidget {
  final Fixture fixture;
  final double fontSize;

  const ScoreDisplay({
    super.key,
    required this.fixture,
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (fixture.status.isNotStarted) {
      return Text(
        _formatTime(fixture.date),
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: fontSize * 0.85,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final home = fixture.score.homeTotal?.toString() ?? '-';
    final away = fixture.score.awayTotal?.toString() ?? '-';

    return Text(
      '$home - $away',
      style: TextStyle(
        color: fixture.status.isLive ? AppColors.accent : AppColors.textPrimary,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  String _formatTime(DateTime date) {
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
