/// Zuralog Dashboard — Bar Chart Graph Widget.
///
/// A vertical bar chart powered by `fl_chart` for visualising cumulative
/// daily totals (steps, calories, nutrition macros, hydration, etc.).
/// Supports both a full detail view with axes and labels and a compact
/// sparkline-style preview suitable for embedding inside CategoryCards.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/dashboard/domain/metric_series.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Full-size chart height in logical pixels.
const double _kFullHeight = 200;

/// Compact sparkline height in logical pixels.
const double _kCompactHeight = 48;

/// Width ratio for compact bars (slightly thinner than full-size).
const double _kCompactBarWidth = 4;

/// Width ratio for full-size bars.
const double _kFullBarWidth = 12;

// ── Widget ────────────────────────────────────────────────────────────────────

/// A vertical bar chart for cumulative daily health metric totals.
///
/// Renders one bar per time bucket (day or week depending on [timeRange]).
/// Supports an optional horizontal goal line, touch tooltips, and a
/// compact sparkline mode for embedding inside summary cards.
///
/// Example:
/// ```dart
/// BarChartGraph(
///   series: myStepsSeries,
///   timeRange: TimeRange.week,
///   accentColor: AppColors.primary,
/// )
/// ```
class BarChartGraph extends StatelessWidget {
  /// Creates a [BarChartGraph].
  const BarChartGraph({
    super.key,
    required this.series,
    required this.timeRange,
    required this.accentColor,
    this.interactive = true,
    this.compact = false,
  });

  /// The metric time-series data to visualise.
  final MetricSeries series;

  /// The selected time window; determines x-axis bucketing and labels.
  final TimeRange timeRange;

  /// The bar fill colour derived from the metric's health category.
  final Color accentColor;

  /// Whether touch tooltips are enabled (disable for embedded previews).
  final bool interactive;

