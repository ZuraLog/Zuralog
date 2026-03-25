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
    this.freezeCount = 0,
    this.onFreezeTap,
    this.nudgeMessage,
  });

  final int currentCount;
  final int longestCount;
  final List<bool> weekHits;
  final int todayIndex;
  final bool isFrozen;
  /// Number of streak-freeze tokens available. When > 0 a pill is shown.
  final int freezeCount;
  /// Called when the user taps the freeze pill. Typically opens the freeze dialog.
  final VoidCallback? onFreezeTap;
  /// Optional contextual message shown below the calendar row (e.g. for zero-data state).
  final String? nudgeMessage;

  @override
  Widget build(BuildContext context) {
    final isRecord = currentCount > 0 && currentCount >= longestCount;
    final clampedTodayIndex = todayIndex.clamp(0, 6);
    final todayDone = clampedTodayIndex < weekHits.length && weekHits[clampedTodayIndex];

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
                width: AppDimens.iconContainerLg,
                height: AppDimens.iconContainerLg,
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
                    Semantics(
                      label: '$currentCount day streak',
                      child: PatternFill(
                        child: Text(
                          '$currentCount',
                          style: AppTextStyles.displayLarge.copyWith(
                            color: Colors.white,
                            height: 1.0,
                          ),
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
          const SizedBox(height: 4),
          Text(
            todayDone ? 'Today: done' : 'Today: pending',
            style: AppTextStyles.labelSmall.copyWith(
              color: todayDone ? AppColors.progressSage : AppColors.progressTextMuted,
            ),
            textAlign: TextAlign.center,
          ),
          if (nudgeMessage != null) ...[
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              nudgeMessage!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.progressTextMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (freezeCount > 0) ...[
            const SizedBox(height: AppDimens.spaceMd),
            Semantics(
              label: 'Use streak freeze — $freezeCount remaining',
              button: true,
              child: GestureDetector(
                onTap: onFreezeTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                    vertical: AppDimens.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.categoryBody.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppDimens.radiusButton),
                    border: Border.all(
                      color: AppColors.categoryBody.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🧊', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: AppDimens.spaceXs),
                      Text(
                        '$freezeCount freeze token${freezeCount == 1 ? '' : 's'} available',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.categoryBody,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
