/// Zuralog — Tile Visualization Widgets (Phase 5).
///
/// All 14 visualization sub-widgets for metric tiles.
/// Each widget accepts a [TileVisualizationData] subtype and renders
/// an appropriate chart or graphic at whatever size given by the parent.
///
/// Entry point: [buildTileVisualization] factory function.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart'
    hide BarChartData, LineChartData, BarChartGroupData;
import 'package:fl_chart/fl_chart.dart' as fl;
import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';


// ── TileVisualizationFactory ──────────────────────────────────────────────────

/// Maps a [TileVisualizationData] subtype to its corresponding widget.
///
/// Pass [categoryColor] for widgets that tint themselves with the category hue.
Widget buildTileVisualization({
  required TileVisualizationData data,
  required Color categoryColor,
}) {
  return switch (data) {
    BarChartData() => BarChartViz(data: data, categoryColor: categoryColor),
    RingData() => RingViz(data: data, categoryColor: categoryColor),
    LineChartData() => LineChartViz(data: data, categoryColor: categoryColor),
    StackedBarData() => StackedBarViz(data: data),
    AreaChartData() => AreaChartViz(data: data, categoryColor: categoryColor),
    GaugeData() => GaugeViz(data: data, categoryColor: categoryColor),
    ValueData() => ValueViz(data: data),
    DualValueData() => DualValueViz(data: data),
    MacroBarsData() => MacroBarsViz(data: data, categoryColor: categoryColor),
    FillGaugeData() => FillGaugeViz(data: data, categoryColor: categoryColor),
    DotsData() => DotsViz(data: data, categoryColor: categoryColor),
    CountBadgeData() => CountBadgeViz(data: data),
    CalendarDotsData() => CalendarDotsViz(data: data),
    EnvironmentData() => EnvironmentViz(data: data),
  };
}

// ── BarChartViz ───────────────────────────────────────────────────────────────

/// 7-day bar chart. Used by: Steps.
///
/// - Bar color = [categoryColor] at varying opacity (today 100%, yesterday 85%, older 60%).
/// - Dashed horizontal line at [BarChartData.average] when non-null.
/// - X-axis: day labels, 9px tertiary color. No Y-axis or grid.
class BarChartViz extends StatelessWidget {
  const BarChartViz({
    super.key,
    required this.data,
    required this.categoryColor,
  });

  final BarChartData data;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final values = data.dailyValues;
    final labels = data.dayLabels;
    final count = values.length;
    final maxY = values.isEmpty
        ? 1.0
        : values.reduce(math.max) * 1.2;

    double opacityFor(int index) {
      final fromEnd = count - 1 - index;
      if (fromEnd == 0) return 1.0;
      if (fromEnd == 1) return 0.85;
      return 0.60;
    }

