/// Today Tab — Sleep Pillar Card.
// TODO(backend): Replace hardwired data with provider data.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/shared/widgets/cards/z_pillar_card.dart';

class SleepPillarCard extends StatelessWidget {
  const SleepPillarCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ZPillarCard(
      icon: Icons.bedtime_rounded,
      categoryColor: AppColors.categorySleep,
      label: 'Sleep',
      headline: '7h 24m',
      contextStat: 'Good',
      secondaryStats: const [
        PillarStat(label: 'Bed', value: '11:12 PM'),
        PillarStat(label: 'Wake', value: '6:36 AM'),
        PillarStat(label: 'Deep', value: '1h 48m'),
      ],
      onTap: onTap,
    );
  }
}
