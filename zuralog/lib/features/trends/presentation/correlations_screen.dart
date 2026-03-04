/// Correlations Explorer Screen — /trends/correlations
///
/// Lets the user select any two health metrics, pick a lag offset and
/// time range, then view a scatter plot, overlaid time-series charts,
/// Pearson coefficient, and AI annotation.
///
/// Layout:
///   - AppBar: "Explorer" title + back button
///   - Two metric pickers (Metric A / Metric B)
///   - Time-range segmented button (7D / 30D / 90D)
///   - Lag selector (0-day … 3-day)
///   - Scatter plot (fl_chart ScatterChart) — when metrics selected
///   - Correlation strength meter
///   - AI annotation card
///   - Empty/loading/error states
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _CorrelationsBody extends ConsumerWidget {
  const _CorrelationsBody({required this.metrics});
  final List<AvailableMetric> metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricAId = ref.watch(selectedMetricAProvider);
    final metricBId = ref.watch(selectedMetricBProvider);
    final lagDays = ref.watch(selectedLagDaysProvider);
    final timeRange = ref.watch(selectedTimeRangeProvider);

    final hasSelection = metricAId != null && metricBId != null;
    final key = hasSelection
        ? CorrelationKey(
            metricAId: metricAId,
            metricBId: metricBId,
            lagDays: lagDays,
            timeRange: timeRange,
          )
        : null;

    final analysisAsync =
        key != null ? ref.watch(correlationAnalysisProvider(key)) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Metric pickers ─────────────────────────────────────────
          _MetricPickerRow(
            metrics: metrics,
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
              data: (analysis) => _AnalysisResult(analysis: analysis),
            ),

          const SizedBox(height: AppDimens.spaceXxl),
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
            onSelected: (id) =>
                ref.read(selectedMetricAProvider.notifier).state = id,
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
            onSelected: (id) =>
                ref.read(selectedMetricBProvider.notifier).state = id,
          ),
        ),
      ],
    );
  }
}

class _MetricPickerButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final selectedLabel = _selectedLabel();
    return GestureDetector(
      onTap: () => _showPicker(context),
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

class _TimeRangeSelector extends ConsumerWidget {
  const _TimeRangeSelector({required this.selected});
  final CorrelationTimeRange selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: CorrelationTimeRange.values
          .map(
            (range) => Padding(
              padding: const EdgeInsets.only(right: AppDimens.spaceSm),
              child: _RangeChip(
                label: range.label,
                isSelected: selected == range,
                onTap: () =>
                    ref.read(selectedTimeRangeProvider.notifier).state =
                        range,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                  onTap: () =>
                      ref.read(selectedLagDaysProvider.notifier).state = i,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Analysis Result ───────────────────────────────────────────────────────────

class _AnalysisResult extends StatelessWidget {
  const _AnalysisResult({required this.analysis});
  final CorrelationAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Coefficient summary card ──────────────────────────────
        _CoefficientSummaryCard(analysis: analysis),
        const SizedBox(height: AppDimens.spaceMd),

        // ── Scatter plot ──────────────────────────────────────────
        if (analysis.scatterPoints.isNotEmpty) ...[
          Text('Scatter Plot', style: AppTextStyles.h3),
          const SizedBox(height: AppDimens.spaceSm),
          _ScatterPlotCard(analysis: analysis),
          const SizedBox(height: AppDimens.spaceMd),
        ],

        // ── AI annotation ─────────────────────────────────────────
        _AiAnnotationCard(annotation: analysis.aiAnnotation),
      ],
    );
  }
}

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

class _ScatterPlotCard extends StatelessWidget {
  const _ScatterPlotCard({required this.analysis});
  final CorrelationAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final points = analysis.scatterPoints;
    if (points.isEmpty) return const SizedBox.shrink();

    final xs = points.map((p) => p.x).toList();
    final ys = points.map((p) => p.y).toList();
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);

    // Add 10% padding to axes; guard against zero range (all values identical)
    final xPad = (maxX - minX) * 0.1;
    final yPad = (maxY - minY) * 0.1;
    final xRange = xPad == 0 ? 1.0 : xPad;
    final yRange = yPad == 0 ? 1.0 : yPad;

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

    return Container(
      height: 260,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: ScatterChart(
        ScatterChartData(
          scatterSpots: scatterSpots,
          minX: minX - xRange,
          maxX: maxX + xRange,
          minY: minY - yRange,
          maxY: maxY + yRange,
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
                reservedSize: 40,
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
                reservedSize: 24,
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
    );
  }
}

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
