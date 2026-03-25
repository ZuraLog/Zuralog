library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class GaugeViz extends StatelessWidget {
  const GaugeViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final GaugeConfig config;
  final Color color;
  final TileSize size;

  String get _currentZoneLabel {
    for (final zone in config.zones) {
      if (config.value >= zone.min && config.value <= zone.max) return zone.label;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final gaugeSize = switch (size) {
      TileSize.square => 80.0,
      TileSize.wide   => 110.0,
      TileSize.tall   => 120.0,
    };

    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: gaugeSize,
            height: gaugeSize / 2 + 20,
            child: CustomPaint(
              painter: _GaugePainter(config: config, color: color),
            ),
          ),
          Text(
            '${config.value}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            _currentZoneLabel,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondaryDark),
          ),
          if (size == TileSize.tall) ...[
            const SizedBox(height: 8),
            ...config.zones.map((z) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: z.color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('${z.label}: ${z.min}–${z.max}', style: const TextStyle(fontSize: 8)),
                ],
              ),
            )),
          ],
        ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.config, required this.color});
  final GaugeConfig config;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 16);
    final radius = size.width / 2 - 4;
    final range = config.maxValue - config.minValue;

    // Draw zone arcs
    for (final zone in config.zones) {
      final startAngle = math.pi + math.pi * (zone.min - config.minValue) / range;
      final sweepAngle = math.pi * (zone.max - zone.min) / range;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = zone.color.withValues(alpha: 0.7)
          ..strokeWidth = 10
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
    }

    // Draw needle/filled arc to current value
    final valueAngle = math.pi * (config.value - config.minValue) / range;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      math.pi,
      valueAngle,
      false,
      Paint()
        ..color = color
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
