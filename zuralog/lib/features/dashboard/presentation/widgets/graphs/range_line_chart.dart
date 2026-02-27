/// Zuralog Dashboard — Range Line Chart Widget.
///
/// A specialised line chart for metrics that report a value range over each
/// time bucket — most notably Heart Rate, where each data point carries an
/// average value plus optional [MetricDataPoint.min] and [MetricDataPoint.max]
/// extremes. Renders a centre line (average/typical) with a shaded band
/// between min and max using `fl_chart`'s [BetweenBarsData].
///
/// Falls back to a plain line chart (identical to [LineChartGraph]) when
/// data points do not carry min/max information.
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

/// Full-size chart height in logical pixels.
const double _kFullHeight = 200;

/// Compact sparkline height in logical pixels.
const double _kCompactHeight = 48;

/// Index of the centre (average) line inside [lineBarsData].
const int _kCentreLineIndex = 0;

/// Index of the min-band line inside [lineBarsData].
const int _kMinLineIndex = 1;

/// Index of the max-band line inside [lineBarsData].
const int _kMaxLineIndex = 2;

// ── Widget ────────────────────────────────────────────────────────────────────

/// A range line chart showing a centre average line with a min–max band.
///
/// Each [MetricDataPoint] in [series.dataPoints] may carry optional [min]
/// and [max] fields. When they are present, the chart draws:
///
/// - A solid centre line in [accentColor] for the primary value.
/// - A transparent min line and max line whose interior is shaded with
///   [accentColor] at 15% opacity using [BetweenBarsData].
///
/// When min/max are absent (all null), the widget falls back to drawing only
/// the centre line — equivalent to a plain [LineChartGraph].
///
/// In compact mode ([compact] = `true`): just the centre line and a very light
/// shaded area, no axes, no labels, fixed height 48px.
///
/// In full mode ([compact] = `false`):
/// - Left y-axis in the metric's unit (e.g. bpm).
/// - Bottom time axis with smart date labels from [timeRange].
/// - Touch tooltip: "Avg: X | Min: Y | Max: Z bpm".
///
/// Example:
/// ```dart
/// RangeLineChart(
///   series: myHeartRateSeries,
///   timeRange: TimeRange.week,
///   accentColor: Colors.red,
/// )
/// ```
class RangeLineChart extends StatelessWidget {
  /// Creates a [RangeLineChart].
  const RangeLineChart({
    super.key,
    required this.series,
    required this.timeRange,
    required this.accentColor,
    this.interactive = true,
    this.compact = false,
  });

  /// The metric time-series data; data points may include [MetricDataPoint.min]
  /// and [MetricDataPoint.max] values.
  final MetricSeries series;

  /// The selected time window; determines x-axis bucketing and labels.
  final TimeRange timeRange;

  /// The centre line colour, derived from the metric's health category.
  final Color accentColor;

  /// Whether touch tooltips are enabled. Disable for embedded previews.
  final bool interactive;

  /// When `true`, renders a compact version with no axes and a fixed 48px height.
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

