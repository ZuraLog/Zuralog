/// Zuralog Dashboard — Trend Sparkline Widget.
///
/// A minimal trend chart widget built with the `fl_chart` package.
/// Renders a smooth, borderless line chart with a gradient fill beneath
/// the line — ideal for embedding inside [MetricCard] bento tiles.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// ── Widget ────────────────────────────────────────────────────────────────────

/// A compact sparkline chart for 7-day metric trends.
///
/// Renders a smooth curved line in [color] with a gradient fill below it.
/// Grid, axes, borders, and dots are all hidden for a minimal aesthetic.
///
/// Falls back to an empty [SizedBox] when [dataPoints] has fewer than 2 entries
/// (a single point makes a meaningful line impossible).
///
/// Example:
/// ```dart
/// TrendSparkline(
///   dataPoints: [6200, 7100, 8400, 7900, 9000, 8200, 8432].map((e) => e.toDouble()).toList(),
///   color: AppColors.primary,
///   height: 36,
/// )
/// ```
class TrendSparkline extends StatelessWidget {
  /// Creates a [TrendSparkline].
  ///
  /// [dataPoints] should have 7 entries (one per day).
  /// [color] is used for the line and the fill gradient.
  /// [height] controls the chart container height (default 40 px).
  const TrendSparkline({
    super.key,
    required this.dataPoints,
    required this.color,
    this.height = 40,
  });

  /// The 7-day data values to plot.
  final List<double> dataPoints;

  /// Line and gradient fill colour.
  final Color color;

  /// Chart container height in logical pixels.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (dataPoints.length < 2) {
      // Not enough data to render a meaningful line — show an empty placeholder.
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '—',
            style: TextStyle(color: color.withValues(alpha: 0.4)),
          ),
        ),
      );
    }

    final spots = dataPoints
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return SizedBox(
      height: height,
      child: LineChart(
        _buildChartData(spots),
      ),
    );
  }

  /// Builds the [LineChartData] with a single smooth line and gradient fill.
  LineChartData _buildChartData(List<FlSpot> spots) {
    return LineChartData(
      // No grid lines — clean minimal look.
      gridData: const FlGridData(show: false),
      // No axis labels.
      titlesData: const FlTitlesData(show: false),
      // No border around the chart.
      borderData: FlBorderData(show: false),
      // Remove touch interactions for embedded sparklines.
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          color: color,
          barWidth: 2.0,
          isCurved: true,
          // Smooth curve without overshooting.
          curveSmoothness: 0.3,
          // No visible dots.
          dotData: const FlDotData(show: false),
          // Gradient fill beneath the line.
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}
