import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/theme.dart';
import '../../../models/h2h_entry.dart';

class H2HSection extends StatelessWidget {
  final List<H2HEntry> entries;

  const H2HSection({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final shown = entries.take(8).toList();
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
          title: const Text(
            'HEAD-TO-HEAD',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          children: [
            for (int i = 0; i < shown.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.border),
              _H2HTile(entry: shown[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _H2HTile extends StatelessWidget {
  final H2HEntry entry;

  const _H2HTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = entry.date.toLocal();
    final dateStr = '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    final score = (entry.homeScore != null && entry.awayScore != null)
        ? '${entry.homeScore} - ${entry.awayScore}'
        : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$dateStr · ${entry.leagueName}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _TeamLine(
                  name: entry.homeName,
                  logo: entry.homeLogo,
                  alignEnd: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  score,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: _TeamLine(
                  name: entry.awayName,
                  logo: entry.awayLogo,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamLine extends StatelessWidget {
  final String name;
  final String? logo;
  final bool alignEnd;

  const _TeamLine({required this.name, this.logo, required this.alignEnd});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (logo != null)
        CachedNetworkImage(
          imageUrl: logo!,
          width: 18,
          height: 18,
          placeholder: (_, __) => const SizedBox(width: 18, height: 18),
          errorWidget: (_, __, ___) =>
              const Icon(Icons.shield, size: 18, color: AppColors.textSecondary),
        ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ];
    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd ? children.reversed.toList() : children,
    );
  }
}
