library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/presentation/widgets/streak_week_calendar_row.dart';
import 'package:zuralog/features/progress/presentation/widgets/pattern_fill.dart';

class StreakFlameHero extends StatelessWidget {
  const StreakFlameHero({
    super.key,
    required this.currentCount,
    required this.longestCount,
    required this.weekHits,
    required this.todayIndex,
    this.isFrozen = false,
  });

  final int currentCount;
  final int longestCount;
  final List<bool> weekHits;
  final int todayIndex;
  final bool isFrozen;

  @override
  Widget build(BuildContext context) {
    final isRecord = currentCount > 0 && currentCount >= longestCount;
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.progressSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: AppColors.progressBorderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.progressStreakWarm.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    isFrozen ? '🧊' : '🔥',
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PatternFill(
                      child: Text(
                        '$currentCount',
                        style: AppTextStyles.displayLarge.copyWith(
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                    Text(
                      'day streak',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.progressStreakWarm,
                        letterSpacing: 0.44,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isRecord) ...[
                      const SizedBox(height: 2),
                      Text(
                        '🎉 Personal best!',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.progressTextMuted,
                        ),
                      ),
                    ] else if (longestCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Best: $longestCount days',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.progressTextMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          StreakWeekCalendarRow(hits: weekHits, todayIndex: todayIndex),
        ],
      ),
    );
  }
}