    final barGroups = List.generate(count, (i) {
      return fl.BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: values[i],
            color: categoryColor.withValues(alpha: opacityFor(i)),
            width: 10,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      );
    });

    final extraLines = <HorizontalLine>[];
    if (data.average != null) {
      extraLines.add(
        HorizontalLine(
          y: data.average!,
          color: categoryColor.withValues(alpha: 0.6),
          strokeWidth: 1,
          dashArray: [4, 4],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1.8,
      child: BarChart(
        fl.BarChartData(
          maxY: maxY,
          barGroups: barGroups,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(horizontalLines: extraLines),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
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
                reservedSize: 16,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  return Text(
                    labels[i],
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textTertiary,
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(enabled: false),
        ),
      ),
    );
  }
}

// ── RingViz ───────────────────────────────────────────────────────────────────

/// Circular progress ring. Used by: Active Calories, Sleep Duration.
///
/// Fill fraction = value / max, clamped 0.0–1.0.
/// Center text: goalLabel if provided, else percentage.
class RingViz extends StatelessWidget {
  const RingViz({
    super.key,
    required this.data,
    required this.categoryColor,
  });

  final RingData data;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final fraction = (data.max > 0 ? data.value / data.max : 0.0).clamp(0.0, 1.0);
    final centerText = data.goalLabel ?? '${(fraction * 100).round()}%';

    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: fraction,
              strokeWidth: 8,
              backgroundColor: categoryColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
            ),
            Text(
              centerText,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── LineChartViz ──────────────────────────────────────────────────────────────

/// Thin sparkline chart. Used by: Resting HR, HRV.
///
/// Optional range band between [rangeLow] and [rangeHigh].
/// Delta badge below the chart.
class LineChartViz extends StatelessWidget {
  const LineChartViz({
    super.key,
    required this.data,
    required this.categoryColor,
  });

  final LineChartData data;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final values = data.values;
    if (values.isEmpty) return const SizedBox.shrink();

    final spots = List.generate(
      values.length,
      (i) => FlSpot(i.toDouble(), values[i]),
    );

    final minY = data.rangeLow ??
        (values.reduce(math.min) - (values.reduce(math.max) - values.reduce(math.min)) * 0.1);
    final maxY = data.rangeHigh ??
        (values.reduce(math.max) + (values.reduce(math.max) - values.reduce(math.min)) * 0.1);

    final extraLines = <HorizontalLine>[];
    if (data.rangeLow != null) {
      extraLines.add(HorizontalLine(
        y: data.rangeLow!,
        color: categoryColor.withValues(alpha: 0.3),
        strokeWidth: 1,
        dashArray: [4, 4],
      ));
    }
    if (data.rangeHigh != null) {
      extraLines.add(HorizontalLine(
        y: data.rangeHigh!,
        color: categoryColor.withValues(alpha: 0.3),
        strokeWidth: 1,
        dashArray: [4, 4],
      ));
    }

    // Range fill between low and high
    BetweenBarsData? betweenBarsData;
    List<LineChartBarData> lineBars;

    if (data.rangeLow != null && data.rangeHigh != null) {
      final lowSpots = List.generate(
        values.length,
        (i) => FlSpot(i.toDouble(), data.rangeLow!),
      );
      final highSpots = List.generate(
        values.length,
        (i) => FlSpot(i.toDouble(), data.rangeHigh!),
      );
      lineBars = [
        // Low band line (invisible)
        LineChartBarData(
          spots: lowSpots,
          isCurved: false,
          color: Colors.transparent,
          dotData: const FlDotData(show: false),
        ),
        // High band line (invisible)
        LineChartBarData(
          spots: highSpots,
          isCurved: false,
          color: Colors.transparent,
          dotData: const FlDotData(show: false),
        ),
        // Actual data line
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: categoryColor,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ];
      betweenBarsData = BetweenBarsData(
        fromIndex: 0,
        toIndex: 1,
        color: categoryColor.withValues(alpha: 0.1),
      );
    } else {
      lineBars = [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: categoryColor,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ];
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 2.5,
          child: LineChart(
            fl.LineChartData(
              minY: minY,
              maxY: maxY,
              lineBarsData: lineBars,
              betweenBarsData:
                  betweenBarsData != null ? [betweenBarsData] : [],
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(
                leftTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              extraLinesData: ExtraLinesData(horizontalLines: extraLines),
              lineTouchData: const LineTouchData(enabled: false),
            ),
          ),
        ),
        if (data.delta != null) ...[
          const SizedBox(height: 4),
          _DeltaBadge(delta: data.delta!),
        ],
      ],
    );
  }
}

// ── StackedBarViz ─────────────────────────────────────────────────────────────

/// Horizontal stacked bar for sleep stages. Used by: Sleep Stages.
///
/// Segments: deep=purple, REM=blue, light=teal, awake=gray.
class StackedBarViz extends StatelessWidget {
  const StackedBarViz({super.key, required this.data});

  final StackedBarData data;

