/// Category Detail Screen — pushed from Health Dashboard.
///
/// Drill-down into a specific health category (Activity, Sleep, Heart, etc.)
/// showing all metrics within the category with [fl_chart] line charts and a
/// time-range selector (7D / 30D / 90D / Custom).
///
/// Category color theming is applied throughout. Tap a metric row to push
/// [MetricDetailScreen]. Charts animate in with 400ms easeOutCubic.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/shared/widgets/time_range_selector.dart';

// ── CategoryDetailScreen ──────────────────────────────────────────────────────

/// Category detail screen parameterised by [categoryId].
class CategoryDetailScreen extends ConsumerStatefulWidget {
  /// Creates a [CategoryDetailScreen] for the given [categoryId].
  const CategoryDetailScreen({super.key, required this.categoryId});

  /// The category identifier slug (e.g. "activity", "sleep", "heart").
  final String categoryId;

  @override
  ConsumerState<CategoryDetailScreen> createState() =>
      _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  TimeRange _selectedRange = TimeRange.days7;
  DateTimeRange? _customRange;

  HealthCategory get _category =>
      HealthCategory.fromString(widget.categoryId) ?? HealthCategory.activity;

  @override
  Widget build(BuildContext context) {
    final cat = _category;
    final layout = ref.watch(dashboardLayoutProvider);
    final overrideInt = layout.categoryColorOverrides[cat.name];
    final color = overrideInt != null ? Color(overrideInt) : categoryColor(cat);
    // When custom is selected with a picked range, encode dates into the
    // time range key so the cache treats it as a distinct entry.
    final timeRangeKey = _selectedRange == TimeRange.custom && _customRange != null
        ? 'custom:${_customRange!.start.toIso8601String()}|${_customRange!.end.toIso8601String()}'
        : _selectedRange.label;
    final params = CategoryDetailParams(
      categoryId: widget.categoryId,
      timeRange: timeRangeKey,
    );
    final detailAsync = ref.watch(categoryDetailProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Text(cat.displayName, style: AppTextStyles.h2),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Time range selector ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: TimeRangeSelector(
              value: _selectedRange,
              onChanged: (range) =>
                  setState(() => _selectedRange = range),
              customDateRange: _customRange,
              onCustomRangePicked: (range) => setState(() {
                _customRange = range;
                _selectedRange = TimeRange.custom;
              }),
            ),
          ),

          // ── Content ────────────────────────────────────────────────────────
          Expanded(
            child: detailAsync.when(
              loading: () => _buildSkeletons(),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 40,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    Text(
                      'Could not load ${cat.displayName}',
                      style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              data: (detail) {
                if (detail.metrics.isEmpty) {
                  return Center(
                    child: Text(
                      'No metrics for ${cat.displayName} yet.',
                      style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceXs,
                    AppDimens.spaceMd,
                    AppDimens.bottomNavHeight + AppDimens.spaceMd,
                  ),
                  itemCount: detail.metrics.length,
                  itemBuilder: (context, i) {
                    return _MetricChartCard(
                      series: detail.metrics[i],
                      color: color,
                      onTap: () => context
                          .push('/data/metric/${detail.metrics[i].metricId}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletons() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      itemCount: 3,
      itemBuilder: (context, index) => const _MetricCardSkeleton(),
    );
  }
}

// ── _MetricChartCard ──────────────────────────────────────────────────────────

/// A card showing a metric's name, current value, and fl_chart line chart.
class _MetricChartCard extends StatefulWidget {
  const _MetricChartCard({
    required this.series,
    required this.color,
    required this.onTap,
  });

  final MetricSeries series;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_MetricChartCard> createState() => _MetricChartCardState();
}

class _MetricChartCardState extends State<_MetricChartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_MetricChartCard old) {
    super.didUpdateWidget(old);
    // MED-02: replay animation when the data series changes (e.g. time range switch)
    if (old.series.metricId != widget.series.metricId ||
        old.series.dataPoints.length != widget.series.dataPoints.length) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight;
    final series = widget.series;
    final color = widget.color;

    final spots = [
      for (var i = 0; i < series.dataPoints.length; i++)
        FlSpot(i.toDouble(), series.dataPoints[i].value),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          series.displayName,
                          style: AppTextStyles.h3,
                        ),
                        if (series.currentValue != null) ...[
                          const SizedBox(height: 2),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: series.currentValue!,
                                  style: AppTextStyles.h2.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (series.unit.isNotEmpty)
                                  TextSpan(
                                    text: ' ${series.unit}',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (series.deltaPercent != null)
                    _DeltaBadge(delta: series.deltaPercent!),
                  const SizedBox(width: AppDimens.spaceSm),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                    size: AppDimens.iconMd,
                  ),
                ],
              ),

              // Chart (only when data points available)
              if (spots.length >= 2) ...[
                const SizedBox(height: AppDimens.spaceMd),
                FadeTransition(
                  opacity: _opacity,
                  child: SizedBox(
                    height: 80,
                    child: _buildChart(context, spots, color),
                  ),
                ),
              ] else if (spots.length == 1) ...[
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'Only one data point available',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<FlSpot> spots, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final values = spots.map((s) => s.y).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) == 0 ? 1.0 : (maxY - minY) * 0.1;

    return LineChart(
      LineChartData(
        minY: minY - padding,
        maxY: maxY + padding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 3 + 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: (isDark ? AppColors.borderDark : AppColors.borderLight)
                .withValues(alpha: 0.5),
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceDark,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      s.y.toStringAsFixed(1),
                      AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }
}

// ── _DeltaBadge ───────────────────────────────────────────────────────────────

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta});
  final double delta;

  @override
  Widget build(BuildContext context) {
    final isUp = delta > 0;
    final isFlat = delta == 0;
    final color = isFlat
        ? AppColors.textTertiary
        : isUp
            ? AppColors.healthScoreGreen
            : AppColors.healthScoreRed;
    final icon = isFlat
        ? Icons.remove_rounded
        : isUp
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;
    final label =
        isFlat ? '0%' : '${isUp ? '+' : ''}${delta.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _MetricCardSkeleton ───────────────────────────────────────────────────────

class _MetricCardSkeleton extends StatelessWidget {
  const _MetricCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
