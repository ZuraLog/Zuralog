/// Zuralog Design System — BMI Gauge.
///
/// A semicircular BMI gauge used by the Body category detail screen. The
/// arc spans 180° (from π at the left to 0 at the right, sweeping
/// clockwise over the top) and is split into four coloured bands matching
/// WHO BMI cut-offs:
///
///   Underweight  (< 18.5)       — sky blue  (`0xFF64D2FF`)
///   Normal       (18.5 – 24.9)  — sage green (`0xFF30D158`)
///   Overweight   (25 – 29.9)    — amber      (`0xFFFFB06A`)
///   Obese        (≥ 30)         — deep red   (`0xFFE63946`)
///
/// A thin needle points from the centre to the arc at the angle
/// corresponding to the user's BMI. Under the semicircle, the big Lora
/// BMI number is rendered, followed by a small pill showing the band
/// label tinted with the band's colour.
///
/// Out-of-range values (below [minBmi] / above [maxBmi]) are clamped on
/// the needle but still shown accurately in the number + pill label.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Fixed band palette for BMI bands. Kept at the library top level so the
/// pill tint and the arc always stay in sync.
const Color _kBandUnderweight = Color(0xFF64D2FF); // sky blue
const Color _kBandNormal = Color(0xFF30D158); // sage green
const Color _kBandOverweight = Color(0xFFFFB06A); // amber
const Color _kBandObese = Color(0xFFE63946); // deep red

/// WHO BMI band cut-offs. Values at the boundary fall into the higher
/// band (e.g. 18.5 → Normal, 25 → Overweight, 30 → Obese).
const double _kNormalStart = 18.5;
const double _kOverweightStart = 25.0;
const double _kObeseStart = 30.0;

/// A semicircular BMI gauge with four coloured bands and a needle.
class ZBmiGauge extends StatelessWidget {
  /// Creates a [ZBmiGauge].
  const ZBmiGauge({
    super.key,
    required this.bmi,
    this.size = 200,
    this.strokeWidth = 18,
    this.minBmi = 14,
    this.maxBmi = 40,
  });

  /// The user's current BMI. Values outside `[minBmi, maxBmi]` clamp the
  /// needle angle but the number + pill label still reflect the raw value.
  final double bmi;

  /// Overall gauge width in logical pixels. Height is roughly half this
  /// plus space for the value text.
  final double size;

  /// Arc stroke thickness.
  final double strokeWidth;

  /// Lowest BMI represented by the arc (left end).
  final double minBmi;

  /// Highest BMI represented by the arc (right end).
  final double maxBmi;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final band = _bandFor(bmi);
    final bandColor = _bandColor(band);
    final bandLabel = _bandLabel(band);

    // Clamp the displayed BMI for the needle angle only — the number and
    // pill label still show the raw value.
    final clampedBmi = bmi.clamp(minBmi, maxBmi).toDouble();

