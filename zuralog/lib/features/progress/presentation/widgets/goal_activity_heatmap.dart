/// 30-day activity heatmap for the Goal Detail page.
///
/// Each cell tinted by daily progress intensity. Today's cell gets a halo
/// ring in the lighter category tint.
///
/// Backend follow-up: progressHistory has no per-entry date today, so we
/// derive dates by indexing backward from today assuming daily cadence.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_visuals.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';

class GoalActivityHeatmap extends StatelessWidget {
  const GoalActivityHeatmap({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final visuals = goalVisuals(goal);
    final lighter = Color.lerp(Colors.white, visuals.color, 0.6) ?? visuals.color;

    final history = goal.progressHistory;
    final lastValues = history.length >= 35 ? history.sublist(history.length - 35) : history;
    final maxV = lastValues.isEmpty ? 1.0 : lastValues.reduce((a, b) => a > b ? a : b);
    final minV = lastValues.isEmpty ? 0.0 : lastValues.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);

    return ZFeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final l in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: List.generate(35, (i) {
              final hi = lastValues.length - (35 - i);
              final v = (hi >= 0 && hi < lastValues.length) ? lastValues[hi] : 0.0;
              final isToday = i == 34;
              final intensity = v <= 0 ? 0.0 : ((v - minV) / range).clamp(0.0, 1.0);
              final cellColor = _cellColor(intensity, visuals.color);
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: cellColor,
                  borderRadius: BorderRadius.circular(4),
                  border: isToday ? Border.all(color: lighter, width: 2) : null,
                ),
                child: const SizedBox.expand(),
              );
            }),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Row(
            children: [
              Text(
                'Less',
                style: AppTextStyles.labelSmall.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(width: 6),
              for (final f in [0.0, 0.25, 0.5, 0.75, 1.0])
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: _cellColor(f, visuals.color),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              const SizedBox(width: 3),
              Text(
                'More',
                style: AppTextStyles.labelSmall.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _cellColor(double intensity, Color category) {
    if (intensity <= 0) return Colors.white.withValues(alpha: 0.05);
    if (intensity < 0.25) return category.withValues(alpha: 0.18);
    if (intensity < 0.5) return category.withValues(alpha: 0.35);
    if (intensity < 0.75) return category.withValues(alpha: 0.55);
    return category;
  }
}
