// zuralog/lib/features/today/presentation/widgets/body_now/body_now_metrics_rail.dart
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/body/providers/pillar_metrics_providers.dart';
import 'package:zuralog/shared/widgets/metric_chip.dart';

enum BodyNowChip { nutrition, fitness, sleep, heart }

class BodyNowMetricsRail extends StatelessWidget {
  const BodyNowMetricsRail({
    super.key,
    required this.metrics,
    required this.onChipTapped,
  });

  final PillarMetrics metrics;
  final void Function(BodyNowChip chip) onChipTapped;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final deep = Color.alphaBlend(
      colors.textPrimary.withValues(alpha: 0.02),
      AppColors.canvas,
    );

    return Container(
      decoration: BoxDecoration(
        color: deep,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _expanded(context, chip: _nutritionChip(metrics), divider: true),
          _expanded(context, chip: _fitnessChip(metrics), divider: true),
          _expanded(context, chip: _sleepChip(metrics), divider: true),
          _expanded(context, chip: _heartChip(metrics), divider: false),
        ],
      ),
    );
  }

  Widget _expanded(BuildContext context,
      {required MetricChip chip, required bool divider}) {
    final colors = AppColorsOf(context);
    return Expanded(
      child: Row(
        children: [
          Expanded(child: chip),
          if (divider)
            Container(width: 1, height: 48, color: colors.divider),
        ],
      ),
    );
  }

  MetricChip _nutritionChip(PillarMetrics m) {
    final val = m.caloriesKcal;
    final prev = m.caloriesPrevKcal;
    final delta = (val != null && prev != null) ? val - prev : null;
    return MetricChip(
      label: 'Nutrition',
      value: val?.toString(),
      unit: 'kcal',
      delta: delta == null
          ? null
          : '${delta >= 0 ? '+' : ''}$delta',
      deltaColor: delta == null
          ? null
          : (delta >= 0 ? AppColors.categoryActivity : AppColors.categoryHeart),
      accent: AppColors.categoryNutrition,
      onTap: () => onChipTapped(BodyNowChip.nutrition),
    );
  }

  MetricChip _fitnessChip(PillarMetrics m) {
    final val = m.stepsToday;
    final prev = m.stepsPrev;
    final delta = (val != null && prev != null) ? val - prev : null;
    return MetricChip(
      label: 'Fitness',
      value: val == null ? null : _formatSteps(val),
      unit: 'steps',
      delta: delta == null
          ? null
          : '${delta >= 0 ? '+' : ''}${_formatSteps(delta.abs())}',
      deltaColor: delta == null
          ? null
          : (delta >= 0 ? AppColors.categoryActivity : AppColors.categoryHeart),
      accent: AppColors.categoryActivity,
      onTap: () => onChipTapped(BodyNowChip.fitness),
    );
  }

  MetricChip _sleepChip(PillarMetrics m) {
    final val = m.sleepHours;
    final prev = m.sleepHoursPrev;
    final delta = (val != null && prev != null) ? val - prev : null;
    return MetricChip(
      label: 'Sleep',
      value: val == null ? null : _formatSleep(val),
      delta: delta == null
          ? null
          : '${delta >= 0 ? '+' : ''}${delta.abs().toStringAsFixed(1)}h',
      deltaColor: delta == null
          ? null
          : (delta >= 0 ? AppColors.categoryActivity : AppColors.categoryHeart),
      accent: AppColors.categorySleep,
      onTap: () => onChipTapped(BodyNowChip.sleep),
    );
  }

  MetricChip _heartChip(PillarMetrics m) {
    final val = m.avgHrBpm;
    final prev = m.avgHrBpmPrev;
    final delta = (val != null && prev != null) ? val - prev : null;
    return MetricChip(
      label: 'Heart',
      value: val?.toString(),
      unit: 'bpm',
      delta: delta == null
          ? null
          : '${delta >= 0 ? '+' : ''}$delta bpm',
      // Higher avg HR is worse for resting baseline, green when delta <= 0.
      deltaColor: delta == null
          ? null
          : (delta <= 0 ? AppColors.categoryActivity : AppColors.categoryHeart),
      accent: AppColors.categoryHeart,
      onTap: () => onChipTapped(BodyNowChip.heart),
    );
  }

  static String _formatSteps(int steps) {
    if (steps >= 1000) {
      final k = steps / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
    }
    return steps.toString();
  }

  static String _formatSleep(double hours) {
    final h = hours.truncate();
    final m = ((hours - h) * 60).round();
    return '$h:${m.toString().padLeft(2, '0')}';
  }
}
