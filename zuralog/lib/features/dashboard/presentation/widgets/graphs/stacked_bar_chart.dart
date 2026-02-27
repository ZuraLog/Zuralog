/// Zuralog Dashboard — Stacked Bar Chart Widget.
///
/// Renders a stacked bar chart for metrics whose data points carry
/// multi-component breakdowns in [MetricDataPoint.components].
///
/// Supports two composition modes detected from the component keys:
///   - **Sleep stages**: keys `awake`, `rem`, `core`, `deep` (hours).
///   - **Activity intensity**: keys `move`, `exercise`, `stand` (minutes).
///
/// Uses `fl_chart`'s [BarChart] with [BarChartRodStackItem] for the stacking.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/dashboard/domain/metric_data_point.dart';
import 'package:zuralog/features/dashboard/domain/metric_series.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';

// ── Internal types ────────────────────────────────────────────────────────────

/// Discriminates between the two supported stack composition modes.
enum _StackMode { sleep, activity, unknown }

/// One named segment within a stacked bar.
class _Segment {
  const _Segment({
    required this.key,
    required this.label,
    required this.color,
  });

  final String key;
  final String label;
  final Color color;
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// A stacked bar chart widget for multi-component health metrics.
///
/// Inspects [MetricDataPoint.components] to determine stack composition mode
/// and renders each bar as a vertical stack of colored segments.
///
/// Example usage:
/// ```dart
/// StackedBarChart(
///   series: sleepSeries,
///   timeRange: TimeRange.week,
///   accentColor: Colors.blue,
/// )
/// ```
class StackedBarChart extends StatefulWidget {
  /// Creates a [StackedBarChart].
  ///
  /// [series] — the metric time-series whose [MetricDataPoint.components]
  /// maps provide the per-segment values.
  ///
  /// [timeRange] — the selected time window, used to label the x-axis.
  ///
  /// [accentColor] — the primary brand color for this metric's category.
  ///
  /// [interactive] — when `true`, tap gestures show a tooltip overlay.
  ///
  /// [compact] — when `true`, renders a simplified 2-segment 48 px sparkline
  /// with no axes or legend.
  const StackedBarChart({
    super.key,
    required this.series,
    required this.timeRange,
    required this.accentColor,
    this.interactive = true,
    this.compact = false,
  });

  /// The metric time-series to visualise.
  final MetricSeries series;

  /// The selected time window (controls x-axis labelling).
  final TimeRange timeRange;

  /// The primary accent colour for this metric's category.
  final Color accentColor;

  /// Enables touch/tap interactions when `true`.
  final bool interactive;

  /// When `true`, renders a compact 48 px sparkline with no axes or legend.
  final bool compact;

  @override
  State<StackedBarChart> createState() => _StackedBarChartState();
}

class _StackedBarChartState extends State<StackedBarChart> {
  int? _touchedIndex;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Detects which stack mode applies based on the component keys of the
  /// first data point that has component data.
  _StackMode _detectMode() {
    for (final point in widget.series.dataPoints) {
      final keys = point.components?.keys.toSet() ?? {};
      if (keys.contains('rem')) return _StackMode.sleep;
      if (keys.contains('move')) return _StackMode.activity;
    }
    return _StackMode.unknown;
  }

  /// Returns the ordered segment definitions for the detected mode.
  List<_Segment> _segments(_StackMode mode) {
    switch (mode) {
      case _StackMode.sleep:
        return [
          _Segment(
            key: 'awake',
            label: 'Awake',
            color: Colors.orange.shade300,
          ),
          _Segment(key: 'rem', label: 'REM', color: Colors.purple.shade300),
          _Segment(key: 'core', label: 'Core', color: widget.accentColor),
          _Segment(
            key: 'deep',
            label: 'Deep',
            color: Colors.indigo.shade400,
          ),
        ];
      case _StackMode.activity:
        return [
          _Segment(
            key: 'stand',
            label: 'Stand',
            color: widget.accentColor.withValues(alpha: 0.4),
          ),
          _Segment(
            key: 'move',
            label: 'Move',
            color: widget.accentColor,
          ),
          _Segment(
            key: 'exercise',
            label: 'Exercise',
            color: widget.accentColor.withValues(alpha: 0.7),
          ),
        ];
      case _StackMode.unknown:
        return [
          _Segment(
            key: 'value',
            label: 'Value',
            color: widget.accentColor,
          ),
        ];
    }
  }

  /// Builds one [BarChartGroupData] from a [MetricDataPoint].
  BarChartGroupData _buildBar(
    int index,
    MetricDataPoint point,
    List<_Segment> segments,
    bool compactMode,
  ) {
    final comps = point.components ?? {};
    final isTouched = index == _touchedIndex;

    if (compactMode) {
      // Compact: render only the two largest segments.
      final sorted = segments
          .where((s) => comps.containsKey(s.key))
          .toList()
        ..sort(
          (a, b) => (comps[b.key] ?? 0).compareTo(comps[a.key] ?? 0),
        );
      final top2 = sorted.take(2).toList();
      double from = 0;
      final stackItems = top2.map((seg) {
        final val = comps[seg.key] ?? 0;
        final item = BarChartRodStackItem(from, from + val, seg.color);
        from += val;
        return item;
      }).toList();
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: from,
            width: 6,
            borderRadius: BorderRadius.circular(2),
            rodStackItems: stackItems,
          ),
        ],
      );
    }

    // Full mode: all segments.
    double from = 0;
    final stackItems = segments.map((seg) {
      final val = comps[seg.key] ?? 0;
      final item = BarChartRodStackItem(from, from + val, seg.color);
      from += val;
      return item;
    }).toList();

    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: from,
          width: isTouched ? 14 : 10,
          borderRadius: BorderRadius.circular(4),
          rodStackItems: stackItems,
        ),
      ],
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.series.dataPoints.isEmpty) {
      return _EmptyState(compact: widget.compact);
    }

    final mode = _detectMode();
    final segments = _segments(mode);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    final barGroups = widget.series.dataPoints
        .asMap()
        .entries
        .map(
          (e) => _buildBar(e.key, e.value, segments, widget.compact),
        )
        .toList();

    if (widget.compact) {
      return SizedBox(
        height: 48,
        child: BarChart(
          BarChartData(
            barGroups: barGroups,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            barTouchData: BarTouchData(enabled: false),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend.
        Wrap(
          spacing: AppDimens.spaceMd,
          runSpacing: AppDimens.spaceXs,
          children: segments
              .map(
                (seg) => _LegendItem(color: seg.color, label: seg.label),
              )
              .toList(),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        // Chart.
        Expanded(
          child: BarChart(
            BarChartData(
              barGroups: barGroups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: isDark
                      ? AppColors.borderDark
                      : AppColors.borderLight,
                  strokeWidth: 0.5,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
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
                      if (idx < 0 ||
                          idx >= widget.series.dataPoints.length) {
                        return const SizedBox.shrink();
                      }
                      final ts =
                          widget.series.dataPoints[idx].timestamp;
                      final label = _xLabel(ts, widget.timeRange);
                      return Text(
                        label,
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
              ),
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
                          final point =
                              widget.series.dataPoints[group.x.toInt()];
                          final comps = point.components ?? {};
                          final lines = segments
                              .where((s) => comps.containsKey(s.key))
                              .map(
                                (s) =>
                                    '${s.label}: ${(comps[s.key] ?? 0).toStringAsFixed(1)}',
                              )
                              .join('\n');
                          return BarTooltipItem(
                            lines,
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
        ),
      ],
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// A single colour + label legend item.
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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

/// Dashed rounded-rectangle empty state shown when there are no data points.
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
