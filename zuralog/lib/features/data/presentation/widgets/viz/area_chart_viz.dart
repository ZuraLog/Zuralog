library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class AreaChartViz extends StatelessWidget {
  const AreaChartViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final AreaChartConfig config;
  final Color color;
  final TileSize size;

  @override
  Widget build(BuildContext context) {
    if (config.points.isEmpty) return const SizedBox.shrink();

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final lastIndex = config.points.length - 1;

    final spots = <FlSpot>[
      for (var i = 0; i < config.points.length; i++)
        FlSpot(i.toDouble(), config.points[i].value),
    ];

    final lineBarData = LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 1.5,
      isCurved: false,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, barData) =>
            spot.x.toInt() == lastIndex,
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
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
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

    return Semantics(
      label: 'Area chart with ${config.points.length} data points',
      child: Stack(
        children: [
          LineChart(
            chartData,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          ),
          if (config.delta != null)
            Positioned(
              top: 4,
              right: 4,
              child: _DeltaBadge(
                  delta: config.delta!, positiveIsUp: config.positiveIsUp),
            ),
        ],
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta, required this.positiveIsUp});
  final double delta;
  final bool positiveIsUp;

  @override
  Widget build(BuildContext context) {
    final isPositive = delta >= 0;
    final isGood = positiveIsUp ? isPositive : !isPositive;
    final badgeColor =
        isGood ? AppColors.categoryActivity : AppColors.accentDark;
    final arrow = isPositive ? '▲' : '▼';
    final pct = '$arrow ${(delta.abs() * 100).toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(pct,
          style: TextStyle(
              fontSize: 8, color: badgeColor, fontWeight: FontWeight.bold)),
    );
  }
}
