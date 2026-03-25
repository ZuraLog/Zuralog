library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/pattern_progress_bar.dart';

class NextAchievementCard extends StatelessWidget {
  const NextAchievementCard({
    super.key,
    required this.achievement,
    required this.onTap,
  });

  final Achievement achievement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = achievement.progressCurrent ?? 0;
    final total = achievement.progressTotal ?? 1;
    final fraction = (total > 0) ? (current / total).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.progressSurface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border(
            top: BorderSide(
              color: AppColors.progressStreakWarm,
              width: 3,
            ),
            left: BorderSide(color: AppColors.progressBorderDefault),
            right: BorderSide(color: AppColors.progressBorderDefault),
            bottom: BorderSide(color: AppColors.progressBorderDefault),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.progressSurfaceRaised,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Center(
                child: Text(
                  achievement.iconName,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.progressTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    achievement.description,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.progressTextMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  Row(
                    children: [
                      Expanded(
                        child: PatternProgressBar(fraction: fraction),
                      ),
                      const SizedBox(width: AppDimens.spaceSm),
                      Text(
                        achievement.progressLabel ?? '$current/$total',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.progressTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
