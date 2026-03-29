/// Zuralog — HealthScoreBuildingState widget.
///
/// Shown inside the Health Score hero card during Days 1–6 while the user
/// is building up enough data to unlock the full score.
///
/// Displays a partial ring in sage-green filled to [dataDays]/[targetDays],
/// a centred day counter (e.g. "4/7"), "Health Score" label, and
/// "X more days" subtitle.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── Constants ────────────────────────────────────────────────────────────────

/// Ring diameter — matches [HealthScoreWidget.hero] (120pt).
const double _kRingDiameter = 120.0;

/// Stroke width fraction — matches [HealthScoreWidget] (12% of diameter).
const double _kStrokeFraction = 0.12;

// ── HealthScoreBuildingState ─────────────────────────────────────────────────

/// Building-up placeholder for the Health Score hero card.
///
/// Shows a partial sage-green ring counting days towards the 7-day threshold.
class HealthScoreBuildingState extends StatelessWidget {
  /// Creates a [HealthScoreBuildingState].
  const HealthScoreBuildingState({
    super.key,
    required this.dataDays,
    this.targetDays = 7,
  });

  /// Number of days with recorded health data (1–6).
  final int dataDays;

  /// Threshold to unlock the full score. Defaults to 7.
  final int targetDays;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final remaining = (targetDays - dataDays).clamp(1, targetDays);
    final progress = (dataDays / targetDays).clamp(0.0, 1.0);
    final trackColor = colors.cardBackground.withValues(alpha: 0.3);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Partial ring with day counter.
        SizedBox(
          width: _kRingDiameter,
          height: _kRingDiameter,
          child: CustomPaint(
            painter: _BuildingRingPainter(
              progress: progress,
              ringColor: colors.primary,
              trackColor: trackColor,
              strokeWidth: _kRingDiameter * _kStrokeFraction,
            ),
            child: Center(
              child: Text(
                '$dataDays/$targetDays',
                style: AppTextStyles.displayMedium.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          'Health Score',
          style: AppTextStyles.labelMedium.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Text(
          '$remaining more ${remaining == 1 ? 'day' : 'days'}',
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── _BuildingRingPainter ─────────────────────────────────────────────────────

class _BuildingRingPainter extends CustomPainter {
  const _BuildingRingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2; // 12 o'clock

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Full track circle.
    canvas.drawCircle(center, radius, trackPaint);

    // Filled arc — progress portion.
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * math.pi * progress,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_BuildingRingPainter old) =>
      old.progress != progress ||
      old.ringColor != ringColor ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