  static const _segmentColors = <String, Color>{
    'Deep': AppColors.categorySleep,      // 0xFF5E5CE6 — purple
    'REM': AppColors.categoryVitals,      // 0xFF6AC4DC — blue
    'Light': AppColors.categoryBody,      // 0xFF64D2FF — teal/light-blue
    'Awake': AppColors.textTertiary,      // 0xFFABABAB — gray
  };

  static Color _colorFor(String label) =>
      _segmentColors[label] ?? AppColors.textTertiary;

  @override
  Widget build(BuildContext context) {
    final segments = data.segments;
    if (segments.isEmpty) return const SizedBox.shrink();

    final totalHours =
        segments.fold<double>(0, (sum, s) => sum + s.hours);
    if (totalHours == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stacked bar
        SizedBox(
          height: 20,
          child: Row(
            children: segments.map((s) {
              final flex = (s.hours / totalHours * 1000).round();
              return Expanded(
                flex: flex,
                child: Tooltip(
                  message: '${s.label}: ${s.hours.toStringAsFixed(1)}h',
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: _colorFor(s.label),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        // Legend row
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: segments.map((s) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _colorFor(s.label),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  '${s.label} ${s.hours.toStringAsFixed(1)}h',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── AreaChartViz ──────────────────────────────────────────────────────────────

/// Area chart with optional target line. Used by: Weight.
class AreaChartViz extends StatelessWidget {
  const AreaChartViz({
    super.key,
    required this.data,
    required this.categoryColor,
  });

  final AreaChartData data;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final values = data.values;
    if (values.isEmpty) return const SizedBox.shrink();

    final spots = List.generate(
      values.length,
      (i) => FlSpot(i.toDouble(), values[i]),
    );

    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = (maxVal - minVal).abs();
    final padding = range > 0 ? range * 0.15 : 1.0;

    double minY = minVal - padding;
    double maxY = maxVal + padding;
    if (data.targetValue != null) {
      minY = math.min(minY, data.targetValue! - padding);
      maxY = math.max(maxY, data.targetValue! + padding);
    }

    final extraLines = <HorizontalLine>[];
    if (data.targetValue != null) {
      extraLines.add(HorizontalLine(
        y: data.targetValue!,
        color: categoryColor.withValues(alpha: 0.5),
        strokeWidth: 1,
        dashArray: [6, 4],
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 2.2,
          child: LineChart(
            fl.LineChartData(
              minY: minY,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: categoryColor,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: categoryColor.withValues(alpha: 0.12),
                  ),
                ),
              ],
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(
                leftTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              extraLinesData: ExtraLinesData(horizontalLines: extraLines),
              lineTouchData: const LineTouchData(enabled: false),
            ),
          ),
        ),
        if (data.delta != null) ...[
          const SizedBox(height: 4),
          _DeltaBadge(delta: data.delta!, unit: 'kg', positiveIsGood: false),
        ],
      ],
    );
  }
}

// ── GaugeViz ──────────────────────────────────────────────────────────────────

/// Semicircular gauge. Used by: Body Fat %.
///
/// Arc from -π to 0 (left to right). Fill = [GaugeData.percent].
class GaugeViz extends StatelessWidget {
  const GaugeViz({
    super.key,
    required this.data,
    required this.categoryColor,
  });

  final GaugeData data;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 2.0,
          child: CustomPaint(
            painter: _GaugePainter(
              percent: data.percent,
              color: categoryColor,
            ),
          ),
        ),
        if (data.label != null) ...[
          const SizedBox(height: 4),
          Text(
            data.label!,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.percent, required this.color});

  final double percent;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.height * 0.18;
    final center = Offset(size.width / 2, size.height);
    final radius = (size.width / 2) - strokeWidth / 2;

    // Track
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      trackPaint,
    );

    // Fill
    final fillPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi * percent,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.percent != percent || old.color != color;
}

// ── ValueViz ──────────────────────────────────────────────────────────────────

/// Large centered value display. Used by: VO₂ Max, SpO2, Mobility.
class ValueViz extends StatelessWidget {
  const ValueViz({super.key, required this.data});

  final ValueData data;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        data.statusColor != null ? Color(data.statusColor!) : null;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (statusColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                data.primaryValue,
                style: AppTextStyles.displaySmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (data.secondaryLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              data.secondaryLabel!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── DualValueViz ──────────────────────────────────────────────────────────────

/// Two-value display (e.g. blood pressure). Used by: Blood Pressure.
class DualValueViz extends StatelessWidget {
  const DualValueViz({super.key, required this.data});

  final DualValueData data;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top value + label
          _ValueRow(value: data.topValue, label: data.topLabel),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '/',
              style: AppTextStyles.displaySmall.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          // Bottom value + label
          _ValueRow(value: data.bottomValue, label: data.bottomLabel),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: AppTextStyles.displaySmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

// ── MacroBarsViz ──────────────────────────────────────────────────────────────

/// Macro nutrition bars. Used by: Calories.
class MacroBarsViz extends StatelessWidget {
  const MacroBarsViz({
    super.key,
    required this.data,
    required this.categoryColor,
  });

  final MacroBarsData data;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.totalCalories,
          style: AppTextStyles.displaySmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...data.macros.map((macro) {
          final fraction = macro.goal > 0
              ? (macro.current / macro.goal).clamp(0.0, 1.0)
              : 0.0;
          final pct = '${(fraction * 100).round()}%';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      macro.label,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    Text(
                      pct,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                LinearProgressIndicator(
                  value: fraction,
                  backgroundColor: categoryColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── FillGaugeViz ──────────────────────────────────────────────────────────────

/// Vertical fill visualization. Used by: Water.
class FillGaugeViz extends StatelessWidget {
  const FillGaugeViz({
    super.key,
    required this.data,
    required this.categoryColor,
  });

  final FillGaugeData data;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final fraction =
        data.goal > 0 ? (data.current / data.goal).clamp(0.0, 1.0) : 0.0;
    final unit = data.unit ?? '';
    final currentStr = data.current % 1 == 0
        ? data.current.toInt().toString()
        : data.current.toStringAsFixed(1);
    final goalStr = data.goal % 1 == 0
        ? data.goal.toInt().toString()
        : data.goal.toStringAsFixed(1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 80,
          child: CustomPaint(
            painter: _FillGaugePainter(
              fraction: fraction,
              color: categoryColor,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$currentStr / $goalStr$unit',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _FillGaugePainter extends CustomPainter {
  const _FillGaugePainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(8);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // Background
    final bgPaint = Paint()..color = color.withValues(alpha: 0.12);
    canvas.drawRRect(rrect, bgPaint);

    // Fill from bottom
    final fillHeight = size.height * fraction;
    final fillTop = size.height - fillHeight;
    final fillRect = Rect.fromLTWH(0, fillTop, size.width, fillHeight);
    final fillRRect = RRect.fromRectAndRadius(fillRect, radius);

    final fillPaint = Paint()..color = color;
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(fillRRect, fillPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FillGaugePainter old) =>
      old.fraction != fraction || old.color != color;
}

// ── DotsViz ───────────────────────────────────────────────────────────────────

/// 7-day dot row. Used by: Mood, Energy, Stress.
///
/// Each dot's opacity = values[i]. Today's dot is slightly larger.
class DotsViz extends StatelessWidget {
  const DotsViz({
    super.key,
    required this.data,
    required this.categoryColor,
  });

  final DotsData data;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final values = data.values;
    final count = values.length;
    final todayIndex = count - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(count, (i) {
            final isToday = i == todayIndex;
            final size = isToday ? 10.0 : 8.0;
            final opacity = values[i].clamp(0.0, 1.0);
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: categoryColor.withValues(alpha: opacity),
              ),
            );
          }),
        ),
        if (data.todayLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            data.todayLabel!,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

// ── CountBadgeViz ─────────────────────────────────────────────────────────────

/// Large count with last workout metadata. Used by: Workouts.
class CountBadgeViz extends StatelessWidget {
  const CountBadgeViz({super.key, required this.data});

  final CountBadgeData data;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${data.count}',
            style: AppTextStyles.displayLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (data.lastWorkoutType != null ||
              data.lastWorkoutDuration != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (data.lastWorkoutType != null) data.lastWorkoutType!,
                if (data.lastWorkoutDuration != null) data.lastWorkoutDuration!,
              ].join(' · '),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── CalendarDotsViz ───────────────────────────────────────────────────────────

/// Cycle day + phase label + dot row. Used by: Cycle.
class CalendarDotsViz extends StatelessWidget {
  const CalendarDotsViz({super.key, required this.data});

  final CalendarDotsData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${data.cycleDay}',
          style: AppTextStyles.displaySmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          data.phaseLabel,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: data.dotStates.map((filled) {
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? AppColors.categoryCycle
                    : AppColors.categoryCycle.withValues(alpha: 0.2),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── EnvironmentViz ────────────────────────────────────────────────────────────

/// AQI + UV display. Used by: Environment.
///
/// AQI color: green ≤50, yellow 51–100, orange 101–150, red >150.
class EnvironmentViz extends StatelessWidget {
  const EnvironmentViz({super.key, required this.data});

  final EnvironmentData data;

  static Color _aqiColor(int aqi) {
    if (aqi <= 50) return AppColors.statusConnected;    // green
    if (aqi <= 100) return AppColors.categoryMobility;  // yellow 0xFFFFD60A
    if (aqi <= 150) return AppColors.categoryNutrition; // orange 0xFFFF9F0A
    return AppColors.statusError;                       // red
  }

  @override
  Widget build(BuildContext context) {
    final aqiColor = _aqiColor(data.aqiValue);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AQI row
        _EnvRow(
          valueText: '${data.aqiValue}',
          label: data.aqiLabel,
          prefix: 'AQI',
          valueColor: aqiColor,
        ),
        const SizedBox(height: 8),
        // UV row
        _EnvRow(
          valueText: '${data.uvIndex}',
          label: data.uvLabel,
          prefix: 'UV',
          valueColor: AppColors.textTertiary,
        ),
      ],
    );
  }
}

class _EnvRow extends StatelessWidget {
  const _EnvRow({
    required this.valueText,
    required this.label,
    required this.prefix,
    required this.valueColor,
  });

  final String valueText;
  final String label;
  final String prefix;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          prefix,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          valueText,
          style: AppTextStyles.displaySmall.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── _DeltaBadge ───────────────────────────────────────────────────────────────

/// Small delta indicator used by LineChartViz and AreaChartViz.
///
/// [positiveIsGood] controls color semantics (default `true`).
/// Set to `false` for metrics where lower is better (e.g. weight, stress,
/// resting HR) so that a negative delta renders green and positive renders red.
class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({
    required this.delta,
    this.unit,
    this.positiveIsGood = true,
  });

  final double delta;
  final String? unit;

  /// When `true` (default), a positive delta is colored green (good) and
  /// negative is red (bad). When `false`, the semantics are inverted —
  /// a negative delta is green (good) and positive is red (bad).
  final bool positiveIsGood;

  @override
  Widget build(BuildContext context) {
    final isPositive = delta >= 0;
    // Invert color semantics when positiveIsGood=false (e.g. weight, stress).
    final isGood = positiveIsGood ? isPositive : !isPositive;
    final arrow = isPositive ? '↑' : '↓';
    final color = isGood ? AppColors.statusConnected : AppColors.statusError;
    final unitStr = unit != null ? ' ${unit!}' : '';
    final abs = delta.abs();
    final valueStr =
        abs == abs.roundToDouble() ? abs.toInt().toString() : abs.toStringAsFixed(1);

    return Text(
      '$arrow $valueStr$unitStr',
      style: AppTextStyles.labelSmall.copyWith(color: color),
    );
  }
}
