/// Shared 7-day bar chart used by every category-specific insight body.
/// Bars are category-colored, today is highlighted, and an optional
/// dashed goal line crosses the chart.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class InsightPrimaryChartPoint {
  const InsightPrimaryChartPoint({
    required this.label,
    required this.value,
    required this.isToday,
  });

  /// Short x-axis label (e.g. "M", "T", "W").
  final String label;

  /// Bar height in raw units.
  final double value;

  /// Whether this bar represents today (gets full category color).
  final bool isToday;
}

class InsightPrimaryChart extends StatelessWidget {
  const InsightPrimaryChart({
    super.key,
    required this.title,
    required this.categoryColor,
    required this.points,
    required this.formatTooltip,
    this.goalValue,
    this.goalLabel,
    this.delay = const Duration(milliseconds: 180),
    this.formatYAxis,
  });

  /// Card title, e.g. "Last 7 nights", "This week's steps".
  final String title;

  /// Category color used for today's bar and the goal line.
  final Color categoryColor;

  /// Data points, oldest first.
  final List<InsightPrimaryChartPoint> points;

  /// Formats a bar's raw value into a tooltip string (e.g. "7h 24m").
  final String Function(double value) formatTooltip;

  /// Optional horizontal goal/target value drawn as a dashed line.
  final double? goalValue;

  /// Optional right-aligned label for the goal legend chip.
  final String? goalLabel;

  /// Stagger delay when the chart appears.
  final Duration delay;

  /// Formats a grid-line value for the y-axis label. When null, the
  /// axis labels fall back to a compact integer formatter so every
  /// chart gets useful scale labels even without explicit wiring.
  final String Function(double value)? formatYAxis;

  String _defaultYAxisFormat(double v) {
    if (v.abs() >= 1000) {
      return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    }
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    if (points.isEmpty) return const SizedBox.shrink();

    final maxValue = points.map((p) => p.value).fold<double>(0.0, math.max);
    final rangeCeiling = goalValue != null
        ? math.max(maxValue, goalValue!)
        : maxValue;
    final maxY = math.max(rangeCeiling * 1.15, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZFadeSlideIn(
        delay: delay,
        child: Container(
          decoration: BoxDecoration(
            color: colors.cardBackground,
            border: Border.all(
              color: colors.border.withValues(alpha: 0.4),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          ),
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  if (goalLabel != null)
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 2,
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          goalLabel!,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceMd),
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 4,
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
                          interval: maxY / 4,
                          getTitlesWidget: (value, meta) {
                            // Skip the top-most label (duplicates the max)
                            // and the zero label to keep the axis quiet.
                            if (value <= 0) return const SizedBox.shrink();
                            if ((value - maxY).abs() < 0.01) {
                              return const SizedBox.shrink();
                            }
                            final fmt = formatYAxis ?? _defaultYAxisFormat;
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
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= points.length) {
                              return const SizedBox.shrink();
                            }
                            final p = points[i];
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                p.label,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: p.isToday
                                      ? colors.textPrimary
                                      : colors.textTertiary,
                                  fontWeight: p.isToday
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    extraLinesData: goalValue == null
                        ? ExtraLinesData()
                        : ExtraLinesData(
                            horizontalLines: [
                              HorizontalLine(
                                y: goalValue!,
                                color: categoryColor.withValues(alpha: 0.45),
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
                              toY: points[i].value,
                              color: points[i].isToday
                                  ? categoryColor
                                  : categoryColor.withValues(alpha: 0.38),
                              width: 18,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxY,
                                color:
                                    categoryColor.withValues(alpha: 0.06),
                              ),
                            ),
                          ],
                        ),
                    ],
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => colors.surface,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            formatTooltip(rod.toY),
                            AppTextStyles.bodySmall.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
