/// Correlations Explorer Screen — /trends/correlations
///
/// Lets the user select any two health metrics, pick a lag offset and
/// time range, then view a scatter plot (with regression line), overlaid
/// time-series charts, Pearson coefficient, and AI annotation.
///
/// Layout:
///   - AppBar: "Explorer" title + back button
///   - Two metric pickers (Metric A / Metric B)
///   - Time-range segmented button (7D / 30D / 90D / Custom)
///   - Lag selector (0-day … 3-day)
///   - Chart tab selector (Scatter / Overlay) — when metrics selected
///   - Scatter plot with trend line OR overlay time-series chart
///   - Correlation strength meter
///   - AI annotation card
///   - Data maturity gate (< 7 days of data)
///   - Empty/loading/error states
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/trends/domain/trends_models.dart';
import 'package:zuralog/features/trends/providers/trends_providers.dart';

// ── CorrelationsScreen ────────────────────────────────────────────────────────

/// Correlation explorer — two-metric picker + scatter plot + AI annotation.
class CorrelationsScreen extends ConsumerWidget {
  /// Creates the [CorrelationsScreen].
  const CorrelationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(availableMetricsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorer'),
      ),
      body: metricsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => _ExplorerErrorState(
          onRetry: () => ref.invalidate(availableMetricsProvider),
        ),
        data: (metricList) => _CorrelationsBody(metrics: metricList.metrics),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _CorrelationsBody extends ConsumerStatefulWidget {
  const _CorrelationsBody({required this.metrics});
  final List<AvailableMetric> metrics;

  @override
  ConsumerState<_CorrelationsBody> createState() => _CorrelationsBodyState();
}

class _CorrelationsBodyState extends ConsumerState<_CorrelationsBody> {
  /// 0 = Scatter view, 1 = Overlay view.
  int _chartTab = 0;

