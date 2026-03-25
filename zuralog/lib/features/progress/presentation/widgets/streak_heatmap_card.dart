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
  });

  final String streakName;
  final int freezeCount;
  final List<bool> history;
  final VoidCallback? onFreezeTap;

  @override
  Widget build(BuildContext context) {
    final freezesLeft = (2 - freezeCount).clamp(0, 2);
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
              GestureDetector(
                onTap: freezesLeft > 0 ? onFreezeTap : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceSm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.progressBorderDefault,
                    borderRadius: BorderRadius.circular(AppDimens.radiusButton),
                  ),
                  child: Text(
                    'Freeze: $freezesLeft left',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: freezesLeft > 0
                          ? AppColors.progressTextSecondary
                          : AppColors.progressTextMuted,
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
              return _HeatmapDot(
                isActive: isActive,
                isToday: isToday,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _HeatmapDot extends StatelessWidget {
  const _HeatmapDot({required this.isActive, required this.isToday});
  final bool isActive;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
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
        boxShadow: isActive && isToday
            ? [
                BoxShadow(
                  color: AppColors.progressStreakWarm.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
