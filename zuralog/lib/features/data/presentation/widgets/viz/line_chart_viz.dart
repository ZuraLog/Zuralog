library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class LineChartViz extends StatelessWidget {
  const LineChartViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final LineChartConfig config;
  final Color color;
  final TileSize size;

  @override
  Widget build(BuildContext context) {
    if (config.points.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: 'Line chart with ${config.points.length} data points',
      child: switch (size) {
        TileSize.square => _buildChart(context),
        TileSize.wide   => _buildChart(context),
        TileSize.tall   => _buildTall(context),
      },
    );
  }

  Widget _buildChart(BuildContext context) {
    return SizedBox.expand(
      child: _lineChart(context),
    );
  }

  Widget _buildTall(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: _lineChart(context),
        ),
        _StatsRow(points: config.points, color: color),
      ],
    );
  }

  Widget _lineChart(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < config.points.length; i++)
        FlSpot(i.toDouble(), config.points[i].value),
    ];

    final lastIndex = config.points.length - 1;

    final lineBarData = LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 1.5,
      isCurved: false,
      dotData: FlDotData(
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

    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return LineChart(
      LineChartData(
        lineBarsData: [lineBarData],
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        minY: config.rangeMin,
        maxY: config.rangeMax,
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
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.points, required this.color});
  final List<ChartPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final values = points.map((p) => p.value).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final avg = values.reduce((a, b) => a + b) / values.length;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: 'MIN', value: min.round().toString(), color: color),
          _Stat(label: 'AVG', value: avg.round().toString(), color: color),
          _Stat(label: 'MAX', value: max.round().toString(), color: color),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.bold)),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColorsOf(context).textSecondary)),
      ],
    );
  }
}
