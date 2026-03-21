library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class StatCardViz extends StatelessWidget {
  const StatCardViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final StatCardConfig config;
  final Color color;
  final TileSize size;

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      TileSize.square => _Square(config: config, color: color),
      TileSize.wide   => _Wide(config: config, color: color),
      TileSize.tall   => _Tall(config: config, color: color),
    };
  }
}

class _Square extends StatelessWidget {
  const _Square({required this.config, required this.color});
  final StatCardConfig config;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          config.value,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
        ),
        Text(config.unit, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        if (config.statusLabel != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: config.statusColor ?? color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(config.statusLabel!, style: const TextStyle(fontSize: 9)),
          ]),
        ],
      ],
    );
  }
}

class _Wide extends StatelessWidget {
  const _Wide({required this.config, required this.color});
  final StatCardConfig config;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                config.value,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
              ),
              Text(config.unit, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
            ],
          ),
        ),
        if (config.secondaryValue != null || config.statusLabel != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (config.statusLabel != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(color: config.statusColor ?? color, shape: BoxShape.circle),
                  ),
                  Text(config.statusLabel!, style: const TextStyle(fontSize: 9)),
                ]),
              if (config.secondaryValue != null)
                Text(config.secondaryValue!, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
              if (config.trendNote != null)
                Text(config.trendNote!, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
            ],
          ),
      ],
    );
  }
}

class _Tall extends StatelessWidget {
  const _Tall({required this.config, required this.color});
  final StatCardConfig config;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          config.value,
          style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: color),
        ),
        Text(config.unit, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        if (config.statusLabel != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: config.statusColor ?? color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(config.statusLabel!, style: const TextStyle(fontSize: 9)),
          ]),
        ],
        if (config.trendNote != null) ...[
          const SizedBox(height: 4),
          Text(config.trendNote!, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        ],
        if (config.secondaryValue != null) ...[
          const SizedBox(height: 4),
          Text(config.secondaryValue!, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
        ],
      ],
    );
  }
}
