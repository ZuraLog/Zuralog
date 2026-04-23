/// Zuralog — Onboarding BMR Card.
///
/// Dropped into the chat after basics (sex + age + height + weight) are
/// filled. A small surface card with a sage ring and one headline
/// number — the user's Basal Metabolic Rate. Shows the coach is already
/// doing math on what they shared.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class OnboardingBmrCard extends StatelessWidget {
  const OnboardingBmrCard({
    super.key,
    required this.bmrCalories,
  });

  /// The Basal Metabolic Rate in calories per day.
  final int bmrCalories;

  static const double _ringSize = 72;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(_ringSize, _ringSize),
            painter: _BmrRingPainter(
              progressColor: colors.primary,
              trackColor: colors.textPrimary.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RESTING ENERGY',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.textSecondary,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _formatThousands(bmrCalories),
                      style: AppTextStyles.displayMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'cal / day',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textSecondary,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _BmrRingPainter extends CustomPainter {
  _BmrRingPainter({
    required this.progressColor,
    required this.trackColor,
  });

  final Color progressColor;
  final Color trackColor;

  static const double _strokeWidth = 4.5;
  static const double _sweepFraction = 0.74;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - _strokeWidth;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    // Full track circle.
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc — 74% sweep to feel "strongly present" without being full.
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * _sweepFraction,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BmrRingPainter oldDelegate) =>
      oldDelegate.progressColor != progressColor ||
      oldDelegate.trackColor != trackColor;
}
