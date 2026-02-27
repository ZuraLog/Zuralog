/// Zuralog Dashboard — Dual Line Chart Widget.
///
/// A two-line chart for health metrics that record two simultaneous readings
/// per data point — most notably Blood Pressure, where each [MetricDataPoint]
/// carries both a systolic and a diastolic value inside its [components] map.
///
/// Line 1 (systolic): solid [accentColor] at full opacity.
/// Line 2 (diastolic): [accentColor] at 55% opacity.
///
/// Supports compact sparkline mode for CategoryCard previews and full detail
/// mode with a legend, axes, and a touch tooltip.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/dashboard/domain/metric_data_point.dart';
import 'package:zuralog/features/dashboard/domain/metric_series.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Component key for the systolic blood pressure reading.
const String _kSystolicKey = 'systolic';

/// Component key for the diastolic blood pressure reading.
const String _kDiastolicKey = 'diastolic';

/// Full-size chart height in logical pixels.
const double _kFullHeight = 200;

/// Compact sparkline height in logical pixels.
const double _kCompactHeight = 48;

/// Legend dot radius in logical pixels.
const double _kLegendDotRadius = 4;

/// Bar data index for the systolic line.
const int _kSystolicIndex = 0;

/// Bar data index for the diastolic line.
const int _kDiastolicIndex = 1;

// ── Widget ────────────────────────────────────────────────────────────────────

/// A two-line chart for paired health metric readings (e.g. Blood Pressure).
///
/// Each [MetricDataPoint] in [series.dataPoints] must carry both readings
/// inside its [MetricDataPoint.components] map:
/// ```dart
/// components: {'systolic': 120, 'diastolic': 78}
/// ```
///
/// Points missing [components], or missing either key, are silently skipped
/// (rendered as gaps — no crash).
///
/// In compact mode ([compact] = `true`):
/// - Both lines rendered, no axes, no legend, fixed 48px height.
///
/// In full mode ([compact] = `false`):
/// - Left y-axis for mmHg values.
/// - Bottom time axis based on [timeRange].
/// - Legend row at the top: "● Systolic  ○ Diastolic".
/// - Touch tooltip: "Systolic: X mmHg / Diastolic: Y mmHg".
///
/// Example:
/// ```dart
/// DualLineChart(
///   series: myBloodPressureSeries,
///   timeRange: TimeRange.month,
///   accentColor: Colors.deepOrange,
/// )
/// ```
class DualLineChart extends StatelessWidget {
  /// Creates a [DualLineChart].
  const DualLineChart({
    super.key,
    required this.series,
    required this.timeRange,
    required this.accentColor,
    this.interactive = true,
    this.compact = false,
  });

  /// The metric time-series data; each point must carry systolic/diastolic
  /// values inside [MetricDataPoint.components].
  final MetricSeries series;

  /// The selected time window; determines x-axis bucketing and labels.
  final TimeRange timeRange;

  /// Primary line colour (systolic). Diastolic uses this at 55% opacity.
  final Color accentColor;

  /// Whether touch tooltips are enabled. Disable for embedded previews.
  final bool interactive;

  /// When `true`, renders a compact sparkline with no axes or legend.
  final bool compact;

  // ── Derived colours ───────────────────────────────────────────────────────

  Color get _systolicColor => accentColor;
  Color get _diastolicColor => accentColor.withValues(alpha: 0.55);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final validPoints = _validPoints;

    if (validPoints.isEmpty) {
      return _EmptyPlaceholder(
        height: compact ? _kCompactHeight : _kFullHeight,
        accentColor: accentColor,
      );
    }

    if (validPoints.length < 2) {
      return SizedBox(
        height: compact ? _kCompactHeight : _kFullHeight,
        child: Center(
          child: Text(
            '—',
            style: TextStyle(color: accentColor.withValues(alpha: 0.4)),
          ),
        ),
      );
    }

    // In full mode, wrap chart inside a Column so we can add the legend above.
    if (compact) {
      return SizedBox(
        height: _kCompactHeight,
        child: LineChart(_buildChartData(isDark, validPoints)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegendRow(
          systolicColor: _systolicColor,
          diastolicColor: _diastolicColor,
        ),
        const SizedBox(height: AppDimens.spaceSm),
        SizedBox(
          height: _kFullHeight,
          child: LineChart(_buildChartData(isDark, validPoints)),
        ),
      ],
    );
  }

  /// Filters data points to only those that carry both systolic and diastolic.
  List<_BPPoint> get _validPoints {
    final result = <_BPPoint>[];
    for (int i = 0; i < series.dataPoints.length; i++) {
      final p = series.dataPoints[i];
      final comp = p.components;
      if (comp == null) continue;
      final systolic = comp[_kSystolicKey];
      final diastolic = comp[_kDiastolicKey];
      if (systolic == null || diastolic == null) continue;
      result.add(_BPPoint(index: i, systolic: systolic, diastolic: diastolic));
    }
    return result;
  }

