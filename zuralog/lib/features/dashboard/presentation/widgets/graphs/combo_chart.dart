/// Zuralog Dashboard — Combo Chart Widget (Bar + Line Overlay).
///
/// Renders vertical bars for a primary value (bolus dose) with a smooth line
/// overlay for a secondary component value (basal rate).
///
/// Used for: Insulin Delivery — `MetricDataPoint.value` = bolus dose (IU),
/// `MetricDataPoint.components['basal']` = basal rate (IU/hr).
///
/// Implementation: a [BarChart] and a [LineChart] are composed in a [Stack]
/// so they share the same pixel space. Since `fl_chart` does not natively
/// support dual y-axes, a single scale is used (determined by whichever
/// series has the higher max value) and a legend documents the units.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/dashboard/domain/metric_data_point.dart';
import 'package:zuralog/features/dashboard/domain/metric_series.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';

// ── Internal helpers ──────────────────────────────────────────────────────────

/// Formats an x-axis label from a [DateTime] appropriate for the [TimeRange].
String _xLabel(DateTime ts, TimeRange range) {
  switch (range) {
    case TimeRange.day:
      final h = ts.hour;
      final suffix = h < 12 ? 'am' : 'pm';
      final display = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$display$suffix';
    case TimeRange.week:
      const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return days[(ts.weekday - 1) % 7];
    case TimeRange.month:
      return '${ts.day}';
    case TimeRange.sixMonths:
    case TimeRange.year:
      const months = [
        'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D',
      ];
      return months[ts.month - 1];
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// A combo chart that overlays a smooth line on top of vertical bars.
///
/// Bars represent the primary [MetricDataPoint.value] (bolus dose in IU).
/// The line represents the basal rate stored in
/// `MetricDataPoint.components['basal']` (IU/hr).
///
/// Both series share a single y-axis scaled to the maximum across both.
///
/// Example usage:
/// ```dart
/// ComboChart(
///   series: insulinSeries,
///   timeRange: TimeRange.day,
///   accentColor: Colors.blue,
/// )
/// ```
class ComboChart extends StatefulWidget {
  /// Creates a [ComboChart].
  ///
  /// [series] — the metric time-series. [MetricDataPoint.value] provides
  /// bolus values; `components['basal']` provides basal rate values.
  ///
  /// [timeRange] — the selected time window (controls x-axis labelling).
  ///
  /// [accentColor] — the primary colour for the bars. The line uses the
  /// same colour at 60 % opacity.
  ///
  /// [interactive] — enables touch tooltip when `true`.
  ///
  /// [compact] — when `true`, renders bars only (no line) at 48 px height
  /// with no axes.
  const ComboChart({
    super.key,
    required this.series,
    required this.timeRange,
    required this.accentColor,
    this.interactive = true,
    this.compact = false,
  });

  /// The insulin delivery time-series.
  final MetricSeries series;

  /// The selected time window.
  final TimeRange timeRange;

  /// The primary accent colour (bars). Line uses 60 % opacity variant.
  final Color accentColor;

  /// Enables touch/tap interactions when `true`.
  final bool interactive;

  /// When `true`, renders bars only at 48 px height with no axes.
  final bool compact;

  @override
  State<ComboChart> createState() => _ComboChartState();
}

class _ComboChartState extends State<ComboChart> {
  int? _touchedIndex;

  // ── Derived data ─────────────────────────────────────────────────────────────

  /// Maximum y value across bolus and basal, used to scale both charts.
  double _maxY(List<MetricDataPoint> points) {
    double max = 0;
    for (final p in points) {
      if (p.value > max) max = p.value;
      final basal = p.components?['basal'] ?? 0;
      if (basal > max) max = basal;
    }
    return max == 0 ? 1 : max * 1.2;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.series.dataPoints.isEmpty) {
      return _EmptyState(compact: widget.compact);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final points = widget.series.dataPoints;
    final maxY = _maxY(points);

    // Bar data.
    final barGroups = points.asMap().entries.map((e) {
      final isTouched = e.key == _touchedIndex;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.value,
            width: isTouched ? 12 : 8,
            color: widget.accentColor,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      );
    }).toList();

    // Line data (basal rate).
    final lineSpots = points.asMap().entries.map((e) {
      final basal = e.value.components?['basal'] ?? 0.0;
      return FlSpot(e.key.toDouble(), basal);
    }).toList();

    if (widget.compact) {
      return _CompactComboChart(
        barGroups: barGroups,
        maxY: maxY,
        accentColor: widget.accentColor,
      );
    }

    // Shared axis config.
    final titlesData = FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          getTitlesWidget: (value, meta) => Text(
            value.toStringAsFixed(1),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 20,
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= points.length) {
              return const SizedBox.shrink();
            }
            return Text(
              _xLabel(points[idx].timestamp, widget.timeRange),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
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

    final gridData = FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) => FlLine(
        color: isDark ? AppColors.borderDark : AppColors.borderLight,
        strokeWidth: 0.5,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend.
        Row(
          children: [
            _LegendItem(color: widget.accentColor, label: 'Bolus (IU)'),
            const SizedBox(width: AppDimens.spaceMd),
            _LegendItem(
              color: widget.accentColor.withValues(alpha: 0.6),
              label: 'Basal (IU/hr)',
              isLine: true,
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceSm),
        // Chart stack.
        Expanded(
          child: Stack(
            children: [
              // Bar layer (bottom).
              BarChart(
                BarChartData(
                  maxY: maxY,
                  barGroups: barGroups,
                  gridData: gridData,
                  borderData: FlBorderData(show: false),
                  titlesData: titlesData,
                  barTouchData: widget.interactive
                      ? BarTouchData(
                          touchCallback: (event, response) {
                            if (!event.isInterestedForInteractions) {
                              setState(() => _touchedIndex = null);
                              return;
                            }
                            setState(
                              () => _touchedIndex =
                                  response?.spot?.touchedBarGroupIndex,
                            );
                          },
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => isDark
                                ? AppColors.surfaceDark
                                : AppColors.surfaceLight,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final idx = group.x.toInt();
                              if (idx < 0 || idx >= points.length) return null;
                              final point = points[idx];
                              final bolus = point.value.toStringAsFixed(2);
                              final basal = (point.components?['basal'] ?? 0)
                                  .toStringAsFixed(2);
                              return BarTooltipItem(
                                'Bolus: $bolus IU\nBasal: $basal IU/hr',
                                AppTextStyles.caption.copyWith(
                                  color: labelColor,
                                ),
                              );
                            },
                          ),
                        )
                      : BarTouchData(enabled: false),
                ),
              ),
              // Line overlay (top). Needs to match bar chart coordinate space.
              // We use IgnorePointer so the bar chart handles all touches.
              IgnorePointer(
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: lineSpots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: widget.accentColor.withValues(alpha: 0.6),
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    lineTouchData: LineTouchData(enabled: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Compact variant ───────────────────────────────────────────────────────────

/// A 48 px compact bar-only chart with no axes.
class _CompactComboChart extends StatelessWidget {
  const _CompactComboChart({
    required this.barGroups,
    required this.maxY,
    required this.accentColor,
  });

  final List<BarChartGroupData> barGroups;
  final double maxY;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barGroups: barGroups,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          barTouchData: BarTouchData(enabled: false),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// A small legend item showing a colour swatch + label.
class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.isLine = false,
  });

  final Color color;
  final String label;

  /// When `true`, renders a short horizontal line instead of a filled square.
  final bool isLine;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLine)
          Container(
            width: 16,
            height: 2,
            color: color,
          )
        else
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: AppDimens.spaceXs),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

/// Dashed rounded-rectangle empty state.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 48 : null,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.textSecondary.withValues(alpha: 0.4),
          radius: AppDimens.radiusSm,
        ),
        child: Center(
          child: compact
              ? const SizedBox.shrink()
              : Text(
                  'No data',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Paints a dashed rounded-rectangle border for the empty state.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}
