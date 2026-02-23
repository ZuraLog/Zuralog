/// Zuralog Dashboard — Activity Rings Widget.
///
/// Renders three concentric Apple Health-style arc rings using [CustomPainter].
/// The outer ring shows steps, the middle ring shows sleep, and the inner ring
/// shows calories burned. Below the rings a horizontal pill row summarises each
/// metric with its colour-coded value.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

// ── Data class ────────────────────────────────────────────────────────────────

/// Data required to render a single activity ring.
///
/// [value] is the current reading (e.g., 6 500 steps), [maxValue] is the daily
/// goal (e.g., 10 000 steps), and [color] is the ring's accent colour.
class RingData {
  /// Creates a [RingData] for one ring in [ActivityRings].
  const RingData({
    required this.value,
    required this.maxValue,
    required this.color,
    required this.label,
    required this.unit,
  });

  /// Current metric value (e.g., step count for today).
  final double value;

  /// Goal / maximum value used to compute the fill fraction.
  final double maxValue;

  /// Accent colour for the track and the filled arc.
  final Color color;

  /// Human-readable label (e.g., "Steps").
  final String label;

  /// Unit abbreviation displayed in the pill row (e.g., "steps", "hrs").
  final String unit;
}

// ── Widget ────────────────────────────────────────────────────────────────────

/// Three concentric activity rings with a summary pill row.
///
/// Expects exactly three [RingData] entries in [rings]:
/// - index 0 → outer ring (typically steps, sage green)
/// - index 1 → middle ring (typically sleep, slate)
/// - index 2 → inner ring (typically calories, coral)
///
/// Sized to [AppDimens.ringDiameter] × [AppDimens.ringDiameter].
class ActivityRings extends StatelessWidget {
  /// Creates an [ActivityRings] widget.
  ///
  /// [rings] must have exactly three entries.
  const ActivityRings({super.key, required this.rings})
      : assert(rings.length == 3, 'ActivityRings requires exactly 3 RingData entries.');

  /// The three rings to render, ordered outer → middle → inner.
  final List<RingData> rings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Rings + centred label ──────────────────────────────────────────
        SizedBox(
          width: AppDimens.ringDiameter,
          height: AppDimens.ringDiameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(AppDimens.ringDiameter, AppDimens.ringDiameter),
                painter: _RingsPainter(rings: rings),
              ),
              // Primary metric: value + label centred inside the inner ring.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatValue(rings[0].value, rings[0].unit),
                    style: AppTextStyles.h2.copyWith(
                      color: primaryTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    rings[0].label,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppDimens.spaceMd),

        // ── Pill row ──────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: rings.map((r) => _RingPill(ring: r)).toList(),
        ),
      ],
    );
  }

  /// Formats [value] for compact display.
  ///
  /// Values ≥ 1 000 use comma notation; float values are shown with one decimal
  /// place only if non-integer (e.g., 7.5 hrs). Pure integers drop the decimal.
  static String _formatValue(double value, String unit) {
    if (unit == 'hrs') {
      return value == value.floorToDouble()
          ? '${value.toInt()}'
          : value.toStringAsFixed(1);
    }
    final intValue = value.toInt();
    if (intValue >= 1000) {
      final thousands = intValue ~/ 1000;
      final remainder = intValue % 1000;
      return '$thousands,${remainder.toString().padLeft(3, '0')}';
    }
    return '$intValue';
  }
}

// ── Mini pill row item ────────────────────────────────────────────────────────

/// A single stat pill displayed below the rings.
///
/// Shows a coloured dot, the metric value+unit, and the label.
class _RingPill extends StatelessWidget {
  /// Creates a [_RingPill] for [ring].
  const _RingPill({required this.ring});

  /// Data for this pill.
  final RingData ring;

  @override
  Widget build(BuildContext context) {
    final valueText =
        '${ActivityRings._formatValue(ring.value, ring.unit)} ${ring.unit}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceXs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        border: Border.all(
          color: ring.color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Coloured dot
          Container(
            width: AppDimens.spaceXs + 2,
            height: AppDimens.spaceXs + 2,
            decoration: BoxDecoration(
              color: ring.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppDimens.spaceXs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                valueText,
                style: AppTextStyles.caption.copyWith(
                  color: ring.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ring.label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── CustomPainter ─────────────────────────────────────────────────────────────

/// Paints three concentric arc rings onto the canvas.
///
/// Ring layout (outside → in):
/// | Ring | Stroke | Gap before next |
/// |------|--------|-----------------|
/// | 0    | 18 px  | 10 px           |
/// | 1    | 16 px  | 10 px           |
/// | 2    | 14 px  | —               |
///
/// The start angle is at the 12 o'clock position (`-π/2`).
/// A minimum sweep of 0.05 rad ensures a visible dot even at 0 %.
class _RingsPainter extends CustomPainter {
  /// Creates a [_RingsPainter] with the given [rings].
  const _RingsPainter({required this.rings});

  /// Ring data ordered outer → middle → inner.
  final List<RingData> rings;

  // Stroke widths per ring tier.
  static const double _outerStroke = 18;
  static const double _middleStroke = 16;
  static const double _innerStroke = 14;

  // Gap between rings (centre-to-centre distance reduction).
  static const double _ringGap = 10;

  // Minimum visible arc angle (prevents a completely invisible 0 % ring).
  static const double _minSweep = 0.05;

  /// Returns stroke width for ring at [index].
  double _strokeFor(int index) {
    switch (index) {
      case 0:
        return _outerStroke;
      case 1:
        return _middleStroke;
      default:
        return _innerStroke;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Compute the outer-most available radius (leaving room for the outermost
    // stroke so arcs don't clip against the widget boundary).
    double currentRadius = size.width / 2 - _outerStroke / 2;

    for (int i = 0; i < rings.length; i++) {
      final ring = rings[i];
      final stroke = _strokeFor(i);

      final rect = Rect.fromCircle(center: center, radius: currentRadius);
      final fraction = (ring.value / ring.maxValue).clamp(0.0, 1.0);
      final sweepAngle = max(fraction * 2 * pi, _minSweep);

      // Track (background) arc — 12 % opacity of ring colour.
      final trackPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = ring.color.withValues(alpha: 0.12);

      canvas.drawArc(rect, -pi / 2, 2 * pi, false, trackPaint);

      // Foreground arc — full ring colour.
      final foregroundPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = ring.color;

      canvas.drawArc(rect, -pi / 2, sweepAngle, false, foregroundPaint);

      // Advance inward: half current stroke + gap + half next stroke.
      if (i < rings.length - 1) {
        final nextStroke = _strokeFor(i + 1);
        currentRadius -= stroke / 2 + _ringGap + nextStroke / 2;
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) {
    // Repaint only if ring data has changed.
    if (oldDelegate.rings.length != rings.length) return true;
    for (int i = 0; i < rings.length; i++) {
      final a = oldDelegate.rings[i];
      final b = rings[i];
      if (a.value != b.value ||
          a.maxValue != b.maxValue ||
          a.color != b.color) {
        return true;
      }
    }
    return false;
  }
}
