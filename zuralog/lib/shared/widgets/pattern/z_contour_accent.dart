/// Zuralog Design System — Single Drifting Contour Accent.
///
/// Renders a horizontal band of three thin sage contour strokes that
/// drift slowly on a 20-second loop. The brand's topographic pattern
/// used as a *signature*, never as a wallpaper.
///
/// ## Usage
///
/// ```dart
/// const SizedBox(
///   width: 300,
///   height: 90,
///   child: ZContourAccent(),
/// )
/// ```
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';

/// A horizontal band of drifting sage contour strokes.
class ZContourAccent extends StatefulWidget {
  const ZContourAccent({
    super.key,
    this.animate = true,
    this.opacity = 0.18,
  });

  /// When false, the contour holds still. Reduced-motion callers pass false.
  final bool animate;

  /// Stroke opacity. Defaults to 0.18 — a barely-there signature.
  final double opacity;

  @override
  State<ZContourAccent> createState() => _ZContourAccentState();
}

class _ZContourAccentState extends State<ZContourAccent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    // Animation driven in didChangeDependencies — MediaQuery isn't safe
    // to read in initState.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final shouldAnimate = widget.animate && !reduceMotion;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColorsOf(context).primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ContourPainter(
            phase: _controller.value,
            opacity: widget.opacity,
            color: color,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ContourPainter extends CustomPainter {
  _ContourPainter({
    required this.phase,
    required this.opacity,
    required this.color,
  });

  final double phase;
  final double opacity;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;

    // Three stacked sinusoidal strokes, each with a different phase so the
    // band feels alive without looking repetitive.
    for (var i = 0; i < 3; i++) {
      final yBase = size.height * (0.35 + i * 0.22);
      final drift = phase * size.width + i * 60.0;
      final path = Path()..moveTo(-20, yBase);
      for (var x = -20.0; x <= size.width + 20; x += 6) {
        final y = yBase +
            14.0 *
                (i.isEven ? 1 : -1) *
                math.sin((x + drift) / 90.0 + i * 1.3);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ContourPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.opacity != opacity ||
      oldDelegate.color != color;
}
