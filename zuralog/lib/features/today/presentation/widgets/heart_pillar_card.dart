/// Today Tab — Heart Pillar Card.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/heart/domain/heart_models.dart';
import 'package:zuralog/shared/widgets/cards/z_pillar_card.dart';

class HeartPillarCard extends StatelessWidget {
  const HeartPillarCard({
    super.key,
    required this.summary,
    this.onTap,
  });

  final HeartDaySummary summary;
  final VoidCallback? onTap;

  String _formatDelta(double? delta) {
    if (delta == null) return '\u2013';
    final sign = delta >= 0 ? '+' : '';
    return '$sign${delta.round()}';
  }

  @override
  Widget build(BuildContext context) {
    return ZPillarCard(
      icon: Icons.favorite_rounded,
      categoryColor: AppColors.categoryHeart,
      label: 'Heart',
      headline: summary.restingHr?.round().toString() ?? '\u2013',
      headlineUnit: 'bpm',
      contextStat: 'Resting',
      secondaryStats: [
        PillarStat(
          label: 'HRV',
          value: summary.hrvMs != null
              ? '${summary.hrvMs!.round()} ms'
              : '\u2013',
        ),
        PillarStat(
          label: 'vs avg',
          value: _formatDelta(summary.restingHrVs7Day),
        ),
      ],
      onTap: onTap,
    );
  }
}
