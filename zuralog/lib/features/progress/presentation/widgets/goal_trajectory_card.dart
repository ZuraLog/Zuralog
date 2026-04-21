library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/pressable_card.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';
import 'package:zuralog/shared/widgets/feedback/z_progress_bar.dart';
import 'package:zuralog/shared/widgets/indicators/z_category_icon_tile.dart';

class GoalTrajectoryCard extends StatelessWidget {
  const GoalTrajectoryCard({
    super.key,
    required this.goal,
    required this.onTap,
  });

  final Goal goal;
  final VoidCallback onTap;

  static const Map<GoalType, IconData> _iconFor = {
    GoalType.weightTarget: Icons.gps_fixed_rounded,
    GoalType.weeklyRunCount: Icons.directions_run_rounded,
    GoalType.dailyCalorieLimit: Icons.restaurant_rounded,
    GoalType.sleepDuration: Icons.bedtime_rounded,
    GoalType.stepCount: Icons.directions_walk_rounded,
    GoalType.waterIntake: Icons.water_drop_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final iconData = _iconFor[goal.type] ?? Icons.auto_awesome_rounded;
    final categoryColor = goal.type.categoryColor;
    final variant = goal.type.patternVariant;
    final pct = goal.progressFraction;
    final pctInt = (pct * 100).round();

    return PressableCard(
      onTap: onTap,
      borderRadius: AppDimens.shapeLg,
      child: ZFeatureCard(
        variant: variant,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ZCategoryIconTile(
                  color: categoryColor,
                  icon: iconData,
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.progressTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_fmt(goal.currentValue)} / ${_fmt(goal.targetValue)} ${goal.unit}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.progressTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimens.radiusButton),
                  ),
                  child: Text(
                    '$pctInt%',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),
            ZProgressBar(value: pct.clamp(0.0, 1.0)),
            const SizedBox(height: AppDimens.spaceSm),
            Row(
              children: [
                const Spacer(),
                _TrendBadge(direction: goal.trendDirection),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.direction});
  final String direction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    if (direction == 'completed') {
      return Text(
        '✓ Done',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final isOnTrack = direction == 'on_track';
    final color = isOnTrack ? AppColors.success : colors.progressStreakWarm;
    final label = isOnTrack ? '▲ On track' : '⚠ Behind';
    return Text(
      label,
      style: AppTextStyles.labelSmall.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