  /// Builds the [LineChartData] with two line series.
  LineChartData _buildChartData(bool isDark, List<_BPPoint> points) {
    final systolicSpots =
        points.map((p) => FlSpot(p.index.toDouble(), p.systolic)).toList();
    final diastolicSpots =
        points.map((p) => FlSpot(p.index.toDouble(), p.diastolic)).toList();

    // Y bounds: from lowest diastolic to highest systolic with headroom.
    final allValues = [
      ...points.map((p) => p.systolic),
      ...points.map((p) => p.diastolic),
    ];
    final yMin = allValues.reduce((a, b) => a < b ? a : b);
    final yMax = allValues.reduce((a, b) => a > b ? a : b);
    final padding = (yMax - yMin) * 0.15;

    return LineChartData(
      minY: (yMin - padding).clamp(0, double.infinity).toDouble(),
      maxY: yMax + padding,
      lineBarsData: [
        _buildLine(systolicSpots, _systolicColor),
        _buildLine(diastolicSpots, _diastolicColor),
      ],
      gridData:
          compact ? const FlGridData(show: false) : _buildGridData(isDark),
      titlesData:
          compact ? const FlTitlesData(show: false) : _buildTitlesData(isDark, points),
      borderData: FlBorderData(show: false),
      lineTouchData: _buildTouchData(isDark, points),
    );
  }

  /// Builds one [LineChartBarData] line series for [color].
  LineChartBarData _buildLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      color: color,
      barWidth: compact ? 2.0 : 2.5,
      isCurved: true,
      curveSmoothness: 0.35,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  /// Builds horizontal grid lines.
  FlGridData _buildGridData(bool isDark) {
    final gridColor = isDark
        ? AppColors.borderDark.withValues(alpha: 0.5)
        : AppColors.borderLight;
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: 20,
      getDrawingHorizontalLine: (_) => FlLine(
        color: gridColor,
        strokeWidth: 1,
        dashArray: [4, 4],
      ),
    );
  }

  /// Builds left y-axis and bottom x-axis labels.
  FlTitlesData _buildTitlesData(bool isDark, List<_BPPoint> points) {
    final labelStyle = AppTextStyles.labelXs.copyWith(
      color: AppColors.textSecondary,
    );
    final totalCount = series.dataPoints.length;

    return FlTitlesData(
      show: true,
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval: 20,
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == meta.min) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(right: AppDimens.spaceXs),
              child: Text(
                value.toStringAsFixed(0),
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
            if (idx < 0 || idx >= totalCount) return const SizedBox.shrink();
            if (!_shouldShowLabel(idx, totalCount)) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: AppDimens.spaceXs),
              child: Text(_xLabel(idx), style: labelStyle),
            );
          },
        ),
      ),
      rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  /// Builds the touch tooltip data for both lines.
  LineTouchData _buildTouchData(bool isDark, List<_BPPoint> points) {
    if (!interactive || compact) {
      return const LineTouchData(enabled: false);
    }

    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final bgColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => bgColor,
        tooltipBorderRadius: BorderRadius.circular(AppDimens.radiusSm),
        tooltipPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceSm,
          vertical: AppDimens.spaceXs,
        ),
        getTooltipItems: (touchedSpots) {
          // Aggregate systolic and diastolic from whichever line was touched.
          double? sys;
          double? dia;

          for (final spot in touchedSpots) {
            if (spot.barIndex == _kSystolicIndex) sys = spot.y;
            if (spot.barIndex == _kDiastolicIndex) dia = spot.y;
          }

          if (sys == null && dia == null) {
            return touchedSpots.map((_) => null).toList();
          }

          // Build the tooltip text only once (on the first touched spot).
          // Return null for subsequent spots to avoid duplicate tooltips.
          final label = sys != null && dia != null
              ? 'Systolic: ${sys.toStringAsFixed(0)} mmHg'
                  ' / Diastolic: ${dia.toStringAsFixed(0)} mmHg'
              : sys != null
                  ? 'Systolic: ${sys.toStringAsFixed(0)} mmHg'
                  : 'Diastolic: ${dia!.toStringAsFixed(0)} mmHg';

          return touchedSpots.asMap().entries.map((entry) {
            if (entry.key != 0) return null;
            return LineTooltipItem(
              label,
              AppTextStyles.caption.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList();
        },
      ),
      getTouchedSpotIndicator: (barData, spotIndexes) {
        final lineColor = barData.color ?? accentColor;
        return spotIndexes.map((i) {
          return TouchedSpotIndicatorData(
            FlLine(
              color: lineColor,
              strokeWidth: 1.5,
              dashArray: [4, 4],
            ),
            FlDotData(
              show: true,
              getDotPainter: (p, q, r, s) => FlDotCirclePainter(
                radius: 4,
                color: lineColor,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
          );
        }).toList();
      },
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
}

// ── Legend Row ────────────────────────────────────────────────────────────────

/// A compact legend row: "● Systolic  ○ Diastolic".
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.systolicColor,
    required this.diastolicColor,
  });

  final Color systolicColor;
  final Color diastolicColor;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTextStyles.caption.copyWith(
      color: AppColors.textSecondary,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendDot(color: systolicColor, filled: true),
        const SizedBox(width: AppDimens.spaceXs),
        Text('Systolic', style: labelStyle),
        const SizedBox(width: AppDimens.spaceMd),
        _LegendDot(color: diastolicColor, filled: false),
        const SizedBox(width: AppDimens.spaceXs),
        Text('Diastolic', style: labelStyle),
      ],
    );
  }
}

/// A small filled or outlined circle dot used in the legend.
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kLegendDotRadius * 2,
      height: _kLegendDotRadius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }
}

// ── Internal Data Model ───────────────────────────────────────────────────────

/// Lightweight container for a single validated blood-pressure reading.
class _BPPoint {
  const _BPPoint({
    required this.index,
    required this.systolic,
    required this.diastolic,
  });

  /// Original index in [MetricSeries.dataPoints].
  final int index;

  /// Systolic pressure reading in mmHg.
  final double systolic;

  /// Diastolic pressure reading in mmHg.
  final double diastolic;
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
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color;
}
