/// Inline empty-state card shown when the user has no active goals.
///
/// Uses a dashed border to visually distinguish it from data-filled cards
/// and provides a clear call-to-action to create the first goal.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/presentation/widgets/pressable_card.dart';

class GoalsEmptyCard extends StatelessWidget {
  const GoalsEmptyCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      borderRadius: AppDimens.radiusCard,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.progressBorderStrong,
          radius: AppDimens.radiusCard.toDouble(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceLg,
          ),
          child: Row(
            children: [
              Container(
                width: AppDimens.iconContainerSm,
                height: AppDimens.iconContainerSm,
                decoration: BoxDecoration(
                  color: AppColors.progressSage.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  border: Border.all(
                    color: AppColors.progressSage.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.flag_rounded,
                    size: AppDimens.iconSm,
                    color: AppColors.progressSage,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set your first goal',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.progressTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Track your progress toward what matters most.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.progressTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceXs + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.progressSage.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimens.radiusButton),
                  border: Border.all(
                    color: AppColors.progressSage.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'Add Goal',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.progressSage,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _DashedBorderPainter ──────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    _drawDashedRRect(canvas, rect, paint, dashLength: 6, gapLength: 4);
  }

  void _drawDashedRRect(
    Canvas canvas,
    RRect rrect,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    double distance = 0;
    bool draw = true;
    while (distance < metrics.length) {
      final len = draw ? dashLength : gapLength;
      if (draw) {
        canvas.drawPath(
          metrics.extractPath(distance, distance + len),
          paint,
        );
      }
      distance += len;
      draw = !draw;
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