    return SizedBox(
      height: compact ? _kCompactHeight : _kFullHeight,
      child: LineChart(_buildChartData(isDark)),
    );
  }

  /// Returns `true` if any data point carries min/max range information.
  bool get _hasRangeData =>
      series.dataPoints.any((p) => p.min != null && p.max != null);

  /// Builds the complete [LineChartData] including min/max band lines.
  LineChartData _buildChartData(bool isDark) {
    final points = series.dataPoints;
    final hasRange = _hasRangeData;

    // Build FlSpot lists for centre, min, and max series.
    final centreSpots = <FlSpot>[];
    final minSpots = <FlSpot>[];
    final maxSpots = <FlSpot>[];

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = i.toDouble();
      centreSpots.add(FlSpot(x, p.value));
      if (hasRange) {
        minSpots.add(FlSpot(x, p.min ?? p.value));
        maxSpots.add(FlSpot(x, p.max ?? p.value));
      }
    }

    // Compute y-axis bounds from all relevant values.
    double overallMin = series.stats.min;
    double overallMax = series.stats.max;
    if (hasRange) {
      for (final p in points) {
        if (p.min != null && p.min! < overallMin) overallMin = p.min!;
        if (p.max != null && p.max! > overallMax) overallMax = p.max!;
      }
    }
    final rangePadding = (overallMax - overallMin) * 0.15;
    final yMin = (overallMin - rangePadding).clamp(0, double.infinity).toDouble();
    final yMax = overallMax + rangePadding;

    // Assemble chart bars — centre always index 0, min at 1, max at 2.
    final bars = <LineChartBarData>[
      _buildCentreLine(centreSpots),
      if (hasRange) ...[
        _buildBandLine(minSpots, visible: false),
        _buildBandLine(maxSpots, visible: false),
      ],
    ];

    // Between-bars shading from min (index 1) to max (index 2).
    final betweenBars = hasRange
        ? [
            BetweenBarsData(
              fromIndex: _kMinLineIndex,
              toIndex: _kMaxLineIndex,
              color: accentColor.withValues(alpha: 0.15),
            ),
          ]
        : <BetweenBarsData>[];

    return LineChartData(
      minY: yMin,
      maxY: yMax > 0 ? yMax : 10.0,
      lineBarsData: bars,
      betweenBarsData: betweenBars,
      gridData:
          compact ? const FlGridData(show: false) : _buildGridData(isDark),
      titlesData:
          compact ? const FlTitlesData(show: false) : _buildTitlesData(isDark),
      borderData: FlBorderData(show: false),
      lineTouchData: _buildTouchData(isDark, hasRange),
    );
  }

  /// Builds the solid centre (average) line.
  LineChartBarData _buildCentreLine(List<FlSpot> spots) {
    return LineChartBarData(
      spots: spots,
      color: accentColor,
      barWidth: compact ? 2.0 : 2.5,
      isCurved: true,
      curveSmoothness: 0.35,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  /// Builds a transparent band boundary line (min or max).
  ///
  /// These lines are invisible themselves; only the [BetweenBarsData] fill
  /// is rendered between them.
  LineChartBarData _buildBandLine(
    List<FlSpot> spots, {
    required bool visible,
  }) {
    return LineChartBarData(
      spots: spots,
      color: Colors.transparent,
      barWidth: 0,
      isCurved: true,
      curveSmoothness: 0.35,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
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

  /// Builds left y-axis and bottom x-axis title data.
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
            if (idx < 0 || idx >= count) return const SizedBox.shrink();
            if (!_shouldShowLabel(idx, count)) return const SizedBox.shrink();
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

  /// Builds touch tooltip data.
  ///
  /// When [hasRange] is `true` the tooltip shows "Avg: X | Min: Y | Max: Z".
  /// Otherwise just the value.
  LineTouchData _buildTouchData(bool isDark, bool hasRange) {
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
          // Only show the tooltip for the centre line (index 0).
          // The band lines (index 1, 2) are invisible — skip them.
          return touchedSpots.map((spot) {
            if (spot.barIndex != _kCentreLineIndex) {
              return null;
            }
            final idx = spot.x.toInt();
            if (idx < 0 || idx >= series.dataPoints.length) return null;
            final point = series.dataPoints[idx];

            final String label;
            if (hasRange && point.min != null && point.max != null) {
              label =
                  'Avg: ${spot.y.toStringAsFixed(0)}'
                  ' | Min: ${point.min!.toStringAsFixed(0)}'
                  ' | Max: ${point.max!.toStringAsFixed(0)}';
            } else {
              label = spot.y.toStringAsFixed(1);
            }

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
        return spotIndexes.map((i) {
          return TouchedSpotIndicatorData(
            FlLine(
              color: accentColor,
              strokeWidth: 1.5,
              dashArray: [4, 4],
            ),
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
