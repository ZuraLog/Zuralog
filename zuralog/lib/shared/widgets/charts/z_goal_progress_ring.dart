/// Concentric goal progress ring used by Activity (and future categories).
///
/// Renders one or two ring arcs — an outer ring painted over a tinted
/// background track, and an optional inner ring offset 28pt inward.
/// The center of the card can display a big value + small label.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// A filled arc over a tinted ring, optionally with a second inner ring.
///
/// Behaviour:
/// - Outer fill sweeps from the top (−π/2) clockwise by
///   `(value / goal).clamp(0, 1) * 2π`.
/// - `goal <= 0` renders an empty ring (no fill).
/// - `value > goal` caps the fill at a full circle — no overshoot.
/// - If [innerValue] and [innerGoal] are provided, a second ring is
///   painted 28pt inside the outer ring with [innerColor] (defaulting to
///   a slightly desaturated variant of [color]).
/// - [centerValue] + [centerLabel] are rendered stacked in the middle.
///
/// Animation: the painter itself is static. Callers should wrap the
/// widget in their own stagger/fade animation (e.g. `ZFadeSlideIn`) if
/// they want motion.
class ZGoalProgressRing extends StatelessWidget {
  /// Creates a [ZGoalProgressRing].
  const ZGoalProgressRing({
    super.key,
    required this.value,
    required this.goal,
    required this.color,
    this.size = 180,
    this.strokeWidth = 14,
    this.centerValue,
    this.centerLabel,
    this.innerValue,
    this.innerGoal,
    this.innerColor,
    this.innerStrokeWidth = 10,
  });

  /// Current outer ring value (e.g. today's steps).
  final double value;

  /// Outer ring goal (e.g. 8000 step goal).
  final double goal;

  /// Outer ring accent colour. The background track is this colour at
  /// 18 % alpha; the fill arc uses the colour at full opacity.
  final Color color;

  /// Outer ring diameter in logical pixels.
  final double size;

  /// Outer stroke thickness.
  final double strokeWidth;

  /// Optional big number rendered in the centre (e.g. "8,420").
  final String? centerValue;

  /// Optional small label beneath [centerValue] (e.g. "steps").
  final String? centerLabel;

  /// Optional inner ring value. Both [innerValue] and [innerGoal] must
  /// be non-null for the inner ring to render.
  final double? innerValue;

  /// Optional inner ring goal.
  final double? innerGoal;

  /// Optional inner ring colour. Falls back to a 75 %-saturation variant
  /// of [color] when null.
  final Color? innerColor;

  /// Inner ring stroke thickness.
  final double innerStrokeWidth;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final hasInner = innerValue != null && innerGoal != null;
    final resolvedInnerColor = innerColor ?? _desaturate(color, 0.75);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _GoalRingPainter(
              value: value,
              goal: goal,
              color: color,
              strokeWidth: strokeWidth,
              // Inner ring is sized 28pt smaller — 14pt of inset each side.
              innerValue: hasInner ? innerValue : null,
              innerGoal: hasInner ? innerGoal : null,
              innerColor: hasInner ? resolvedInnerColor : null,
              innerStrokeWidth: innerStrokeWidth,
              innerInset: 14,
            ),
          ),
          // Centered value + label column.
          if (centerValue != null || centerLabel != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (centerValue != null)
                  Text(
                    centerValue!,
                    style: GoogleFonts.lora(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (centerLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    centerLabel!,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textTertiary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  /// Produces a softer variant of [base] by blending it with white at
  /// the given saturation fraction. 1.0 = original, 0.0 = fully white.
  static Color _desaturate(Color base, double saturation) {
    final clamped = saturation.clamp(0.0, 1.0);
    return Color.lerp(Colors.white, base, clamped) ?? base;
  }
}

/// Painter that draws the concentric rings + fill arcs.
class _GoalRingPainter extends CustomPainter {
  _GoalRingPainter({
    required this.value,
    required this.goal,
    required this.color,
    required this.strokeWidth,
    required this.innerValue,
    required this.innerGoal,
    required this.innerColor,
    required this.innerStrokeWidth,
    required this.innerInset,
  });

  final double value;
  final double goal;
  final Color color;
  final double strokeWidth;

  final double? innerValue;
  final double? innerGoal;
  final Color? innerColor;
  final double innerStrokeWidth;

  /// How many logical pixels the inner ring is inset from the outer
  /// ring's centre line. 14pt inset = 28pt smaller diameter.
  final double innerInset;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // ── Outer ring ──────────────────────────────────────────────────────────
    final outerRadius = (size.width / 2) - (strokeWidth / 2);
    _paintRing(
      canvas: canvas,
      center: center,
      radius: outerRadius,
      strokeWidth: strokeWidth,
      color: color,
      value: value,
      goal: goal,
    );

    // ── Inner ring ──────────────────────────────────────────────────────────
    if (innerValue != null && innerGoal != null && innerColor != null) {
      final innerRadius = outerRadius - innerInset - (innerStrokeWidth / 2);
      if (innerRadius > 0) {
        _paintRing(
          canvas: canvas,
          center: center,
          radius: innerRadius,
          strokeWidth: innerStrokeWidth,
          color: innerColor!,
          value: innerValue!,
          goal: innerGoal!,
        );
      }
    }
  }

  void _paintRing({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double strokeWidth,
    required Color color,
    required double value,
    required double goal,
  }) {
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withValues(alpha: 0.18)
      ..strokeCap = StrokeCap.round;

    // Background track — full circle at tinted colour.
    canvas.drawCircle(center, radius, trackPaint);

    if (goal <= 0 || value <= 0) return;

    final fraction = (value / goal).clamp(0.0, 1.0);
    final sweep = fraction * 2 * math.pi;

    // Fill arc — starts at top (−π/2) and sweeps clockwise.
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _GoalRingPainter old) {
    return old.value != value ||
        old.goal != goal ||
        old.color != color ||
        old.strokeWidth != strokeWidth ||
        old.innerValue != innerValue ||
        old.innerGoal != innerGoal ||
        old.innerColor != innerColor ||
        old.innerStrokeWidth != innerStrokeWidth ||
        old.innerInset != innerInset;
  }
}