  @override
  Widget build(BuildContext context) {
    final metricAId = ref.watch(selectedMetricAProvider);
    final metricBId = ref.watch(selectedMetricBProvider);
    final lagDays = ref.watch(selectedLagDaysProvider);
    final timeRange = ref.watch(selectedTimeRangeProvider);
    final customStart = ref.watch(customDateStartProvider);
    final customEnd = ref.watch(customDateEndProvider);

    final hasSelection = metricAId != null && metricBId != null;
    final key = hasSelection
        ? CorrelationKey(
            metricAId: metricAId,
            metricBId: metricBId,
            lagDays: lagDays,
            timeRange: timeRange,
            customStart: customStart,
            customEnd: customEnd,
          )
        : null;

    final analysisAsync =
        key != null ? ref.watch(correlationAnalysisProvider(key)) : null;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Metric pickers ─────────────────────────────────────────
          _MetricPickerRow(
            metrics: widget.metrics,
            metricAId: metricAId,
            metricBId: metricBId,
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // ── Time range selector ────────────────────────────────────
          _TimeRangeSelector(selected: timeRange),
          const SizedBox(height: AppDimens.spaceMd),

          // ── Lag selector ───────────────────────────────────────────
          _LagSelector(selectedDays: lagDays),
          const SizedBox(height: AppDimens.spaceLg),

          // ── Analysis content ───────────────────────────────────────
          if (!hasSelection)
            const _PickerPrompt()
          else if (analysisAsync == null)
            const SizedBox.shrink()
          else
            analysisAsync.when(
              loading: () => const _AnalysisLoadingState(),
              error: (e, _) => _AnalysisErrorState(
                onRetry: () =>
                    ref.invalidate(correlationAnalysisProvider(key!)),
              ),
              data: (analysis) => _AnalysisResult(
                analysis: analysis,
                chartTab: _chartTab,
                onChartTabChanged: (tab) => setState(() => _chartTab = tab),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Metric Picker Row ─────────────────────────────────────────────────────────

class _MetricPickerRow extends ConsumerWidget {
  const _MetricPickerRow({
    required this.metrics,
    required this.metricAId,
    required this.metricBId,
  });

  final List<AvailableMetric> metrics;
  final String? metricAId;
  final String? metricBId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _MetricPickerButton(
            label: 'Metric A',
            selectedId: metricAId,
            metrics: metrics,
            excludeId: metricBId,
            onSelected: (id) {
              ref.read(selectedMetricAProvider.notifier).state = id;
              ref.read(analyticsServiceProvider).capture(
                event: AnalyticsEvents.correlationMetricSelected,
                properties: {'position': 'metric_a', 'metric_id': id},
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
          child: Icon(
            Icons.close_rounded,
            color: AppColors.textTertiary,
            size: AppDimens.iconMd,
          ),
        ),
        Expanded(
          child: _MetricPickerButton(
            label: 'Metric B',
            selectedId: metricBId,
            metrics: metrics,
            excludeId: metricAId,
            onSelected: (id) {
              ref.read(selectedMetricBProvider.notifier).state = id;
              ref.read(analyticsServiceProvider).capture(
                event: AnalyticsEvents.correlationMetricSelected,
                properties: {'position': 'metric_b', 'metric_id': id},
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MetricPickerButton extends ConsumerWidget {
  const _MetricPickerButton({
    required this.label,
    required this.selectedId,
    required this.metrics,
    required this.excludeId,
    required this.onSelected,
  });

  final String label;
  final String? selectedId;
  final List<AvailableMetric> metrics;
  final String? excludeId;
  final ValueChanged<String> onSelected;

  String? _selectedLabel() {
    if (selectedId == null) return null;
    try {
      return metrics.firstWhere((m) => m.id == selectedId).label;
    } catch (_) {
      return null;
    }
  }

  void _showPicker(BuildContext context) {
    final available = metrics.where((m) => m.id != excludeId).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusCard),
        ),
      ),
      builder: (_) => _MetricPickerSheet(
        metrics: available,
        selectedId: selectedId,
        onSelected: (id) {
          onSelected(id);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLabel = _selectedLabel();
    return GestureDetector(
      onTap: () {
        ref.read(hapticServiceProvider).light();
        _showPicker(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceMd,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: selectedId != null
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.labelXs.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedLabel ?? 'Tap to select',
                    style: AppTextStyles.caption.copyWith(
                      color: selectedLabel != null
                          ? AppColors.textPrimaryDark
                          : AppColors.textSecondaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: AppDimens.iconMd,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPickerSheet extends StatelessWidget {
  const _MetricPickerSheet({
    required this.metrics,
    required this.selectedId,
    required this.onSelected,
  });

  final List<AvailableMetric> metrics;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        // Group by category
        final categories = <String, List<AvailableMetric>>{};
        for (final m in metrics) {
          categories.putIfAbsent(m.category, () => []).add(m);
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd),
              child: Text('Select Metric', style: AppTextStyles.h2),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd),
                children: categories.entries.expand((entry) {
                  return [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppDimens.spaceSm),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: AppTextStyles.labelXs.copyWith(
                          color: AppColors.textTertiary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ...entry.value.map(
                      (m) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(m.label, style: AppTextStyles.body),
                        subtitle: Text(
                          m.unit,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                        trailing: m.id == selectedId
                            ? Icon(Icons.check_rounded,
                                color: AppColors.primary)
                            : null,
                        onTap: () => onSelected(m.id),
                      ),
                    ),
                  ];
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Time Range Selector ───────────────────────────────────────────────────────

class _TimeRangeSelector extends ConsumerStatefulWidget {
  const _TimeRangeSelector({required this.selected});
  final CorrelationTimeRange selected;

  @override
  ConsumerState<_TimeRangeSelector> createState() => _TimeRangeSelectorState();
}

class _TimeRangeSelectorState extends ConsumerState<_TimeRangeSelector> {
  /// Reads the custom date providers and builds a display label such as
  /// "Feb 1–28" when a custom range has been selected.
  String _labelFor(CorrelationTimeRange range) {
    if (range != CorrelationTimeRange.custom) return range.label;
    final start = ref.read(customDateStartProvider);
    final end = ref.read(customDateEndProvider);
    if (start == null || end == null) return range.label;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    if (start.month == end.month && start.year == end.year) {
      return '${months[start.month - 1]} ${start.day}–${end.day}';
    }
    return '${months[start.month - 1]} ${start.day} – '
        '${months[end.month - 1]} ${end.day}';
  }

  Future<void> _handleCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.black,
            surface: Color(0xFF1C1C1E),
          ),
        ),
        child: child!,
      ),
    );
    // Guard: widget may have been disposed while the picker was open.
    if (!mounted) return;
    if (picked != null) {
      ref.read(customDateStartProvider.notifier).state = picked.start;
      ref.read(customDateEndProvider.notifier).state = picked.end;
      ref.read(selectedTimeRangeProvider.notifier).state =
          CorrelationTimeRange.custom;
      ref.read(analyticsServiceProvider).capture(
        event: AnalyticsEvents.timeRangeChanged,
        properties: {'range': 'custom', 'context': 'correlations'},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch custom date providers so the chip label updates reactively.
    ref.watch(customDateStartProvider);
    ref.watch(customDateEndProvider);

    return Row(
      children: CorrelationTimeRange.values
          .map(
            (range) => Padding(
              padding: const EdgeInsets.only(right: AppDimens.spaceSm),
              child: _RangeChip(
                label: _labelFor(range),
                isSelected: widget.selected == range,
                onTap: () async {
                  if (range == CorrelationTimeRange.custom) {
                    await _handleCustomRange();
                  } else {
                    ref.read(selectedTimeRangeProvider.notifier).state = range;
                    ref.read(analyticsServiceProvider).capture(
                      event: AnalyticsEvents.timeRangeChanged,
                      properties: {
                        'range': range.label,
                        'context': 'correlations',
                      },
                    );
                  }
                },
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RangeChip extends ConsumerWidget {
  const _RangeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  // Uses Future<void> Function() to safely support async callers (e.g. date picker).
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(hapticServiceProvider).selectionTick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
          border: isSelected
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5))
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondaryDark,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Lag Selector ──────────────────────────────────────────────────────────────

class _LagSelector extends ConsumerWidget {
  const _LagSelector({required this.selectedDays});
  final int selectedDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lag Offset',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Row(
          children: List.generate(4, (i) {
            final label =
                i == 0 ? 'Same day' : '+$i day${i > 1 ? 's' : ''}';
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i < 3 ? AppDimens.spaceXs : 0,
                ),
                child: _RangeChip(
                  label: label,
                  isSelected: selectedDays == i,
                  onTap: () async {
                    ref.read(selectedLagDaysProvider.notifier).state = i;
                    ref.read(analyticsServiceProvider).capture(
                      event: AnalyticsEvents.correlationLagChanged,
                      properties: {'lag_days': i},
                    );
                  },
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Chart Tab Selector ────────────────────────────────────────────────────────

class _ChartTabSelector extends StatelessWidget {
  const _ChartTabSelector({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ChartTabChip(
          label: 'Scatter',
          selected: selectedIndex == 0,
          onTap: () => onChanged(0),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        _ChartTabChip(
          label: 'Overlay',
          selected: selectedIndex == 1,
          onTap: () => onChanged(1),
        ),
      ],
    );
  }
}

class _ChartTabChip extends StatelessWidget {
  const _ChartTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? Colors.black : AppColors.textSecondaryDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Analysis Result ───────────────────────────────────────────────────────────

class _AnalysisResult extends StatelessWidget {
  const _AnalysisResult({
    required this.analysis,
    required this.chartTab,
    required this.onChartTabChanged,
  });

  final CorrelationAnalysis analysis;
  final int chartTab;
  final ValueChanged<int> onChartTabChanged;

  @override
  Widget build(BuildContext context) {
    // Data maturity gate — no scatter points means not enough data
    if (analysis.scatterPoints.isEmpty) {
      return const _DataMaturityGate();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Coefficient summary card ──────────────────────────────
        _CoefficientSummaryCard(analysis: analysis),
        const SizedBox(height: AppDimens.spaceMd),

        // ── Chart tab selector ────────────────────────────────────
        Text('Visualisation', style: AppTextStyles.h3),
        const SizedBox(height: AppDimens.spaceSm),
        _ChartTabSelector(
          selectedIndex: chartTab,
          onChanged: onChartTabChanged,
        ),
        const SizedBox(height: AppDimens.spaceSm),

        // ── Chart (scatter or overlay) ────────────────────────────
        if (chartTab == 0)
          _ScatterPlotCard(analysis: analysis)
        else
          _OverlayChartCard(analysis: analysis),

        const SizedBox(height: AppDimens.spaceMd),

        // ── AI annotation ─────────────────────────────────────────
        _AiAnnotationCard(annotation: analysis.aiAnnotation),
      ],
    );
  }
}

// ── Data Maturity Gate ────────────────────────────────────────────────────────

class _DataMaturityGate extends StatelessWidget {
  const _DataMaturityGate();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppDimens.spaceLg),
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.hourglass_empty_rounded,
            color: AppColors.textTertiary,
            size: 36,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Not enough data yet',
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Correlations need at least 7 days of data. Keep logging and check back soon.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryDark,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Coefficient Summary Card ──────────────────────────────────────────────────

class _CoefficientSummaryCard extends StatelessWidget {
  const _CoefficientSummaryCard({required this.analysis});
  final CorrelationAnalysis analysis;

  Color _coeffColor(double coeff) {
    final abs = coeff.abs();
    if (abs >= 0.7) return AppColors.categoryActivity;
    if (abs >= 0.4) return AppColors.healthScoreAmber;
    return AppColors.textSecondaryDark;
  }

  @override
  Widget build(BuildContext context) {
    final coeffColor = _coeffColor(analysis.coefficient);
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Row(
        children: [
          // Coefficient circle
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: coeffColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                analysis.coefficient.toStringAsFixed(2),
                style: AppTextStyles.h2.copyWith(color: coeffColor),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analysis.interpretation,
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 4),
                Text(
                  '${analysis.metricA.label} × ${analysis.metricB.label}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                if (analysis.lagDays > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '+${analysis.lagDays}d lag applied',
                    style: AppTextStyles.labelXs.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scatter Plot Card (with regression line) ──────────────────────────────────

class _ScatterPlotCard extends StatelessWidget {
  const _ScatterPlotCard({required this.analysis});
  final CorrelationAnalysis analysis;

  /// Computes linear regression endpoints [x1, y1, x2, y2].
  /// Returns null if fewer than 2 points or degenerate case.
  List<double>? _regressionLine(List<ScatterPoint> pts) {
    if (pts.length < 2) return null;
    final n = pts.length.toDouble();
    final sumX = pts.fold(0.0, (s, p) => s + p.x);
    final sumY = pts.fold(0.0, (s, p) => s + p.y);
    final sumXY = pts.fold(0.0, (s, p) => s + p.x * p.y);
    final sumX2 = pts.fold(0.0, (s, p) => s + p.x * p.x);
    final denom = n * sumX2 - sumX * sumX;
    if (denom == 0) return null;
    final slope = (n * sumXY - sumX * sumY) / denom;
    final intercept = (sumY - slope * sumX) / n;
    final minX = pts.map((p) => p.x).reduce(math.min);
    final maxX = pts.map((p) => p.x).reduce(math.max);
    return [minX, slope * minX + intercept, maxX, slope * maxX + intercept];
  }

  @override
  Widget build(BuildContext context) {
    final points = analysis.scatterPoints;
    if (points.isEmpty) return const SizedBox.shrink();

    final xs = points.map((p) => p.x).toList();
    final ys = points.map((p) => p.y).toList();
    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);

    // Add 10% padding to axes; guard against zero range
    final xPad = (maxX - minX) * 0.1;
    final yPad = (maxY - minY) * 0.1;
    final xRange = xPad == 0 ? 1.0 : xPad;
    final yRange = yPad == 0 ? 1.0 : yPad;

    final chartMinX = minX - xRange;
    final chartMaxX = maxX + xRange;
    final chartMinY = minY - yRange;
    final chartMaxY = maxY + yRange;

    final scatterSpots = points
        .map(
          (p) => ScatterSpot(
            p.x,
            p.y,
            dotPainter: FlDotCirclePainter(
              radius: 4,
              color: AppColors.primary.withValues(alpha: 0.7),
              strokeWidth: 0,
            ),
          ),
        )
        .toList();

    final regLine = _regressionLine(points);

    // fl_chart axis-label reserved sizes — must match SideTitles.reservedSize.
    const double leftReserved = 40.0;
    const double bottomReserved = 24.0;

    return Container(
      height: 260,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Stack(
        children: [
          ScatterChart(
            ScatterChartData(
              scatterSpots: scatterSpots,
              minX: chartMinX,
              maxX: chartMaxX,
              minY: chartMinY,
              maxY: chartMaxY,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.borderDark,
                  strokeWidth: 0.5,
                ),
                getDrawingVerticalLine: (_) => FlLine(
                  color: AppColors.borderDark,
                  strokeWidth: 0.5,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: leftReserved,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: AppTextStyles.labelXs.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: bottomReserved,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: AppTextStyles.labelXs.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              scatterTouchData: ScatterTouchData(enabled: false),
            ),
          ),
          // Regression trend line — positioned over the data area only.
          // Offset by axis-label gutters so it aligns with the scatter dots.
          if (regLine != null)
            Positioned(
              left: leftReserved,
              top: 0,
              right: 0,
              bottom: bottomReserved,
              child: ClipRect(
                child: CustomPaint(
                  painter: _RegressionLinePainter(
                    line: regLine,
                    minX: chartMinX,
                    maxX: chartMaxX,
                    minY: chartMinY,
                    maxY: chartMaxY,
                    color: AppColors.primary.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Paints a linear regression line over the scatter plot area.
///
/// This painter assumes it fills exactly the chart's data-draw area.
/// The [Stack] that contains it must clip children so the line cannot
/// bleed into the axis-label gutters. See [_ScatterPlotCard] for how
/// [ClipRect] + [LayoutBuilder] are used to achieve this.
class _RegressionLinePainter extends CustomPainter {
  const _RegressionLinePainter({
    required this.line,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.color,
  });

  /// [x1, y1, x2, y2] endpoints of the regression line in data coordinates.
  final List<double> line;
  final double minX, maxX, minY, maxY;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final xRange = maxX - minX;
    final yRange = maxY - minY;
    if (xRange == 0 || yRange == 0) return;

    // Map data coordinates → pixel coordinates within this widget's size.
    // No manual offset needed — the widget is already sized to the draw area.
    double toScreenX(double x) => (x - minX) / xRange * size.width;
    double toScreenY(double y) =>
        size.height - (y - minY) / yRange * size.height;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(toScreenX(line[0]), toScreenY(line[1])),
      Offset(toScreenX(line[2]), toScreenY(line[3])),
      paint,
    );
  }

  @override
  bool shouldRepaint(_RegressionLinePainter old) =>
      old.line != line || old.color != color;
}

// ── Overlay Time-Series Chart ─────────────────────────────────────────────────

class _OverlayChartCard extends StatelessWidget {
  const _OverlayChartCard({required this.analysis});
  final CorrelationAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final points = analysis.scatterPoints;
    // Need at least 2 points for a meaningful time-series overlay.
    if (points.length < 2) return const _DataMaturityGate();

    // Normalise both metrics to 0–1 so they share a y-axis
    final xs = points.map((p) => p.x).toList();
    final ys = points.map((p) => p.y).toList();
    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);
    final xRange = maxX - minX == 0 ? 1.0 : maxX - minX;
    final yRange = maxY - minY == 0 ? 1.0 : maxY - minY;

    final lineA = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), (e.value.x - minX) / xRange))
        .toList();
    final lineB = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), (e.value.y - minY) / yRange))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Row(
            children: [
              _LegendDot(color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                analysis.metricA.label,
                style: AppTextStyles.labelXs.copyWith(
                    color: AppColors.textSecondaryDark),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              _LegendDot(color: AppColors.categoryHeart, dashed: true),
              const SizedBox(width: 4),
              Text(
                analysis.metricB.label,
                style: AppTextStyles.labelXs.copyWith(
                    color: AppColors.textSecondaryDark),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.borderDark,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minY: -0.05,
                maxY: 1.05,
                lineBarsData: [
                  LineChartBarData(
                    spots: lineA,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: lineB,
                    isCurved: true,
                    color: AppColors.categoryHeart,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    dashArray: [4, 4],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'Both metrics normalised to 0–1 for comparison.',
            style: AppTextStyles.labelXs.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, this.dashed = false});
  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    if (!dashed) {
      return Container(width: 16, height: 2, color: color);
    }
    return SizedBox(
      width: 16,
      height: 2,
      child: CustomPaint(painter: _DashLinePainter(color: color)),
    );
  }
}

/// Paints a short horizontal dashed line for overlay chart legends.
class _DashLinePainter extends CustomPainter {
  const _DashLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..style = PaintingStyle.stroke;
    const dashWidth = 3.0;
    const gapWidth = 2.5;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2),
          Offset((x + dashWidth).clamp(0, size.width), size.height / 2), paint);
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(_DashLinePainter old) => old.color != color;
}

// ── AI Annotation Card ────────────────────────────────────────────────────────

class _AiAnnotationCard extends StatelessWidget {
  const _AiAnnotationCard({required this.annotation});
  final String annotation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              size: 18, color: AppColors.primary),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              annotation,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Picker Prompt ─────────────────────────────────────────────────────────────

class _PickerPrompt extends StatelessWidget {
  const _PickerPrompt();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        children: [
          Icon(
            Icons.scatter_plot_rounded,
            size: 40,
            color: AppColors.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Select Two Metrics',
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Choose a Metric A and Metric B above to explore the correlation between them.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryDark,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Loading / Error States ────────────────────────────────────────────────────

class _AnalysisLoadingState extends StatelessWidget {
  const _AnalysisLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppDimens.spaceLg),
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _AnalysisErrorState extends StatelessWidget {
  const _AnalysisErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceLg),
      child: Column(
        children: [
          Text(
            'Could not load analysis.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppDimens.radiusButtonMd),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ExplorerErrorState extends StatelessWidget {
  const _ExplorerErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text('Could not load metrics', style: AppTextStyles.h3),
            const SizedBox(height: AppDimens.spaceLg),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryButtonText,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.radiusButtonMd),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
