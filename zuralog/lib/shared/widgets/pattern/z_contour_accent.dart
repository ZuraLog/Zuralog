/// Zuralog Design System — Drifting Contour Accent Band.
///
/// Renders three thin sage contour strokes, stacked with offset phases,
/// drifting slowly on a 20-second loop. The brand's topographic pattern
/// used as a *signature*, never as a wallpaper.
///
/// The painter intentionally over-draws horizontally by 20 logical pixels
/// on each edge; wrap in a clipping parent (e.g. `ClipRect`) if edge
/// bleed would be visible against the surface underneath.
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

/// A band of three drifting sage contour strokes used as a brand signature.
class ZContourAccent extends StatefulWidget {
  const ZContourAccent({
    super.key,
    this.animate = true,
    this.opacity = 0.18,
  }) : assert(opacity >= 0 && opacity <= 1, 'opacity must be between 0 and 1');

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

  // Three contour lines at slightly different phases — enough variety to
  // feel alive, not enough to look busy.
  static const int _lineCount = 3;

  // Stroke weight in logical pixels — deliberately thin so it reads as a
  // signature accent, not a border.
  static const double _strokeWidth = 0.7;

  // Peak-to-peak amplitude of each sine line in logical pixels.
  static const double _amplitude = 14.0;

  // Wavelength of each sine in logical pixels.
  static const double _wavelength = 90.0;

  // Horizontal sampling step — 6px gives a visually smooth curve without
  // running the paint loop too hot.
  static const double _sampleStepPx = 6.0;

  // Phase offset per line so the three curves stay out of sync.
  static const double _phaseOffsetPerLine = 60.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < _lineCount; i++) {
      final yBase = size.height * (0.35 + i * 0.22);
      final drift = phase * size.width + i * _phaseOffsetPerLine;
      final path = Path()..moveTo(-20, yBase);
      for (var x = -20.0; x <= size.width + 20; x += _sampleStepPx) {
        final y = yBase +
            _amplitude *
                (i.isEven ? 1 : -1) *
                math.sin((x + drift) / _wavelength + i * 1.3);
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
