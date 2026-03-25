library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class StreakWeekCalendarRow extends StatelessWidget {
  const StreakWeekCalendarRow({
    super.key,
    required this.hits,
    required this.todayIndex,
  });

  final List<bool> hits;
  final int todayIndex;

  static const _labels = ['M', 'Tu', 'W', 'Th', 'F', 'Sa', 'Su'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final isHit = i < hits.length && hits[i];
        final isToday = i == todayIndex;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _labels[i],
              style: AppTextStyles.labelSmall.copyWith(
                color: isToday
                    ? AppColors.progressStreakWarm
                    : AppColors.progressTextMuted,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isHit ? AppColors.progressStreakWarm : Colors.transparent,
                border: Border.all(
                  color: isHit
                      ? AppColors.progressStreakWarm
                      : (isToday
                          ? AppColors.progressStreakWarm
                          : AppColors.progressBorderStrong),
                  width: 1.5,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
