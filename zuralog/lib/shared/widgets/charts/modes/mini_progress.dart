library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Controls whether [ZMiniProgress] renders as a circular ring or a
/// horizontal progress bar.
enum MiniProgressVariant { ring, linear }

/// Tiny goal-completion badge. Non-interactive — no [GestureDetector].
///
/// [value] and [goal] are raw numeric values in the same unit.
/// [size] is the diameter for the ring variant, ignored for linear.
/// [variant] defaults to [MiniProgressVariant.ring].
class ZMiniProgress extends StatelessWidget {
  const ZMiniProgress({
    super.key,
    required this.value,
    required this.goal,
    required this.color,
    this.variant = MiniProgressVariant.ring,
    this.size = 28,
  });

  final double value;
  final double goal;
  final Color color;
  final MiniProgressVariant variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final percentage = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    final label = '${(percentage * 100).round()}% of goal';

    return Semantics(
      label: label,
      child: switch (variant) {
        MiniProgressVariant.ring => SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(percentage: percentage, color: color),
            ),
          ),
        MiniProgressVariant.linear => _LinearVariant(
            percentage: percentage,
            color: color,
          ),
      },
    );
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  _RingPainter({required this.percentage, required this.color});

  final double percentage;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2;
    const strokeWidth = 3.0;

    // Track arc (full 360°, 15% opacity).
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Filled arc (clockwise from 12 o'clock = -π/2).
    if (percentage > 0) {
      final fillPaint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        -math.pi / 2,             // Start at 12 o'clock
        percentage * 2 * math.pi, // Sweep clockwise
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.percentage != percentage || old.color != color;
}

// ── Linear variant ────────────────────────────────────────────────────────────

class _LinearVariant extends StatelessWidget {
  const _LinearVariant({required this.percentage, required this.color});

  final double percentage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Track
            ColoredBox(color: color.withValues(alpha: 0.15)),
            // Fill
            FractionallySizedBox(
              widthFactor: percentage,
              alignment: Alignment.centerLeft,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
