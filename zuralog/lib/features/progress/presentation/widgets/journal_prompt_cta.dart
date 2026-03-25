library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/presentation/widgets/pressable_card.dart';

class JournalPromptCta extends StatelessWidget {
  const JournalPromptCta({super.key, required this.onTap});
  final VoidCallback onTap;

  static const _prompts = [
    'How did this week feel to you?',
    'What are you proud of this week?',
    'What would you do differently?',
    'What energized you most?',
  ];

  @override
  Widget build(BuildContext context) {
    final week = DateTime.now().weekOfYear;
    final prompt = _prompts[week % _prompts.length];

    return PressableCard(
      onTap: onTap,
      borderRadius: AppDimens.radiusCard,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.progressBorderStrong,
          radius: AppDimens.radiusCard.toDouble(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Row(
            children: [
              const Text('✍️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Text(
                  '"$prompt"',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.progressTextSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.progressSurfaceRaised,
                  borderRadius: BorderRadius.circular(AppDimens.radiusButton),
                  border: Border.all(color: AppColors.progressBorderStrong),
                ),
                child: Text(
                  'Write',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.progressTextSecondary,
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

extension on DateTime {
  int get weekOfYear {
    final firstDayOfYear = DateTime(year, 1, 1);
    final diff = difference(firstDayOfYear).inDays;
    return ((diff + firstDayOfYear.weekday - 1) / 7).floor() + 1;
  }
}
