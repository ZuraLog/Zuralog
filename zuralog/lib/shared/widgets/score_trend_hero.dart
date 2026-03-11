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
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
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
              // Compact score ring — or compact zero state when no data yet.
              scoreAsync.when(
                // Provider never errors; safety-net shows compact zero ring.
                error: (err, stack) => const _CompactScoreZeroState(),
                loading: () => const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                data: (score) {
                  if (score.dataDays == 0 && score.score == 0) {
                    return const _CompactScoreZeroState();
                  }
                  return HealthScoreWidget.compact(
                    score: score.score,
                    onTap: () =>
                        context.push(RouteNames.dataScoreBreakdownPath),
                  );
                },
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
                  return _ScoreChartEmptyState(isDark: isDark);
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

          // ── AI Commentary ──────────────────────────────────────────────
          scoreAsync.whenOrNull(
            data: (score) {
              final commentary = score.commentary;
              if (commentary == null || commentary.isEmpty) return null;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppDimens.spaceMd),
                  _ScoreCommentaryCard(commentary: commentary),
                ],
              );
            },
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

// ── _CompactScoreZeroState ────────────────────────────────────────────────────

/// A 48×48 muted ring shown in the top-row ring slot when there is no score
/// data yet. Sized to match [HealthScoreWidget.compact] so the row layout
/// is not disturbed.
class _CompactScoreZeroState extends StatelessWidget {
  const _CompactScoreZeroState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 5,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.favorite_border_rounded,
          size: 20,
          color: AppColors.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ── _ScoreChartEmptyState ─────────────────────────────────────────────────────

/// Shown inside the sparkline area when there's not enough score history yet.
/// Replaces the bare "Not enough data for this range" text with a compact,
/// welcoming prompt that tells the user what to expect.
class _ScoreChartEmptyState extends StatelessWidget {
  const _ScoreChartEmptyState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textTertiary =
        isDark ? AppColors.textTertiary : AppColors.textTertiary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.show_chart_rounded,
          size: 16,
          color: AppColors.primary.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 6),
        Text(
          'Your trend chart will appear here as data builds up.',
          style: AppTextStyles.caption.copyWith(color: textTertiary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── _ScoreCommentaryCard ──────────────────────────────────────────────────────

class _ScoreCommentaryCard extends StatelessWidget {
  const _ScoreCommentaryCard({required this.commentary});
  final String commentary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: AppColors.primary),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                color: isDark
                    ? AppColors.cardBackgroundDark
                    : AppColors.cardBackgroundLight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    Expanded(
                      child: Text(
                        commentary,
                        style: AppTextStyles.caption.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