    // Semicircle needs ~size/2 of vertical space for the arc itself, then
    // a small gap, the big number, and the pill.
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            // Add a small pad so the rounded caps & needle don't clip.
            height: size / 2 + strokeWidth,
            child: CustomPaint(
              size: Size(size, size / 2 + strokeWidth),
              painter: _BmiGaugePainter(
                bmi: clampedBmi,
                minBmi: minBmi,
                maxBmi: maxBmi,
                strokeWidth: strokeWidth,
                needleColor: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            _formatBmi(bmi),
            style: GoogleFonts.lora(
              fontSize: 34,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
              height: 1.1,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bandColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppDimens.radiusChip),
            ),
            child: Text(
              bandLabel,
              style: AppTextStyles.labelSmall.copyWith(
                color: bandColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatBmi(double v) {
    if (!v.isFinite) return '—';
    return v.toStringAsFixed(1);
  }

  static _BmiBand _bandFor(double v) {
    if (!v.isFinite) return _BmiBand.normal;
    if (v < _kNormalStart) return _BmiBand.underweight;
    if (v < _kOverweightStart) return _BmiBand.normal;
    if (v < _kObeseStart) return _BmiBand.overweight;
    return _BmiBand.obese;
  }

  static Color _bandColor(_BmiBand b) {
    switch (b) {
      case _BmiBand.underweight:
        return _kBandUnderweight;
      case _BmiBand.normal:
        return _kBandNormal;
      case _BmiBand.overweight:
        return _kBandOverweight;
      case _BmiBand.obese:
        return _kBandObese;
    }
  }

  static String _bandLabel(_BmiBand b) {
    switch (b) {
      case _BmiBand.underweight:
        return 'Underweight';
      case _BmiBand.normal:
        return 'Normal';
      case _BmiBand.overweight:
        return 'Overweight';
      case _BmiBand.obese:
        return 'Obese';
    }
  }
}

enum _BmiBand { underweight, normal, overweight, obese }

/// Painter for the four-band semicircular arc and the BMI needle.
class _BmiGaugePainter extends CustomPainter {
  _BmiGaugePainter({
    required this.bmi,
    required this.minBmi,
    required this.maxBmi,
    required this.strokeWidth,
    required this.needleColor,
  });

  /// BMI clamped to `[minBmi, maxBmi]`, used for needle positioning.
  final double bmi;
  final double minBmi;
  final double maxBmi;
  final double strokeWidth;
  final Color needleColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Arc geometry — centre at the bottom midpoint of the canvas, radius
    // sized to the smaller of half-width and (height - strokeWidth).
    final center = Offset(size.width / 2, size.height - strokeWidth / 2);
    final radius = math.min(
      size.width / 2 - strokeWidth / 2,
      size.height - strokeWidth,
    );
    if (radius <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // The full arc sweeps from π (left) clockwise by π (half circle) to 0
    // (right). The band boundaries are expressed as BMI values; convert
    // each to a sweep start/length in radians.
    const startAngle = math.pi;
    const totalSweep = math.pi;

    final range = maxBmi - minBmi;
    if (range <= 0) return;

    double bmiToAngle(double value) {
      final clamped = value.clamp(minBmi, maxBmi).toDouble();
      final fraction = (clamped - minBmi) / range;
      return startAngle + fraction * totalSweep;
    }

    // Draw each band as a stroked arc with rounded caps.
    void drawBand(double from, double to, Color color) {
      final a0 = bmiToAngle(from);
      final a1 = bmiToAngle(to);
      final sweep = a1 - a0;
      if (sweep <= 0) return;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, a0, sweep, false, paint);
    }

    drawBand(minBmi, _kNormalStart, _kBandUnderweight);
    drawBand(_kNormalStart, _kOverweightStart, _kBandNormal);
    drawBand(_kOverweightStart, _kObeseStart, _kBandOverweight);
    drawBand(_kObeseStart, maxBmi, _kBandObese);

    // Needle — straight line from centre to the point on the arc at the
    // user's BMI. Length is `radius - strokeWidth` so the tip sits just
    // inside the arc stroke, not on top of it.
    final needleAngle = bmiToAngle(bmi);
    final innerRadius = math.max(0.0, radius - strokeWidth);
    final tip = Offset(
      center.dx + innerRadius * math.cos(needleAngle),
      center.dy + innerRadius * math.sin(needleAngle),
    );

    final needlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = needleColor
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, needlePaint);

    // Small hub dot at the centre so the needle roots cleanly.
    final hubPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = needleColor;
    canvas.drawCircle(center, 3, hubPaint);
  }

  @override
  bool shouldRepaint(covariant _BmiGaugePainter old) {
    return old.bmi != bmi ||
        old.minBmi != minBmi ||
        old.maxBmi != maxBmi ||
        old.strokeWidth != strokeWidth ||
        old.needleColor != needleColor;
  }
}
