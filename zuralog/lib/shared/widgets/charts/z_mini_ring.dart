/// Zuralog Design System — Mini Progress Ring.
///
/// A small progress arc (default 36×36) used in compact stat rows
/// where a full [ZGoalProgressRing] would be too heavy. Renders only
/// the track + arc — caller stacks numeric labels around it.
///
/// Track uses the [color] at 18% alpha (matches [ZGoalProgressRing]
/// convention). Arc starts at 12 o'clock (−π/2) and sweeps clockwise
/// by `value * 2π`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class ZMiniRing extends StatelessWidget {
  const ZMiniRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 36,
    this.strokeWidth = 3,
  });

  /// Progress value 0..1 (clamped). Values <= 0 render an empty ring.
  final double value;

  /// Arc + track tint color.
  final Color color;

  /// Outer diameter in logical pixels.
  final double size;

  /// Stroke thickness in logical pixels.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MiniRingPainter(
          value: value.clamp(0.0, 1.0),
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  _MiniRingPainter({
    required this.value,
    required this.color,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withValues(alpha: 0.18)
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    if (value <= 0) return;

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi / 2, value * 2 * math.pi, false, fill);
  }

  @override
  bool shouldRepaint(covariant _MiniRingPainter old) =>
      old.value != value || old.color != color || old.strokeWidth != strokeWidth;
}
