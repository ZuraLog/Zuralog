library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class BarChartViz extends StatelessWidget {
  const BarChartViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final BarChartConfig config;
  final Color color;
  final TileSize size;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const labelReserve = 14.0;
        double effectiveH(double preferred, bool labels) {
          if (constraints.maxHeight.isInfinite) return preferred;
          final cap = labels
              ? (constraints.maxHeight - labelReserve).clamp(2.0, constraints.maxHeight)
              : constraints.maxHeight;
          return cap < preferred ? cap : preferred;
        }

        return switch (size) {
          TileSize.square => _BarChart(
              bars: config.bars.length > 5
                  ? config.bars.sublist(config.bars.length - 5)
                  : config.bars,
              color: color,
              showLabels: false,
              barHeight: effectiveH(60, false),
            ),
          TileSize.wide => _BarChart(
              bars: config.bars,
              color: color,
              showLabels: true,
              barHeight: effectiveH(80, true),
            ),
          TileSize.tall => _BarChart(
              bars: config.bars,
              color: color,
              showLabels: true,
              barHeight: effectiveH(120, true),
            ),
        };
      },
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.bars, required this.color, required this.showLabels, required this.barHeight});
  final List<BarPoint> bars;
  final Color color;
  final bool showLabels;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();
    final maxVal = bars.map((b) => b.value).reduce((a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: bars.map((bar) {
        final h = maxVal > 0 ? barHeight * bar.value / maxVal : 0.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: const Key('bar_chart_bar'),
                  height: h.clamp(2.0, barHeight),
                  decoration: BoxDecoration(
                    color: bar.isToday ? color : color.withOpacity(0.3),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                  ),
                ),
                if (showLabels) ...[
                  const SizedBox(height: 2),
                  Text(bar.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 7)),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
