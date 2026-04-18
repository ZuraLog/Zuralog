/// Today Tab — Heart Pillar Card.
// TODO(backend): Replace hardwired data with provider data.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/shared/widgets/cards/z_pillar_card.dart';

class HeartPillarCard extends StatelessWidget {
  const HeartPillarCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ZPillarCard(
      icon: Icons.favorite_rounded,
      categoryColor: AppColors.categoryHeart,
      label: 'Heart',
      headline: '62',
      headlineUnit: 'bpm',
      contextStat: 'Resting',
      secondaryStats: const [
        PillarStat(label: 'HRV', value: '48 ms'),
        PillarStat(label: 'Range', value: '58\u2013142'),
        PillarStat(label: 'vs avg', value: '\u22123'),
      ],
      onTap: onTap,
    );
  }
}
