/// Zuralog — ScoreTrendHero widget.
///
/// Replaces the plain HealthScoreWidget.hero() on the Data tab.
/// Shows today's score (compact ring), a 7D/30D/90D period selector,
/// a trend sparkline for the selected period, and aggregate stats
/// (Avg / Min / Max / Trend direction).
///
/// Design: editorial/typographic, dark-first, sage green accent.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/score_history_models.dart';
import 'package:zuralog/features/data/providers/score_history_provider.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/health_score_widget.dart';

// ── ScoreTrendHero ────────────────────────────────────────────────────────────

/// Data-tab hero card showing today's health score and historical trend.
class ScoreTrendHero extends ConsumerWidget {
  const ScoreTrendHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(healthScoreProvider);
    final historyAsync = ref.watch(scoreHistoryProvider);
    final selectedRange = ref.watch(scoreHistoryRangeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top row: compact score ring + title + trend badge ──────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Compact score ring
              scoreAsync.when(
                loading: () => const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, st) => const SizedBox(width: 48, height: 48),
                data: (score) => HealthScoreWidget.compact(score: score.score),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health Score',
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your trend over time',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              // Trend direction badge
              historyAsync.whenOrNull(
                data: (history) => _TrendBadge(direction: history.trendDirection),
              ) ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // ── Period selector ────────────────────────────────────────────
          Row(
            children: ScoreHistoryRange.values.map((range) {
              final isSelected = range == selectedRange;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => ref
                      .read(scoreHistoryRangeProvider.notifier)
                      .state = range,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      range.label,
                      style: AppTextStyles.caption.copyWith(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // ── Trend sparkline ────────────────────────────────────────────
          SizedBox(
            height: 72,
            child: historyAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              error: (e, st) => Center(
                child: Text(
                  'No history yet',
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              data: (history) {
                final values = history.trendValues;
                if (values.length < 2) {
                  return Center(
                    child: Text(
                      'Not enough data for this range',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  );
                }
                return _ScoreSparkline(values: values);
              },
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // ── Stats row ──────────────────────────────────────────────────
          historyAsync.whenOrNull(
            data: (history) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (history.average != null)
                  _StatChip(label: 'Avg', value: '${history.average}'),
                if (history.min != null)
                  _StatChip(label: 'Min', value: '${history.min}'),
                if (history.max != null)
                  _StatChip(label: 'Max', value: '${history.max}'),
                _StatChip(
                  label: 'Days',
                  value: '${history.scores.length}',
                ),
              ],
            ),
          ) ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

// ── _TrendBadge ───────────────────────────────────────────────────────────────

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.direction});
  final String direction;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String label;

    switch (direction) {
      case 'improving':
        color = AppColors.healthScoreGreen;
        icon = Icons.trending_up_rounded;
        label = 'Improving';
      case 'declining':
        color = AppColors.healthScoreRed;
        icon = Icons.trending_down_rounded;
        label = 'Declining';
      default:
        color = AppColors.textTertiary;
        icon = Icons.trending_flat_rounded;
        label = 'Stable';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _StatChip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTextStyles.h3.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ── _ScoreSparkline ───────────────────────────────────────────────────────────

class _ScoreSparkline extends StatelessWidget {
  const _ScoreSparkline({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final nonZero = values.where((v) => v > 0).toList();
    final minY = nonZero.isNotEmpty ? nonZero.reduce(math.min) - 5 : 0.0;
    final maxY = nonZero.isNotEmpty ? nonZero.reduce(math.max) + 5 : 100.0;

    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      if (values[i] > 0) {
        spots.add(FlSpot(i.toDouble(), values[i]));
      }
    }

    if (spots.length < 2) {
      return const SizedBox.shrink();
    }

    return LineChart(
      LineChartData(
        minY: minY.clamp(0, 95),
        maxY: maxY.clamp(5, 100),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                radius: 2.5,
                color: AppColors.primary,
                strokeWidth: 0,
                strokeColor: Colors.transparent,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}
