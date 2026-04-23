// zuralog/lib/features/today/presentation/widgets/body_now/body_now_metrics_rail.dart
/// Horizontal rail of four MetricChips for the hero.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/body/providers/body_now_metrics_provider.dart';
import 'package:zuralog/shared/widgets/metric_chip.dart';

class BodyNowMetricsRail extends StatelessWidget {
  const BodyNowMetricsRail({
    super.key,
    required this.metrics,
    required this.onChipTapped,
  });

  final BodyNowMetrics metrics;
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
        // 16pt radius per brand bible for inner rails inside hero cards.
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _expanded(context, chip: _readinessChip(metrics), divider: true),
          _expanded(context, chip: _hrvChip(metrics), divider: true),
          _expanded(context, chip: _rhrChip(metrics), divider: true),
          _expanded(context, chip: _sleepChip(metrics), divider: false),
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
            Container(
              width: 1,
              height: 48,
              color: colors.divider,
            ),
        ],
      ),
    );
  }

  MetricChip _readinessChip(BodyNowMetrics m) => MetricChip(
        label: 'Ready',
        value: m.readiness.value?.toString(),
        delta: m.readiness.delta == null
            ? null
            : '${m.readiness.delta! >= 0 ? '+' : ''}${m.readiness.delta} vs 7d',
        deltaColor: (m.readiness.delta ?? 0) >= 0
            ? AppColors.categoryActivity
            : AppColors.categoryHeart,
        accent: AppColors.primary,
        onTap: () => onChipTapped(BodyNowChip.readiness),
      );

  MetricChip _hrvChip(BodyNowMetrics m) => MetricChip(
        label: 'HRV',
        value: m.hrvMs?.toString(),
        unit: 'ms',
        delta: m.hrvDeltaPct == null
            ? null
            : '${m.hrvDeltaPct! >= 0 ? '↑' : '↓'} ${m.hrvDeltaPct!.abs()}%',
        deltaColor: (m.hrvDeltaPct ?? 0) >= 0
            ? AppColors.categoryActivity
            : AppColors.categoryHeart,
        accent: AppColors.categoryActivity,
        onTap: () => onChipTapped(BodyNowChip.hrv),
      );

  MetricChip _rhrChip(BodyNowMetrics m) => MetricChip(
        label: 'Rest HR',
        value: m.rhrBpm?.toString(),
        unit: 'bpm',
        delta: m.rhrDeltaBpm == null
            ? null
            : '${m.rhrDeltaBpm! <= 0 ? '↓' : '↑'} ${m.rhrDeltaBpm!.abs()} bpm',
        // For RHR, lower-is-better — green when delta ≤ 0.
        deltaColor: (m.rhrDeltaBpm ?? 0) <= 0
            ? AppColors.categoryActivity
            : AppColors.categoryHeart,
        accent: AppColors.categoryHeart,
        onTap: () => onChipTapped(BodyNowChip.rhr),
      );

  MetricChip _sleepChip(BodyNowMetrics m) => MetricChip(
        label: 'Sleep',
        value: _formatSleep(m.sleepMinutes),
        delta: m.sleepQuality == null ? null : 'Quality ${m.sleepQuality}',
        accent: AppColors.categorySleep,
        onTap: () => onChipTapped(BodyNowChip.sleep),
      );

  static String? _formatSleep(int? minutes) {
    if (minutes == null) return null;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }
}

enum BodyNowChip { readiness, hrv, rhr, sleep }
