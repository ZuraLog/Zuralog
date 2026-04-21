/// Hero section of the Goal Detail page.
///
/// Wears the goal's category-colored topographic pattern via [ZHeroCard],
/// shows a 130×130 progress ring with a pattern-filled animated %,
/// a current value + target, a trend tag, and a 3-stat footer
/// (remaining / days left / streak).
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/goal_metrics.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_visuals.dart';
import 'package:zuralog/features/progress/presentation/widgets/pattern_fill.dart';
import 'package:zuralog/shared/widgets/cards/z_hero_card.dart';
import 'package:zuralog/shared/widgets/charts/z_goal_progress_ring.dart';

class GoalDetailHero extends StatelessWidget {
  const GoalDetailHero({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final visuals = goalVisuals(goal);
    final pct = (goal.currentValue / goal.targetValue).clamp(0.0, 1.0);
    final pctInt = (pct * 100).round();
    final remaining = (goal.targetValue - goal.currentValue).abs();
    final daysLeft = daysRemaining(goal);
    final streak = logStreak(goal);
    final velocity = velocityPerDay(goal);
    final isDecreasing = velocity < 0;

    return ZHeroCard(
      variant: visuals.variant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ZGoalProgressRing(
                      value: goal.currentValue,
                      goal: goal.targetValue,
                      color: visuals.color,
                      size: 130,
                      strokeWidth: 8,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PatternFill(
                          child: Text(
                            '$pctInt%',
                            style: AppTextStyles.displayLarge.copyWith(
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'COMPLETE',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: colors.textSecondary,
                            letterSpacing: 0.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmt(goal.currentValue),
                      style: AppTextStyles.displayLarge.copyWith(
                        color: colors.textPrimary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'of ${_fmt(goal.targetValue)} ${goal.unit} target',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    _TrendTag(
                      visuals: visuals,
                      isDecreasing: isDecreasing,
                      velocity: velocity,
                      unit: goal.unit,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          const Divider(color: AppColors.dividerDefault, height: 1, thickness: 1),
          const SizedBox(height: AppDimens.spaceMd),
          Row(
            children: [
              Expanded(
                child: _FootStat(
                  label: 'REMAINING',
                  value: '${_fmt(remaining)} ${goal.unit}',
                ),
              ),
              Expanded(
                child: _FootStat(
                  label: 'DAYS LEFT',
                  value: daysLeft != null ? '$daysLeft' : '—',
                ),
              ),
              Expanded(
                child: _FootStat(
                  label: 'STREAK',
                  value: '$streak ${streak == 1 ? 'day' : 'days'}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

class _TrendTag extends StatelessWidget {
  const _TrendTag({
    required this.visuals,
    required this.isDecreasing,
    required this.velocity,
    required this.unit,
  });

  final GoalVisuals visuals;
  final bool isDecreasing;
  final double velocity;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (velocity == 0) return const SizedBox.shrink();
    final arrow = isDecreasing ? '▼' : '▲';
    final word = isDecreasing ? 'DOWN' : 'UP';
    final magnitude = (velocity.abs() * 30).toStringAsFixed(1);
    final lighter = Color.lerp(Colors.white, visuals.color, 0.6) ?? visuals.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: visuals.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusButton),
      ),
      child: Text(
        '$arrow $word $magnitude $unit THIS MONTH',
        style: AppTextStyles.labelSmall.copyWith(
          color: lighter,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _FootStat extends StatelessWidget {
  const _FootStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textSecondary,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
