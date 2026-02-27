/// Zuralog Dashboard — Line Chart Graph Widget.
///
/// A smooth curved line chart powered by `fl_chart` for visualising
/// continuous time-series health data: weight, body fat, heart rate
/// variability, VO2 max, respiratory rate, skin temperature, and more.
///
/// Matches the [TrendSparkline] aesthetic in compact mode, and extends it
/// with full axes, labels, an average line, and touch tooltips in full mode.
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

/// Compact sparkline height in logical pixels — matches [TrendSparkline].
const double _kCompactHeight = 48;

// ── Widget ────────────────────────────────────────────────────────────────────

/// A smooth curved line chart for continuous health metric data.
///
/// In compact mode ([compact] = `true`) the widget renders identically to
/// [TrendSparkline]: a borderless line with a gradient fill, no axes, and
/// a fixed height of 48px. This ensures visual consistency between the
/// CategoryCard preview and the detail graph.
///
/// In full mode the widget adds:
/// - Left y-axis with 4–5 evenly spaced labels.
/// - Bottom time axis with smart date labels based on [timeRange].
/// - Light horizontal grid lines.
/// - A dashed average line (when [MetricStats.average] is available).
/// - Touch tooltips showing value + unit.
///
/// Example:
/// ```dart
/// LineChartGraph(
///   series: myWeightSeries,
///   timeRange: TimeRange.month,
///   accentColor: AppColors.secondaryLight,
/// )
/// ```
class LineChartGraph extends StatelessWidget {
  /// Creates a [LineChartGraph].
  const LineChartGraph({
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

  /// The line and fill gradient colour from the metric's health category.
  final Color accentColor;

  /// Whether touch tooltips are enabled (disable for embedded previews).
  final bool interactive;

  /// When `true`, renders a minimal borderless sparkline with no axes.
  ///
  /// Matches [TrendSparkline] style for use inside CategoryCard tiles.
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

    if (series.dataPoints.length < 2) {
      // Not enough data for a meaningful line.
      return SizedBox(
        height: compact ? _kCompactHeight : _kFullHeight,
        child: Center(
          child: Text('—', style: TextStyle(color: accentColor.withValues(alpha: 0.4))),
        ),
      );
    }

    return SizedBox(
      height: compact ? _kCompactHeight : _kFullHeight,
      child: LineChart(_buildChartData(isDark)),
    );
  }

  /// Builds the full [LineChartData] configuration.
  LineChartData _buildChartData(bool isDark) {
    final spots = series.dataPoints
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    final minY = series.stats.min;
    final maxY = series.stats.max;
    final padding = (maxY - minY) * 0.15;
    final yMin = (minY - padding).clamp(0, double.infinity).toDouble();
    final yMax = maxY + padding;

    return LineChartData(
      minY: yMin,
      maxY: yMax > 0 ? yMax : 10.0,
      gridData: compact ? const FlGridData(show: false) : _buildGridData(isDark),
      titlesData: compact ? const FlTitlesData(show: false) : _buildTitlesData(isDark),
      borderData: FlBorderData(show: false),
      lineTouchData: _buildTouchData(isDark),
      lineBarsData: [
        _buildMainLine(spots),
      ],
      extraLinesData: _buildExtraLines(isDark),
    );
  }

  /// Builds the primary [LineChartBarData] with smooth curve and gradient fill.
  LineChartBarData _buildMainLine(List<FlSpot> spots) {
    return LineChartBarData(
      spots: spots,
      color: accentColor,
      barWidth: compact ? 2.0 : 2.5,
      isCurved: true,
      curveSmoothness: 0.35,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.25),
            accentColor.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  /// Builds horizontal grid lines for the full-size view.
  FlGridData _buildGridData(bool isDark) {
    final gridColor = isDark
        ? AppColors.borderDark.withValues(alpha: 0.5)
        : AppColors.borderLight;
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: _niceInterval(series.stats.max - series.stats.min),
      getDrawingHorizontalLine: (_) => FlLine(
        color: gridColor,
        strokeWidth: 1,
        dashArray: [4, 4],
      ),
    );
  }

  /// Builds axis title data for left y-axis and bottom x-axis.
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
          interval: _niceInterval(series.stats.max - series.stats.min),
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == meta.min) {
              return const SizedBox.shrink();
            }
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
            if (!_shouldShowLabel(idx, count)) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: AppDimens.spaceXs),
              child: Text(_xLabel(idx), style: labelStyle),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  /// Builds touch tooltip data for the full interactive view.
  LineTouchData _buildTouchData(bool isDark) {
    if (!interactive || compact) {
      return const LineTouchData(enabled: false);
    }

    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) =>
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        tooltipBorderRadius: BorderRadius.circular(AppDimens.radiusSm),
        tooltipPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceSm,
          vertical: AppDimens.spaceXs,
        ),
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            return LineTooltipItem(
              _formatYLabel(spot.y),
              AppTextStyles.caption.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList();
        },
      ),
      getTouchedSpotIndicator: (barData, spotIndexes) {
        return spotIndexes.map((i) {
          return TouchedSpotIndicatorData(
            FlLine(color: accentColor, strokeWidth: 1.5, dashArray: [4, 4]),
            FlDotData(
              show: true,
              getDotPainter: (p, q, r, s) => FlDotCirclePainter(
                radius: 4,
                color: accentColor,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
          );
        }).toList();
      },
    );
  }

  /// Builds optional extra lines (dashed average line in full view).
  ExtraLinesData _buildExtraLines(bool isDark) {
    if (compact) return const ExtraLinesData();

    final avg = series.stats.average;
    if (avg <= 0) return const ExtraLinesData();

    return ExtraLinesData(
      horizontalLines: [
        HorizontalLine(
          y: avg,
          color: accentColor.withValues(alpha: 0.4),
          strokeWidth: 1.5,
          dashArray: [6, 4],
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _xLabel(int index) {
    if (index < 0 || index >= series.dataPoints.length) return '';
    final ts = series.dataPoints[index].timestamp;
    switch (timeRange) {
      case TimeRange.day:
        return '${ts.hour}h';
      case TimeRange.week:
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[ts.weekday - 1];
      case TimeRange.month:
        return '${ts.day}';
      case TimeRange.sixMonths:
      case TimeRange.year:
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        return months[ts.month - 1];
    }
  }

  bool _shouldShowLabel(int index, int count) {
    if (count <= 7) return true;
    if (count <= 14) return index % 2 == 0;
    if (count <= 31) return index % 5 == 0 || index == count - 1;
    return index % (count ~/ 6) == 0 || index == count - 1;
  }

  String _formatYLabel(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    if (value >= 10) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  double _niceInterval(double range) {
    if (range <= 0) return 1;
    final raw = range / 4;
    final magnitude = raw.abs() < 1
        ? 0.1
        : (raw < 10 ? 1 : (raw < 100 ? 10 : 100));
    return ((raw / magnitude).ceil() * magnitude).toDouble();
  }
}

// ── Empty Placeholder ─────────────────────────────────────────────────────────

/// Dashed rounded-rectangle placeholder shown when there is no data.
class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({required this.height, required this.accentColor});

  final double height;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: CustomPaint(
          painter: _DashedRectPainter(color: accentColor.withValues(alpha: 0.3)),
          child: SizedBox(width: double.infinity, height: height * 0.6),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(AppDimens.radiusSm),
    );

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dashWidth), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color;
}
