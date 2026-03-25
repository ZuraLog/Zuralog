library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class StreakHeatmapCard extends StatelessWidget {
  const StreakHeatmapCard({
    super.key,
    required this.streakName,
    required this.freezeCount,
    required this.history,
    this.onFreezeTap,
    this.historyStartDate,
  });

  final String streakName;
  final int freezeCount;
  final List<bool> history;
  final VoidCallback? onFreezeTap;

  /// ISO-8601 date (YYYY-MM-DD) before which data is unavailable.
  /// Dots before this date are rendered as faded placeholders.
  final String? historyStartDate;

  @override
  Widget build(BuildContext context) {
    // freeze_count is tokens *available* (0–2), not tokens used.
    final freezesLeft = freezeCount.clamp(0, 2);
    final canFreeze = freezesLeft > 0;

    DateTime? startDate;
    if (historyStartDate != null) {
      try {
        startDate = DateTime.parse(historyStartDate!);
      } catch (_) {
        startDate = null;
      }
    }

    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.progressSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: AppColors.progressBorderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  streakName,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.progressTextPrimary,
                  ),
                ),
              ),
              Opacity(
                opacity: canFreeze ? 1.0 : 0.35,
                child: GestureDetector(
                  onTap: canFreeze ? onFreezeTap : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceSm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: canFreeze
                          ? AppColors.progressBorderDefault
                          : AppColors.progressBorderDefault.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppDimens.radiusButton),
                    ),
                    child: Text(
                      'Freeze: $freezesLeft left',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: canFreeze
                            ? AppColors.progressTextSecondary
                            : AppColors.progressTextMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(14, (i) {
              final isActive = i < history.length && history[i];
              final isToday = i == 13;

              // Determine if this dot is before the history start date
              final dotDate = today.subtract(Duration(days: 13 - i));
              final isPreHistory = startDate != null &&
                  dotDate.isBefore(DateTime(startDate.year, startDate.month, startDate.day));

              return _HeatmapDot(
                isActive: isActive,
                isToday: isToday,
                isPreHistory: isPreHistory,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _HeatmapDot extends StatelessWidget {
  const _HeatmapDot({
    required this.isActive,
    required this.isToday,
    this.isPreHistory = false,
  });
  final bool isActive;
  final bool isToday;
  final bool isPreHistory;

  @override
  Widget build(BuildContext context) {
    if (isPreHistory) {
      return Container(
        width: isToday ? 14 : 10,
        height: isToday ? 14 : 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.progressBorderDefault.withValues(alpha: 0.25),
        ),
      );
    }

    return Container(
      width: isToday ? 14 : 10,
      height: isToday ? 14 : 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.progressStreakWarm : Colors.transparent,
        border: Border.all(
          color: isActive
              ? AppColors.progressStreakWarm
              : (isToday
                  ? AppColors.progressStreakWarm.withValues(alpha: 0.5)
                  : AppColors.progressBorderStrong),
          width: isToday ? 2 : 1,
        ),
      ),
    );
  }
}
