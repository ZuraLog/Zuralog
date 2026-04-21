/// Slim chart primitive for the Data tab category cards.
///
/// Renders one of three visualisations — bars, line, or 1–5 dots — across
/// 7 days. Unlike [InsightPrimaryChart], this widget has no card chrome
/// (no container, border, title, or padding) so it can sit inside an
/// existing card as a hero visual.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Which rendering mode [ZCategoryChart] should use.
enum ZCategoryChartKind {
  /// Vertical bars — good for countable metrics (sleep, steps, calories).
  bars,

  /// Smooth line with gradient fill — good for continuous metrics
  /// (resting heart rate, weight).
  line,

  /// Seven colored dots — good for 1–5 mood/wellness scores.
  dots,
}

/// A naked 7-day chart meant to live inside an existing card.
///
/// Pure visual — no title, no border, no padding. Consumers give it the
/// raw values plus day labels and it paints a slim chart that fills the
/// supplied [height].
class ZCategoryChart extends StatelessWidget {
  const ZCategoryChart({
    super.key,
    required this.kind,
    required this.points,
    required this.color,
    required this.dayLabels,
    required this.todayIndex,
    this.goalValue,
    this.formatY,
    this.height = 100,
  });

  /// Which visualisation to render.
  final ZCategoryChartKind kind;

  /// The 7 raw values, oldest first. Non-finite entries are ignored.
  final List<double> points;

  /// Category accent color — used for today's bar/dot, line stroke,
  /// gradient fill, and the dashed goal line.
  final Color color;

  /// Seven short x-axis labels, e.g. ['M', 'T', 'W', 'T', 'F', 'S', 'S'].
  final List<String> dayLabels;

  /// Index of "today" in [points] / [dayLabels] (0..6). Pass `-1` to
  /// disable the today highlight.
  final int todayIndex;

  /// Optional horizontal target drawn as a dashed line. Only honoured
  /// in [ZCategoryChartKind.bars] and [ZCategoryChartKind.line].
  final double? goalValue;

  /// Formats a y-axis grid value. Defaults to a compact integer/`k`
  /// formatter if omitted.
  final String Function(double value)? formatY;

  /// Overall chart height. The chart fills this box exactly.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();

    switch (kind) {
      case ZCategoryChartKind.bars:
        return SizedBox(height: height, child: _buildBars(context));
      case ZCategoryChartKind.line:
        return SizedBox(height: height, child: _buildLine(context));
      case ZCategoryChartKind.dots:
        return SizedBox(height: height, child: _buildDots(context));
    }
  }

  // ---------------------------------------------------------------------------
  // Bars
  // ---------------------------------------------------------------------------

  Widget _buildBars(BuildContext context) {
    final colors = AppColorsOf(context);
    final finite = points.where((v) => v.isFinite).toList();
    if (finite.isEmpty) return const SizedBox.shrink();

    final rawMax = finite.fold<double>(0.0, math.max);
    final ceiling = goalValue != null ? math.max(rawMax, goalValue!) : rawMax;
    final maxY = math.max(ceiling * 1.15, 1.0);
    final interval = maxY / 4;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colors.border.withValues(alpha: 0.25),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value <= 0) return const SizedBox.shrink();
                if ((value - maxY).abs() < 0.01) {
                  return const SizedBox.shrink();
                }
                final fmt = formatY ?? _defaultCompact;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    fmt(value),
                    textAlign: TextAlign.right,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textTertiary,
                      fontSize: 10,
                      letterSpacing: 0.3,
                    ),
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
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) =>
                  _bottomLabel(context, value.toInt()),
            ),
          ),
        ),
        extraLinesData: goalValue == null
            ? ExtraLinesData()
            : ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: goalValue!,
                    color: color.withValues(alpha: 0.45),
                    strokeWidth: 1.5,
                    dashArray: [4, 4],
                  ),
                ],
              ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].isFinite ? points[i] : 0.0,
                  color: i == todayIndex
                      ? color
                      : color.withValues(alpha: 0.38),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: color.withValues(alpha: 0.06),
                  ),
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(enabled: false),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Line
  // ---------------------------------------------------------------------------

  Widget _buildLine(BuildContext context) {
    final colors = AppColorsOf(context);
    final finite = points.where((v) => v.isFinite).toList();
    if (finite.length < 2) return const SizedBox.shrink();

    final rawMin = finite.reduce(math.min);
    final rawMax = finite.reduce(math.max);
    final padding = math.max((rawMax - rawMin) * 0.12, 0.5);
    var minY = rawMin - padding;
    var maxY = rawMax + padding;

    // If a goal is supplied, make sure it's visible on the chart.
    if (goalValue != null && goalValue!.isFinite) {
      minY = math.min(minY, goalValue! - padding);
      maxY = math.max(maxY, goalValue! + padding);
    }

    final interval = math.max((maxY - minY) / 4, 0.001);

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        if (points[i].isFinite) FlSpot(i.toDouble(), points[i]),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: colors.border.withValues(alpha: 0.25),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: interval,
              getTitlesWidget: (value, meta) {
                // Skip top and bottom labels to keep the axis quiet.
                if ((value - maxY).abs() < interval * 0.1) {
                  return const SizedBox.shrink();
                }
                if ((value - minY).abs() < interval * 0.1) {
                  return const SizedBox.shrink();
                }
                final fmt = formatY ?? _defaultCompact;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    fmt(value),
                    textAlign: TextAlign.right,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textTertiary,
                      fontSize: 10,
                      letterSpacing: 0.3,
                    ),
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
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) =>
                  _bottomLabel(context, value.toInt()),
            ),
          ),
        ),
        extraLinesData: goalValue == null
            ? ExtraLinesData()
            : ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: goalValue!,
                    color: color.withValues(alpha: 0.45),
                    strokeWidth: 1.5,
                    dashArray: [4, 4],
                  ),
                ],
              ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            barWidth: 2.0,
            color: color.withValues(alpha: 0.9),
            isStrokeCapRound: true,
            isStrokeJoinRound: true,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, _) => spot.x.toInt() == todayIndex,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3.5,
                color: color,
                strokeWidth: 1,
                strokeColor: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dots (1–5 mood)
  // ---------------------------------------------------------------------------

  Widget _buildDots(BuildContext context) {
    final colors = AppColorsOf(context);
    const dotSize = 24.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < points.length; i++)
                _buildMoodDot(i, dotSize),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < dayLabels.length; i++)
              Expanded(
                child: Center(
                  child: Text(
                    dayLabels[i],
                    style: AppTextStyles.labelSmall.copyWith(
                      color: i == todayIndex
                          ? colors.textPrimary
                          : colors.textTertiary,
                      fontWeight: i == todayIndex
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoodDot(int i, double size) {
    final value = i < points.length ? points[i] : double.nan;
    final missing = !value.isFinite || value <= 0;

    if (missing) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(
            color: color.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
      );
    }

    final alpha = (value / 5.0).clamp(0.25, 1.0);
    final isToday = i == todayIndex;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: alpha),
        border: isToday
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1,
              )
            : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  Widget _bottomLabel(BuildContext context, int i) {
    if (i < 0 || i >= dayLabels.length) return const SizedBox.shrink();
    final colors = AppColorsOf(context);
    final isToday = i == todayIndex;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        dayLabels[i],
        style: AppTextStyles.labelSmall.copyWith(
          color: isToday ? colors.textPrimary : colors.textTertiary,
          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  String _defaultCompact(double v) {
    if (v.abs() >= 1000) {
      return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    }
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
