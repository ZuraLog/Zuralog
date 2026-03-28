library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';

/// Renders a donut-style [PieChart] driven by [RingConfig] and
/// [ChartRenderContext].
///
/// This widget is a pure rendering primitive — it does not wrap itself in
/// Semantics, size-switching logic, or entrance animation controllers. Those
/// concerns belong in the chart shell that hosts this renderer.
class RingRenderer extends StatelessWidget {
  const RingRenderer({
    super.key,
    required this.config,
    required this.color,
    required this.renderCtx,
    required this.diameter,
  });

  final RingConfig config;
  final Color color;
  final ChartRenderContext renderCtx;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final radius = diameter * 0.12;
    final centerSpaceRadius = diameter / 2 - radius;

    // Guard against division by zero.
    final maxValue = config.maxValue;
    final pct = maxValue > 0
        ? (config.value / maxValue * 100).round()
        : 0;

    // Apply entrance animation to the filled portion.
    final animatedValue =
        config.value.clamp(0.0, maxValue) * renderCtx.animationProgress;
    final empty = (maxValue - animatedValue).clamp(0.0, maxValue);

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 0,
              centerSpaceRadius: centerSpaceRadius,
              pieTouchData: PieTouchData(enabled: false),
              sections: [
                PieChartSectionData(
                  value: animatedValue,
                  color: color,
                  radius: radius,
                  showTitle: false,
                ),
                // Omit the empty section when the ring is fully filled.
                if (empty > 0)
                  PieChartSectionData(
                    value: empty,
                    color: color.withValues(alpha: 0.15),
                    radius: radius,
                    showTitle: false,
                  ),
              ],
            ),
            duration: renderCtx.flChartDuration,
            curve: Curves.easeOut,
          ),
          Text(
            '$pct%',
            style: AppTextStyles.labelLarge.copyWith(
              fontSize: diameter * 0.2,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a row of mini vertical bars — typically the 7-day weekly summary
/// shown below the ring in tall mode.
///
/// This widget is a pure rendering primitive — layout positioning is the
/// responsibility of the chart shell.
class RingBarRow extends StatelessWidget {
  const RingBarRow({
    super.key,
    required this.bars,
    required this.color,
  });

  final List<BarPoint> bars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();

    final colors = AppColorsOf(context);
    final maxVal = bars.map((b) => b.value).reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: bars.map((bar) {
        final h = maxVal > 0 ? 24.0 * bar.value / maxVal : 0.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: h.clamp(2.0, 24.0),
                  decoration: BoxDecoration(
                    color: bar.isToday ? color : color.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bar.label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
