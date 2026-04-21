/// Mind-shard dot-scatter chart. Three columns (mood / energy / stress),
/// four dots per column. The bigger filled dot is today's reading; the
/// others are small dim guides. Stress is inverted — a big dot at the
/// BOTTOM means low stress (good).
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';

class ZMoodEnergyStressDots extends StatelessWidget {
  const ZMoodEnergyStressDots({
    super.key,
    required this.mood,
    required this.energy,
    required this.stress,
    this.color = AppColors.categoryWellness,
  });

  /// 1–10 scale. Null = no reading today.
  final int? mood;

  /// 1–10 scale. Null = no reading today.
  final int? energy;

  /// 1–10 scale, INVERTED (low stress is good). Null = no reading today.
  final int? stress;

  /// Base color for all dots. Defaults to the Wellness (Mind) category.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return AspectRatio(
      aspectRatio: 84 / 56,
      child: CustomPaint(
        painter: _DotsPainter(
          mood: mood,
          energy: energy,
          stress: stress,
          color: color,
          labelColor: colors.textSecondary,
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({
    required this.mood,
    required this.energy,
    required this.stress,
    required this.color,
    required this.labelColor,
  });

  final int? mood;
  final int? energy;
  final int? stress;
  final Color color;
  final Color labelColor;

  // Layout is defined in a 84×56 viewport; we scale to the actual size.
  static const double _vpW = 84;
  static const double _vpH = 56;

  // Column x positions in the viewport.
  static const List<double> _columnX = [14, 42, 70];

  // Dot y positions in the viewport — top of column (index 0) to bottom
  // (index 3).
  static const List<double> _dotY = [16, 26, 36, 46];

  static const List<String> _labels = ['mood', 'energy', 'stress'];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _vpW;
    final sy = size.height / _vpH;

    final activeIndices = [
      _yIndex(mood),
      _yIndex(energy),
      _yIndex(stress, inverted: true),
    ];

    for (var c = 0; c < 3; c++) {
      final cx = _columnX[c] * sx;
      for (var r = 0; r < 4; r++) {
        final cy = _dotY[r] * sy;
        final isActive = activeIndices[c] == r;
        final radius = (isActive ? 3.5 : 2.0) * ((sx + sy) / 2);
        final opacity = isActive ? 1.0 : 0.25;
        canvas.drawCircle(
          Offset(cx, cy),
          radius,
          Paint()..color = color.withValues(alpha: opacity),
        );
      }
      _drawLabel(canvas, cx, 55 * sy, _labels[c]);
    }
  }

  void _drawLabel(Canvas canvas, double cx, double y, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 6),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, y - tp.height / 2));
  }

  /// Map a 1–10 value to a dot index 0..3 (top=high). Inverted metrics
  /// (stress) are mirrored so that the visual "big dot near the bottom"
  /// matches "low value = good".
  static int _yIndex(int? v, {bool inverted = false}) {
    if (v == null) return -1;
    final clamped = v.clamp(1, 10);
    final idx = ((10 - clamped) / 3).floor().clamp(0, 3);
    return inverted ? (3 - idx) : idx;
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) =>
      old.mood != mood ||
      old.energy != energy ||
      old.stress != stress ||
      old.color != color ||
      old.labelColor != labelColor;
}
