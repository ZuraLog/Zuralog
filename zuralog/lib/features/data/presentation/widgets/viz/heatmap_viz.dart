library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class HeatmapViz extends StatelessWidget {
  const HeatmapViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final HeatmapConfig config;
  final Color color;
  final TileSize size;

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      TileSize.square => const SizedBox.shrink(), // Not supported at square
      TileSize.wide   => _buildGrid(cellSize: 10),
      TileSize.tall   => _buildGrid(cellSize: 13),
    };
  }

  Widget _buildGrid({required double cellSize}) {
    if (config.cells.isEmpty) return const SizedBox.shrink();

    final maxVal = config.cells.map((c) => c.value).reduce((a, b) => a > b ? a : b);

    // Group cells by week (7 days per row)
    final weeks = <List<HeatmapCell>>[];
    for (var i = 0; i < config.cells.length; i += 7) {
      weeks.add(config.cells.sublist(i, (i + 7).clamp(0, config.cells.length)));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: weeks.map((week) => Row(
              children: week.map((cell) {
                final norm = maxVal > 0 ? cell.value / maxVal : 0.0;
                final cellColor = Color.lerp(config.colorLow, config.colorHigh, norm)!;
                return Container(
                  width: cellSize,
                  height: cellSize,
                  margin: const EdgeInsets.all(0.5),
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              }).toList(),
            )).toList(),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(config.legendLabel, style: const TextStyle(fontSize: 7)),
            const SizedBox(height: 2),
            ...List.generate(5, (i) {
              final t = i / 4.0;
              return Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(bottom: 1),
                color: Color.lerp(config.colorHigh, config.colorLow, t),
              );
            }),
          ],
        ),
      ],
    );
  }
}
