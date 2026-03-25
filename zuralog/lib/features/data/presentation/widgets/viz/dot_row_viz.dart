library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class DotRowViz extends StatelessWidget {
  const DotRowViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final DotRowConfig config;
  final Color color;
  final TileSize size;

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      TileSize.square => _buildSquare(),
      TileSize.wide   => _buildWide(),
      TileSize.tall   => _buildTall(),
    };
  }

  Widget _buildDot(DotPoint point, bool isToday) {
    final opacity = config.invertedScale ? (1 - point.value).clamp(0.1, 1.0) : point.value.clamp(0.1, 1.0);
    final dotSize = isToday ? 12.0 : 9.0;
    return Container(
      key: const Key('dot_row_dot'),
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        shape: BoxShape.circle,
        boxShadow: isToday ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4, spreadRadius: 1)] : null,
      ),
    );
  }

  Widget _buildSquare() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < config.points.length; i++)
              SizedBox(
                child: _buildDot(config.points[i], i == config.points.length - 1),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWide() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < config.points.length; i++)
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDot(config.points[i], i == config.points.length - 1),
                    if (config.points[i].emoji != null) ...[
                      const SizedBox(height: 2),
                      Text(config.points[i].emoji!, style: const TextStyle(fontSize: 9)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTall() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < config.points.length; i++)
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDot(config.points[i], i == config.points.length - 1),
                    const SizedBox(height: 2),
                    Text(
                      config.points[i].label ?? '${i + 1}',
                      style: const TextStyle(fontSize: 7),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
