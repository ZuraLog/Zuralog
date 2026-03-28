library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';

/// Renders a semicircular gauge arc with color zones and an animated needle.
///
/// This widget owns only the gauge painting — no value text, zone label,
/// or zone legend. The mode shell provides those.
class GaugeRenderer extends StatelessWidget {
  const GaugeRenderer({
    super.key,
    required this.config,
    required this.color,
    required this.renderCtx,
    required this.gaugeSize,
  });

  final GaugeConfig config;
  final Color color;
  final ChartRenderContext renderCtx;
  final double gaugeSize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GaugePainter(
        config: config,
        color: color,
        animationProgress: renderCtx.animationProgress,
      ),
      size: Size(gaugeSize, gaugeSize / 2),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.config,
    required this.color,
    required this.animationProgress,
  });

  final GaugeConfig config;
  final Color color;
  final double animationProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 16);
    final radius = size.width / 2 - 4;
    final range = config.maxValue - config.minValue;
    if (range == 0) return;

    // Draw zone arcs.
    for (final zone in config.zones) {
      final startAngle =
          math.pi + math.pi * (zone.min - config.minValue) / range;
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

    // Draw needle arc to current value, scaled by animation progress.
    final clampedValue = config.value.clamp(config.minValue, config.maxValue);
    final valueAngle = math.pi * (clampedValue - config.minValue) / range * animationProgress;
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
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.animationProgress != animationProgress ||
      oldDelegate.config != config ||
      oldDelegate.color != color;
}
