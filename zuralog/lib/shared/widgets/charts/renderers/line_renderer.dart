library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';

/// Renders a single [LineChart] driven by [LineChartConfig] and
/// [ChartRenderContext].
///
/// This widget owns only the fl_chart rendering — no layout wrappers,
/// semantics, stats rows, or size switching. The mode shell provides those.
class LineRenderer extends StatelessWidget {
  const LineRenderer({
    super.key,
    required this.config,
    required this.color,
    required this.renderCtx,
  });

  final LineChartConfig config;
  final Color color;
  final ChartRenderContext renderCtx;

  @override
  Widget build(BuildContext context) {
    if (config.points.isEmpty) return const SizedBox.shrink();

    final progress = renderCtx.animationProgress;
    final spots = <FlSpot>[
      for (var i = 0; i < config.points.length; i++)
        FlSpot(i.toDouble(), config.points[i].value * progress),
    ];

    final lastIndex = config.points.length - 1;

    final lineBarData = LineChartBarData(
      spots: spots,
      color: color,
      barWidth: renderCtx.strokeWidth,
      isCurved: renderCtx.isCurved,
      preventCurveOverShooting: renderCtx.preventCurveOverShooting,
      dotData: FlDotData(
        show: renderCtx.showDots,
        checkToShowDot: (spot, barData) =>
            spot.x == lastIndex.toDouble(),
        getDotPainter: (spot, xPercentage, barData, index) =>
            FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeWidth: 0,
        ),
      ),
      belowBarData: BarAreaData(show: false),
    );

    final minY = renderCtx.minY ?? config.rangeMin;
    final maxY = renderCtx.maxY ?? config.rangeMax;

    return LineChart(
      LineChartData(
        lineBarsData: [lineBarData],
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        clipData: const FlClipData.all(),
        minY: minY,
        maxY: maxY,
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (config.referenceLine != null)
              HorizontalLine(
                y: config.referenceLine!,
                color: color.withValues(alpha: 0.4),
                strokeWidth: 0.75,
                dashArray: [4, 3],
              ),
          ],
        ),
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            if (config.rangeMin != null && config.rangeMax != null)
              HorizontalRangeAnnotation(
                y1: config.rangeMin!,
                y2: config.rangeMax!,
                color: color.withValues(alpha: 0.08),
              ),
          ],
        ),
      ),
      duration: renderCtx.flChartDuration,
      curve: Curves.easeOut,
    );
  }
}
