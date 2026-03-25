library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class StreakTypeTile extends StatelessWidget {
  const StreakTypeTile({
    super.key,
    required this.emoji,
    required this.count,
    required this.label,
    this.isHot = false,
  });

  final String emoji;
  final int count;
  final String label;
  final bool isHot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimens.spaceSm,
        horizontal: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: isHot
            ? AppColors.progressStreakWarm.withValues(alpha: 0.08)
            : AppColors.progressSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(
          color: isHot
              ? AppColors.progressStreakWarm.withValues(alpha: 0.20)
              : AppColors.progressBorderDefault,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.progressTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.progressTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}
