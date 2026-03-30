library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/pattern_progress_bar.dart';
import 'package:zuralog/features/progress/presentation/widgets/pressable_card.dart';

class GoalTrajectoryCard extends StatelessWidget {
  const GoalTrajectoryCard({
    super.key,
    required this.goal,
    required this.onTap,
  });

  final Goal goal;
  final VoidCallback onTap;

  static const Map<GoalType, (IconData, Color)> _typeInfo = {
    GoalType.weightTarget: (Icons.gps_fixed_rounded, Color(0xFF64D2FF)),
    GoalType.weeklyRunCount: (Icons.directions_run_rounded, Color(0xFF30D158)),
    GoalType.dailyCalorieLimit: (Icons.restaurant_rounded, Color(0xFFFF9F0A)),
    GoalType.sleepDuration: (Icons.bedtime_rounded, Color(0xFF5E5CE6)),
    GoalType.stepCount: (Icons.directions_walk_rounded, Color(0xFF30D158)),
    GoalType.waterIntake: (Icons.water_drop_rounded, Color(0xFF64D2FF)),
  };

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final typeData = _typeInfo[goal.type];
    final iconData = typeData?.$1 ?? Icons.auto_awesome_rounded;
    final color = typeData?.$2 ?? colors.progressSage;
    final pct = goal.progressFraction;
    final pctInt = (pct * 100).round();

    final badgeColor = (goal.trendDirection == 'completed' ||
            goal.trendDirection == 'on_track')
        ? AppColors.statusConnected
        : colors.progressStreakWarm;
    final pctColor = badgeColor;

    return PressableCard(
      onTap: onTap,
      borderRadius: AppDimens.radiusCard,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: colors.progressSurface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: colors.progressBorderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: AppDimens.iconContainerSm,
                  height: AppDimens.iconContainerSm,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Center(
                    child: Icon(iconData, size: 16, color: color),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: Text(
                    goal.title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.progressTextPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceSm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: pctColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimens.radiusButton),
                  ),
                  child: Text(
                    '$pctInt%',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: pctColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),
            PatternProgressBar(fraction: pct),
            const SizedBox(height: AppDimens.spaceXs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_fmt(goal.currentValue)} / ${_fmt(goal.targetValue)} ${goal.unit}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.progressTextMuted,
                    ),
                  ),
                ),
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
    if (direction == 'completed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.statusConnected.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusButton),
        ),
        child: Text(
          '✓ Done',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.statusConnected,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    final colors = AppColorsOf(context);
    final isOnTrack = direction == 'on_track';
    final color = isOnTrack ? AppColors.statusConnected : colors.progressStreakWarm;
    final label = isOnTrack ? '▲ On track' : '⚠ Behind';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusButton),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
