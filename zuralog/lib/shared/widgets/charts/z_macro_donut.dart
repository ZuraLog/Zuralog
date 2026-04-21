/// Zuralog Design System — Macro Donut.
///
/// A three-segment donut chart used by the Nutrition category detail
/// screen to visualise today's macro split (Carbs / Protein / Fat).
///
/// Design decisions:
/// - Fixed palette matching the Nutrition brand (warm amber / coral /
///   pale gold). The category color passed in is only used for the
///   background track tint so this primitive feels part of the
///   Nutrition family while segments stay recognisable.
/// - Rounded stroke caps so short segments still read as rings.
/// - Clockwise sweep starting from the top (−π/2): Carbs → Protein → Fat.
/// - Center `centerValue` is rendered in Lora (serif) at 26pt to match
///   the hero and goal-ring conventions; `centerLabel` uses the
///   `labelSmall` + `textTertiary` combo.
/// - Legend is NOT drawn by this widget — callers build the legend so
///   the donut stays a pure chart primitive.
///
/// Empty-state handling is also the caller's responsibility. When
/// `proteinGrams + carbsGrams + fatGrams == 0` the donut still renders
/// (just the background track); callers should prefer to hide the
/// widget and show a friendly caption instead.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Fixed brand palette for macro segments. Kept at the library top level
/// so callers can use the same colours for their legend dots without
/// having to reach into widget internals.
///
/// Carbs — warm amber.
const Color kMacroCarbsColor = Color(0xFFFFB06A);

/// Protein — coral.
const Color kMacroProteinColor = Color(0xFFFF7E6E);

/// Fat — pale gold.
const Color kMacroFatColor = Color(0xFFFFD47F);

/// A three-segment donut chart for Nutrition macro breakdowns.
///
/// Renders, clockwise from the top:
///  1. Carbs  — [kMacroCarbsColor]
///  2. Protein — [kMacroProteinColor]
///  3. Fat — [kMacroFatColor]
///
/// When the macro total is zero, only the background track is painted
/// and the centre text (if any) is still shown.
class ZMacroDonut extends StatelessWidget {
  /// Creates a [ZMacroDonut].
  const ZMacroDonut({
    super.key,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.categoryColor,
    this.size = 180,
    this.strokeWidth = 22,
    this.centerValue,
    this.centerLabel,
  });

  /// Protein consumed today in grams.
  final double proteinGrams;

  /// Carbohydrates consumed today in grams.
  final double carbsGrams;

  /// Fat consumed today in grams.
  final double fatGrams;

  /// Nutrition category accent color. Used only for the background
  /// track tint — macro segments use their own fixed palette.
  final Color categoryColor;

  /// Outer donut diameter in logical pixels.
  final double size;

  /// Segment stroke thickness.
  final double strokeWidth;

  /// Optional big number rendered in the centre (e.g. "1,450").
  final String? centerValue;

  /// Optional small label beneath [centerValue] (e.g. "kcal today").
  final String? centerLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _MacroDonutPainter(
              carbsGrams: carbsGrams,
              proteinGrams: proteinGrams,
              fatGrams: fatGrams,
              trackColor: categoryColor.withValues(alpha: 0.08),
              strokeWidth: strokeWidth,
            ),
          ),
          if (centerValue != null || centerLabel != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (centerValue != null)
                  Text(
                    centerValue!,
                    style: GoogleFonts.lora(
                      fontSize: 26,
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
}

/// Painter that draws the background track and three macro arcs.
class _MacroDonutPainter extends CustomPainter {
  _MacroDonutPainter({
    required this.carbsGrams,
    required this.proteinGrams,
    required this.fatGrams,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double carbsGrams;
  final double proteinGrams;
  final double fatGrams;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    // Background track — full circle at the tinted category colour.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final total = _safe(carbsGrams) + _safe(proteinGrams) + _safe(fatGrams);
    if (total <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    // Small gap between segments in radians so rounded caps don't
    // overlap on adjacent segments. Scales with stroke so it reads
    // at every size.
    final gap = strokeWidth / radius * 0.15;

    var startAngle = -math.pi / 2;

    void drawSegment(double grams, Color color) {
      if (grams <= 0) return;
      final fraction = grams / total;
      // Subtract the gap from the sweep so the segment visually ends
      // before the next one begins. A single full-circle segment
      // (fraction == 1) keeps its full sweep — no gap needed.
      final sweep = fraction >= 0.999
          ? 2 * math.pi
          : math.max(0.0, fraction * 2 * math.pi - gap);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += fraction * 2 * math.pi;
    }

    // Clockwise: Carbs → Protein → Fat.
    drawSegment(carbsGrams, kMacroCarbsColor);
    drawSegment(proteinGrams, kMacroProteinColor);
    drawSegment(fatGrams, kMacroFatColor);
  }

  /// Clamps negative / NaN inputs to zero so bad data never flips the
  /// arc math into an unexpected direction.
  static double _safe(double v) {
    if (v.isNaN || v.isInfinite || v < 0) return 0;
    return v;
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter old) {
    return old.carbsGrams != carbsGrams ||
        old.proteinGrams != proteinGrams ||
        old.fatGrams != fatGrams ||
        old.trackColor != trackColor ||
        old.strokeWidth != strokeWidth;
  }
}
