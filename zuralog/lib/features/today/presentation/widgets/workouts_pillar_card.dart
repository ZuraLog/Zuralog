/// Today Tab — Workouts Pillar Card.
// TODO(backend): Replace hardwired data with provider data.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/shared/widgets/cards/z_pillar_card.dart';

class WorkoutsPillarCard extends StatelessWidget {
  const WorkoutsPillarCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ZPillarCard(
      icon: Icons.directions_run_rounded,
      categoryColor: AppColors.categoryActivity,
      label: 'Workouts',
      headline: '5.2 km',
      contextStat: 'Run',
      secondaryStats: const [
        PillarStat(label: 'Steps', value: '8,420'),
        PillarStat(label: 'Active', value: '42 min'),
        PillarStat(label: 'Burned', value: '380 kcal'),
      ],
      onTap: onTap,
    );
  }
}
