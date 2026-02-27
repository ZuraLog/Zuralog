/// Zuralog Dashboard — Mood Timeline Widget.
///
/// Renders a scatter plot for State of Mind data where each data point is
/// placed on a 1–5 valence scale and displayed with an emoji marker.
///
/// [MetricDataPoint.value] encodes mood on a 1.0 (very unpleasant) to
/// 5.0 (very pleasant) scale. A dashed connecting line is drawn between
/// consecutive points at 30 % opacity.
///
/// Uses `fl_chart`'s [LineChart] for the line/scatter rendering; emoji
/// labels are drawn via a custom [FlDotPainter].
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/dashboard/domain/metric_series.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';

// ── Internal helpers ──────────────────────────────────────────────────────────

/// Returns the emoji for a valence [value] in the 1–5 range.
String _moodEmoji(double value) {
  if (value <= 1.5) return '😔';
  if (value <= 2.5) return '😐';
  if (value <= 3.5) return '🙂';
  if (value <= 4.5) return '😊';
  return '😄';
}

/// Returns the mood label for a valence [value].
String _moodLabel(double value) {
  if (value <= 1.5) return 'Very Low';
  if (value <= 2.5) return 'Low';
  if (value <= 3.5) return 'Neutral';
  if (value <= 4.5) return 'High';
  return 'Very High';
}

/// Formats a [DateTime] as "MMM d" (e.g., "Feb 26").
String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}';
}

/// Formats an x-axis label from [DateTime] and [TimeRange].
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

/// Y-axis label for a given integer mood level (1–5).
String? _yAxisLabel(double value) {
  switch (value.round()) {
    case 1:
      return 'Very Low';
    case 2:
      return 'Low';
    case 3:
      return 'Neutral';
    case 4:
      return 'High';
    case 5:
      return 'Very High';
    default:
      return null;
  }
}

// ── Custom dot painter ────────────────────────────────────────────────────────

/// Paints an emoji character centred at the data point location.
class _EmojiDotPainter extends FlDotPainter {
  const _EmojiDotPainter({required this.emoji, required this.dotSize});

  final String emoji;
  final double dotSize;

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: dotSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      offsetInCanvas - Offset(tp.width / 2, tp.height / 2),
    );
  }

  @override
  Size getSize(FlSpot spot) => Size(dotSize + 4, dotSize + 4);

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;

  @override
  Color get mainColor => Colors.transparent;

  @override
  List<Object?> get props => [emoji, dotSize];
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// A scatter/line chart for mood (State of Mind) data on a 1–5 valence scale.
///
/// Each data point is rendered with an emoji marker reflecting its mood value.
/// A dashed connecting line at 30 % accent opacity links consecutive points.
///
/// Example usage:
/// ```dart
/// MoodTimeline(
///   series: moodSeries,
///   timeRange: TimeRange.week,
///   accentColor: Colors.purple,
/// )
/// ```
class MoodTimeline extends StatelessWidget {
  /// Creates a [MoodTimeline].
  ///
  /// [series] — the State of Mind time-series. [MetricDataPoint.value]
  /// must be in the range 1.0–5.0.
  ///
  /// [timeRange] — the selected time window (controls x-axis).
  ///
  /// [accentColor] — accent colour for the dashed connecting line.
  ///
  /// [interactive] — when `true`, tap shows a date + mood label tooltip.
  ///
  /// [compact] — when `true`, renders a 48 px sparkline with coloured circles
  /// (no emoji, no axes).
  const MoodTimeline({
    super.key,
    required this.series,
    required this.timeRange,
    required this.accentColor,
    this.interactive = true,
    this.compact = false,
  });

  /// The State of Mind time-series to visualise.
  final MetricSeries series;

  /// The selected time window.
  final TimeRange timeRange;

  /// The accent colour for the dashed connecting line.
  final Color accentColor;

  /// Enables touch tooltip when `true`.
  final bool interactive;

  /// When `true`, renders a compact 48 px scatter sparkline with no emoji.
  final bool compact;

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (series.dataPoints.isEmpty) {
      return _EmptyState(compact: compact);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final points = series.dataPoints;

    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value.clamp(1.0, 5.0)))
        .toList();

    if (compact) {
      return _CompactMoodTimeline(
        spots: spots,
        accentColor: accentColor,
      );
    }

    final lineData = LineChartData(
      minY: 0.8,
      maxY: 5.2,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: accentColor.withValues(alpha: 0.3),
          barWidth: 1.5,
          dashArray: [4, 4],
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) {
              final emoji = _moodEmoji(spot.y);
              return _EmojiDotPainter(emoji: emoji, dotSize: 18);
            },
          ),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (_) => FlLine(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          strokeWidth: 0.5,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 56,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final label = _yAxisLabel(value);
              if (label == null) return const SizedBox.shrink();
              return Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                ),
              );
            },
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
                _xLabel(points[idx].timestamp, timeRange),
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
      lineTouchData: interactive
          ? LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => isDark
                    ? AppColors.surfaceDark
                    : AppColors.surfaceLight,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final idx = spot.spotIndex;
                    if (idx < 0 || idx >= points.length) {
                      return LineTooltipItem(
                        '',
                        AppTextStyles.caption.copyWith(color: labelColor),
                      );
                    }
                    final point = points[idx];
                    final label = _moodLabel(point.value);
                    final dateStr = _formatDate(point.timestamp);
                    return LineTooltipItem(
                      '$label — $dateStr',
                      AppTextStyles.caption.copyWith(color: labelColor),
                    );
                  }).toList();
                },
              ),
            )
          : LineTouchData(enabled: false),
    );

    return LineChart(lineData);
  }
}

// ── Compact variant ───────────────────────────────────────────────────────────

/// A 48 px compact scatter sparkline showing coloured circles (no emoji).
class _CompactMoodTimeline extends StatelessWidget {
  const _CompactMoodTimeline({
    required this.spots,
    required this.accentColor,
  });

  final List<FlSpot> spots;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: LineChart(
        LineChartData(
          minY: 0.8,
          maxY: 5.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: accentColor.withValues(alpha: 0.3),
              barWidth: 1,
              dashArray: [4, 4],
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 3,
                  color: accentColor,
                  strokeWidth: 0,
                  strokeColor: Colors.transparent,
                ),
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: LineTouchData(enabled: false),
        ),
      ),
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
