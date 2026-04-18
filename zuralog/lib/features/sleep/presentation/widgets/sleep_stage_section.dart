// zuralog/lib/features/sleep/presentation/widgets/sleep_stage_section.dart
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/sleep/domain/sleep_models.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

const _deepColor   = Color(0xFF5E5CE6);
const _remColor    = Color(0xFFBF5AF2);
const _lightColor  = Color(0x735E5CE6);
const _awakeColor  = Color(0x88FF375F);

class SleepStageSection extends StatelessWidget {
  const SleepStageSection({super.key, required this.stages});

  final SleepStages stages;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final total = stages.totalMinutes;

    final sections = <PieChartSectionData>[
      if ((stages.deepMinutes ?? 0) > 0)
        PieChartSectionData(
          value: stages.deepMinutes!.toDouble(),
          color: _deepColor,
          radius: 18,
          showTitle: false,
        ),
      if ((stages.remMinutes ?? 0) > 0)
        PieChartSectionData(
          value: stages.remMinutes!.toDouble(),
          color: _remColor,
          radius: 18,
          showTitle: false,
        ),
      if ((stages.lightMinutes ?? 0) > 0)
        PieChartSectionData(
          value: stages.lightMinutes!.toDouble(),
          color: _lightColor,
          radius: 18,
          showTitle: false,
        ),
      if ((stages.awakeMinutes ?? 0) > 0)
        PieChartSectionData(
          value: stages.awakeMinutes!.toDouble(),
          color: _awakeColor,
          radius: 18,
          showTitle: false,
        ),
    ];

    if (sections.isEmpty) return const SizedBox.shrink();

    return ZuralogCard(
      variant: ZCardVariant.data,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sleep Stages',
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: AppDimens.ringDiameter * 0.7,
                  height: AppDimens.ringDiameter * 0.7,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: AppDimens.ringDiameter * 0.7 / 2 - 18,
                      sections: sections,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (stages.deepMinutes != null)
                        _StageStat(
                          color: _deepColor,
                          label: 'Deep',
                          minutes: stages.deepMinutes!,
                          total: total,
                        ),
                      if (stages.remMinutes != null)
                        _StageStat(
                          color: _remColor,
                          label: 'REM',
                          minutes: stages.remMinutes!,
                          total: total,
                        ),
                      if (stages.lightMinutes != null)
                        _StageStat(
                          color: _lightColor,
                          label: 'Light',
                          minutes: stages.lightMinutes!,
                          total: total,
                        ),
                      if (stages.awakeMinutes != null)
                        _StageStat(
                          color: _awakeColor,
                          label: 'Awake',
                          minutes: stages.awakeMinutes!,
                          total: total,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StageStat extends StatelessWidget {
  const _StageStat({
    required this.color,
    required this.label,
    required this.minutes,
    required this.total,
  });
  final Color color;
  final String label;
  final int minutes;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final pct = total > 0 ? (minutes / total * 100).round() : 0;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final dur = h > 0 ? '${h}h ${m}m' : '${m}m';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceXs),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: AppDimens.spaceXs),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          Text(
            dur,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: AppDimens.spaceXs),
          SizedBox(
            width: 34,
            child: Text(
              '$pct%',
              style: AppTextStyles.labelSmall.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
