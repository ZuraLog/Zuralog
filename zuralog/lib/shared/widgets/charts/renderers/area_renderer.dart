library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';

/// Renders an area chart (filled line chart) driven by [AreaChartConfig].
///
/// Delegates all mode-specific decisions (stroke width, curved lines, dot
/// visibility, animation timing) to the supplied [ChartRenderContext].
class AreaRenderer extends StatelessWidget {
  const AreaRenderer({
    super.key,
    required this.config,
    required this.color,
    required this.renderCtx,
  });

  final AreaChartConfig config;
  final Color color;
  final ChartRenderContext renderCtx;

  @override
  Widget build(BuildContext context) {
    if (config.points.isEmpty) return const SizedBox.shrink();

    var points = config.points;
    if (points.length > 100) {
      final step = (points.length / 100).ceil();
      points = [for (var i = 0; i < points.length; i += step) points[i], points.last];
    }

    final lastIndex = points.length - 1;
    final progress = renderCtx.animationProgress;

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), (points[i].value.isFinite ? points[i].value : 0.0) * progress),
    ];

    final lineBarData = LineChartBarData(
      spots: spots,
      color: color,
      barWidth: renderCtx.strokeWidth,
      isCurved: renderCtx.isCurved,
      preventCurveOverShooting: renderCtx.preventCurveOverShooting,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: renderCtx.showDots,
        checkToShowDot: (spot, barData) => spot.x.toInt() == lastIndex,
        getDotPainter: (spot, percent, barData, index) =>
            FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: config.fillOpacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );

    final chartData = LineChartData(
      lineBarsData: [lineBarData],
      gridData: FlGridData(
        show: renderCtx.showGrid,
        drawVerticalLine: false,
        horizontalInterval: null,
        getDrawingHorizontalLine: (value) => FlLine(
          color: AppColors.warmWhite.withValues(alpha: 0.04),
          strokeWidth: 0.5,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      clipData: const FlClipData.all(),
      extraLinesData: config.targetLine != null
          ? ExtraLinesData(horizontalLines: [
              HorizontalLine(
                y: config.targetLine!,
                color: color.withValues(alpha: 0.5),
                strokeWidth: 0.75,
                dashArray: [4, 3],
              ),
            ])
          : const ExtraLinesData(),
    );

    return Stack(
      children: [
        LineChart(
          chartData,
          duration: renderCtx.flChartDuration,
          curve: Curves.easeOut,
        ),
        if (config.delta != null)
          Positioned(
            top: 4,
            right: 4,
            child: DeltaBadge(
              delta: config.delta!,
              positiveIsUp: config.positiveIsUp,
            ),
          ),
      ],
    );
  }
}

/// A small badge showing a percentage change with an up/down arrow.
///
/// Displays green for "good" changes and dark accent for "bad" changes,
/// where "good" depends on whether higher values are desirable
/// ([positiveIsUp]).
class DeltaBadge extends StatelessWidget {
  const DeltaBadge({
    super.key,
    required this.delta,
    required this.positiveIsUp,
  });

  final double delta;
  final bool positiveIsUp;

  @override
  Widget build(BuildContext context) {
    final isPositive = delta >= 0;
    final isGood = positiveIsUp ? isPositive : !isPositive;
    final badgeColor =
        isGood ? AppColors.categoryActivity : AppColors.categoryHeart;
    final arrow = isPositive ? '\u25B2' : '\u25BC';
    final pct = '$arrow ${(delta.abs() * 100).toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        pct,
        style: AppTextStyles.labelSmall.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
