library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class RingViz extends StatelessWidget {
  const RingViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final RingConfig config;
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

  String get _pct => '${(config.value / config.maxValue * 100).round()}%';

  Widget _buildRing(double diameter) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: (config.value / config.maxValue).clamp(0.0, 1.0),
            color: color,
            backgroundColor: color.withOpacity(0.15),
            strokeWidth: diameter * 0.12,
            strokeCap: StrokeCap.round,
          ),
          Text(_pct, style: TextStyle(fontSize: diameter * 0.2, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSquare() => Center(child: _buildRing(80));

  Widget _buildWide() {
    return Row(
      children: [
        _buildRing(90),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${config.value.round()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('/ ${config.maxValue.round()} ${config.unit}', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
              Text('${(config.maxValue - config.value).round()} remaining', style: TextStyle(fontSize: 9, color: Colors.grey[500])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTall() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRing(110),
        if (config.weeklyBars != null) ...[
          const SizedBox(height: 8),
          _BarRow(bars: config.weeklyBars!, color: color),
        ],
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.bars, required this.color});
  final List<BarPoint> bars;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
                    color: bar.isToday ? color : color.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 2),
                Text(bar.label, style: const TextStyle(fontSize: 7)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
