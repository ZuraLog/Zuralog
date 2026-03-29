library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/presentation/widgets/pressable_card.dart';

class JournalPromptCta extends StatelessWidget {
  const JournalPromptCta({
    super.key,
    required this.onTap,
    this.lastEntryDate,
    this.journalledToday = false,
  });

  final VoidCallback onTap;

  /// ISO-8601 date string of the most recent journal entry (e.g. "2026-03-24").
  /// Null when the user has never journalled.
  final String? lastEntryDate;

  /// True when the user has already logged a journal entry today.
  /// When true this widget renders nothing (returns [SizedBox.shrink]).
  final bool journalledToday;

  static const _prompts = [
    'How did this week feel to you?',
    'What are you proud of this week?',
    'What would you do differently?',
    'What energized you most?',
  ];

  String _buildPrompt() {
    if (lastEntryDate == null) return 'Start your journal — how are you feeling?';
    final week = DateTime.now().weekOfYear;
    return _prompts[week % _prompts.length];
  }

  String _buildSubLabel() {
    if (lastEntryDate == null) return 'First entry';
    final last = DateTime.tryParse(lastEntryDate!);
    if (last == null) return 'Log today';
    final diff = DateTime.now().difference(last).inDays;
    if (diff == 0) return 'Log today';
    if (diff == 1) return 'Yesterday';
    return '$diff days ago';
  }

  @override
  Widget build(BuildContext context) {
    if (journalledToday) return const SizedBox.shrink();

    final colors = AppColorsOf(context);
    final prompt = _buildPrompt();
    final subLabel = _buildSubLabel();

    return PressableCard(
      onTap: onTap,
      borderRadius: AppDimens.radiusCard,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: colors.progressBorderStrong,
          radius: AppDimens.radiusCard.toDouble(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Row(
            children: [
              const Icon(Icons.edit_rounded, size: 22, color: Color(0xFF4A7C3F)),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"$prompt"',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.progressTextSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: colors.progressTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.progressSurfaceRaised,
                  borderRadius: BorderRadius.circular(AppDimens.radiusButton),
                  border: Border.all(color: colors.progressBorderStrong),
                ),
                child: Text(
                  'Write',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: colors.progressTextSecondary,
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
