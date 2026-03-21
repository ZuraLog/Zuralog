library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class SegmentedBarViz extends StatelessWidget {
  const SegmentedBarViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final SegmentedBarConfig config;
  final Color color;
  final TileSize size;

  double get _total => config.segments.fold(0, (s, seg) => s + seg.value);

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      TileSize.square => _buildSquare(),
      TileSize.wide   => _buildWide(),
      TileSize.tall   => _buildTall(),
    };
  }

  Widget _buildBar(double height) {
    final total = _total;
    if (total == 0) return SizedBox(height: height);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: config.segments.map((seg) => Expanded(
          flex: (seg.value / total * 1000).round(),
          child: Container(height: height, color: seg.color),
        )).toList(),
      ),
    );
  }

  Widget _buildSquare() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(config.totalLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _buildBar(10),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          children: config.segments.take(3).map((seg) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: seg.color, shape: BoxShape.circle)),
              const SizedBox(width: 2),
              Text(seg.label, style: const TextStyle(fontSize: 7)),
            ],
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildWide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(config.totalLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        _buildBar(16),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: config.segments.map((seg) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: seg.color, shape: BoxShape.circle)),
              const SizedBox(height: 2),
              Text(seg.label, style: const TextStyle(fontSize: 7)),
              Text(_fmtMins(seg.value.round()), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold)),
            ],
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildTall() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        Text(config.totalLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        _buildBar(16),
        const SizedBox(height: 8),
        ...config.segments.map((seg) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: seg.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text(seg.label, style: const TextStyle(fontSize: 9))),
              Text(_fmtMins(seg.value.round()), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
        )),
      ],
    );
  }

  String _fmtMins(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}