  /// When `true`, renders a minimal sparkline with no axes or labels.
  ///
  /// Use this when embedding inside [CategoryCard] preview tiles.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (series.dataPoints.isEmpty) {
      return _EmptyPlaceholder(
        height: compact ? _kCompactHeight : _kFullHeight,
        accentColor: accentColor,
      );
    }

    return SizedBox(
      height: compact ? _kCompactHeight : _kFullHeight,
      child: BarChart(_buildChartData(isDark)),
    );
  }

  /// Builds the complete [BarChartData] configuration.
  BarChartData _buildChartData(bool isDark) {
    final spots = series.dataPoints
        .asMap()
        .entries
        .map((e) => BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value,
                  width: compact ? _kCompactBarWidth : _kFullBarWidth,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimens.spaceXs),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.8),
                      accentColor.withValues(alpha: 0.4),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ],
            ))
        .toList();

    // Calculate the y-axis maximum: headroom above the data peak.
    final maxValue = series.stats.max;
    final yMax = maxValue > 0 ? maxValue * 1.2 : 10.0;

    return BarChartData(
      maxY: yMax,
      barGroups: spots,
      gridData: compact
          ? const FlGridData(show: false)
          : _buildGridData(isDark),
      titlesData: compact
          ? const FlTitlesData(show: false)
          : _buildTitlesData(isDark),
      borderData: FlBorderData(show: false),
      barTouchData: _buildTouchData(isDark),
      extraLinesData: _buildExtraLines(),
    );
  }

  /// Builds light grey horizontal grid lines for the full-size view.
  FlGridData _buildGridData(bool isDark) {
    final gridColor = isDark
        ? AppColors.borderDark.withValues(alpha: 0.5)
        : AppColors.borderLight;
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: _niceInterval(series.stats.max),
      getDrawingHorizontalLine: (_) => FlLine(
        color: gridColor,
        strokeWidth: 1,
        dashArray: [4, 4],
      ),
    );
  }

  /// Builds the axis title data (bottom x-axis and left y-axis labels).
  FlTitlesData _buildTitlesData(bool isDark) {
    final labelStyle = AppTextStyles.labelXs.copyWith(
      color: AppColors.textSecondary,
    );
    final count = series.dataPoints.length;

    return FlTitlesData(
      show: true,
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval: _niceInterval(series.stats.max),
          getTitlesWidget: (value, meta) {
            if (value == meta.max) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: AppDimens.spaceXs),
              child: Text(
                _formatYLabel(value),
                style: labelStyle,
                textAlign: TextAlign.right,
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= count) return const SizedBox.shrink();
            // Show a subset of labels to avoid crowding.
            if (!_shouldShowLabel(idx, count)) return const SizedBox.shrink();
            final label = _xLabel(idx);
            return Padding(
              padding: const EdgeInsets.only(top: AppDimens.spaceXs),
              child: Text(label, style: labelStyle),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
    );
  }

  /// Builds touch interaction data with rounded tooltips.
  BarTouchData _buildTouchData(bool isDark) {
    if (!interactive || compact) {
      return const BarTouchData(enabled: false);
    }

    final metric = series.metricId;
    return BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (_) => isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        tooltipBorderRadius: BorderRadius.circular(AppDimens.radiusSm),
        tooltipPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceSm,
          vertical: AppDimens.spaceXs,
        ),
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          final value = rod.toY;
          return BarTooltipItem(
            '${_formatYLabel(value)} $metric',
            AppTextStyles.caption.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              fontWeight: FontWeight.w600,
            ),
          );
        },
      ),
    );
  }

  /// Builds optional extra lines (goal line if [HealthMetric.goalValue] is set).
  ///
  /// Since the goal value is on the [HealthMetric] model (not [MetricSeries]),
  /// we look it up from [MetricSeries.stats] — no goal line is drawn here by
  /// default. Callers that want a goal line should subclass or extend this
  /// widget and supply a [goalValue] parameter.
  ExtraLinesData _buildExtraLines() {
    // No direct goal value available on MetricSeries — no goal line rendered.
    // The detail screen can pass goalValue explicitly if needed.
    return const ExtraLinesData();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Returns an x-axis label for the bucket at [index].
  String _xLabel(int index) {
    if (index < 0 || index >= series.dataPoints.length) return '';
    final ts = series.dataPoints[index].timestamp;
    switch (timeRange) {
      case TimeRange.day:
        // Hourly: show "0h", "6h", "12h", "18h".
        return '${ts.hour}h';
      case TimeRange.week:
        // Daily: show Mon, Tue, etc.
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[ts.weekday - 1];
      case TimeRange.month:
        // Show day number: 1, 8, 15, 22, 29.
        return '${ts.day}';
      case TimeRange.sixMonths:
      case TimeRange.year:
        // Monthly: show Jan, Feb, etc.
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        return months[ts.month - 1];
    }
  }

  /// Decides whether to show an x-axis label for [index] given [count] total.
  bool _shouldShowLabel(int index, int count) {
    if (count <= 7) return true;
    if (count <= 14) return index % 2 == 0;
    if (count <= 31) return index % 5 == 0 || index == count - 1;
    return index % (count ~/ 6) == 0 || index == count - 1;
  }

  /// Formats a y-axis value: no decimals for large values, 1 decimal otherwise.
  String _formatYLabel(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    if (value >= 10) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  /// Computes a round interval for y-axis grid lines.
  double _niceInterval(double max) {
    if (max <= 0) return 1;
    final raw = max / 4;
    final magnitude = (raw == 0)
        ? 1
        : (raw.abs() < 1 ? 0.1 : (raw < 10 ? 1 : (raw < 100 ? 10 : 100)));
    return ((raw / magnitude).ceil() * magnitude).toDouble();
  }
}

// ── Variant with explicit goal line ──────────────────────────────────────────

/// A [BarChartGraph] variant that also draws a horizontal dashed goal line.
///
/// Use when you have a known [goalValue] for the metric (e.g. 10,000 steps).
class BarChartGraphWithGoal extends StatelessWidget {
  /// Creates a [BarChartGraphWithGoal].
  const BarChartGraphWithGoal({
    super.key,
    required this.series,
    required this.timeRange,
    required this.accentColor,
    required this.goalValue,
    this.interactive = true,
    this.compact = false,
  });

  /// The metric time-series data to visualise.
  final MetricSeries series;

  /// The selected time window.
  final TimeRange timeRange;

  /// The bar fill colour.
  final Color accentColor;

  /// The horizontal goal line y-value.
  final double goalValue;

  /// Whether touch tooltips are enabled.
  final bool interactive;

  /// When `true`, renders a compact sparkline view.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (series.dataPoints.isEmpty) {
      return _EmptyPlaceholder(
        height: compact ? _kCompactHeight : _kFullHeight,
        accentColor: accentColor,
      );
    }

    final maxValue = series.stats.max;
    final yMax = (goalValue > maxValue ? goalValue : maxValue) * 1.2;

    final spots = series.dataPoints
        .asMap()
        .entries
        .map((e) => BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value,
                  width: compact ? _kCompactBarWidth : _kFullBarWidth,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimens.spaceXs),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.8),
                      accentColor.withValues(alpha: 0.4),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ],
            ))
        .toList();

    final gridColor = isDark
        ? AppColors.borderDark.withValues(alpha: 0.5)
        : AppColors.borderLight;

    return SizedBox(
      height: compact ? _kCompactHeight : _kFullHeight,
      child: BarChart(
        BarChartData(
          maxY: yMax,
          barGroups: spots,
          gridData: compact
              ? const FlGridData(show: false)
              : FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: gridColor,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
          titlesData: compact
              ? const FlTitlesData(show: false)
              : FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(
                            right: AppDimens.spaceXs,
                          ),
                          child: Text(
                            _formatYLabel(value),
                            style: AppTextStyles.labelXs.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
          borderData: FlBorderData(show: false),
          barTouchData: interactive && !compact
              ? BarTouchData(enabled: true)
              : const BarTouchData(enabled: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: goalValue,
                color: accentColor,
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: !compact,
                  alignment: Alignment.topRight,
                  labelResolver: (_) => 'Goal',
                  style: AppTextStyles.labelXs.copyWith(
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatYLabel(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    if (value >= 10) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}

// ── Empty Placeholder ─────────────────────────────────────────────────────────

/// Displays a dashed rounded-rectangle placeholder when there is no data.
class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({
    required this.height,
    required this.accentColor,
  });

  final double height;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: CustomPaint(
          painter: _DashedRectPainter(color: accentColor.withValues(alpha: 0.3)),
          child: SizedBox(
            width: double.infinity,
            height: height * 0.6,
          ),
        ),
      ),
    );
  }
}

/// Paints a dashed rounded rectangle — used as the empty-state placeholder.
class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const radius = AppDimens.radiusSm;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(radius),
    );

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final extract = metric.extractPath(
          distance,
          distance + dashWidth,
        );
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color;
}
