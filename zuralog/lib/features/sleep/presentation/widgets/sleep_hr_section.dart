// zuralog/lib/features/sleep/presentation/widgets/sleep_hr_section.dart
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/sleep/domain/sleep_models.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';
import 'package:zuralog/shared/widgets/charts/chart_mode.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';
import 'package:zuralog/shared/widgets/charts/renderers/line_renderer.dart';

class SleepHrSection extends StatelessWidget {
  const SleepHrSection({super.key, required this.sleepingHr});

  final SleepingHR sleepingHr;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    const heartColor = AppColors.categoryHeart;

    final points = sleepingHr.curve
        .map((p) => ChartPoint(date: p.time, value: p.bpm))
        .toList();

    return ZuralogCard(
      variant: ZCardVariant.data,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Heart Rate During Sleep',
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Row(
              children: [
                if (sleepingHr.avgBpm != null)
                  _HrStat(
                    label: 'Avg',
                    value: '${sleepingHr.avgBpm!.round()} bpm',
                  ),
                if (sleepingHr.lowBpm != null)
                  _HrStat(
                    label: 'Low',
                    value: '${sleepingHr.lowBpm!.round()} bpm',
                  ),
                if (sleepingHr.highBpm != null)
                  _HrStat(
                    label: 'High',
                    value: '${sleepingHr.highBpm!.round()} bpm',
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            if (points.isNotEmpty)
              SizedBox(
                height: 100,
                child: LineRenderer(
                  config: LineChartConfig(
                    points: points,
                    rangeMin: (sleepingHr.lowBpm ?? 40) - 5,
                    rangeMax: (sleepingHr.highBpm ?? 80) + 5,
                  ),
                  color: heartColor,
                  renderCtx: ChartRenderContext.fromMode(
                    ChartMode.tall,
                  ).copyWith(
                    showAxes: false,
                    showGrid: false,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    strokeWidth: 2.0,
                    animationProgress: 1.0,
                  ),
                  unit: 'bpm',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HrStat extends StatelessWidget {
  const _HrStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.labelLarge.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
