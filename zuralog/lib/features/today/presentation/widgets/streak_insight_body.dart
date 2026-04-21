/// Streak-variant body for the Insight Detail screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_hero_card.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

List<Widget> streakInsightSlivers(BuildContext context, WidgetRef ref) {
  return const [
    SliverToBoxAdapter(child: _StreakHero()),
    SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),
    SliverToBoxAdapter(child: _StreakCalendar()),
  ];
}

class _StreakHero extends ConsumerWidget {
  const _StreakHero();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(todayFeedProvider).valueOrNull;
    final streak = feed?.streak;
    final count = streak?.currentStreak ?? 0;
    return InsightHeroCard(
      eyebrow: 'Streak',
      categoryIcon: Icons.local_fire_department_rounded,
      categoryColor: AppColors.streakWarm,
      value: '$count day${count == 1 ? '' : 's'}',
      qualityLabel: streak?.isFrozen == true ? 'Freeze active' : null,
    );
  }
}

class _StreakCalendar extends ConsumerWidget {
  const _StreakCalendar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final today = DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZFadeSlideIn(
        delay: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            border: Border.all(
              color: colors.border.withValues(alpha: 0.4),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last 7 days',
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 6; i >= 0; i--)
                    _StreakDot(
                      date: today.subtract(Duration(days: i)),
                      active: true,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakDot extends StatelessWidget {
  const _StreakDot({required this.date, required this.active});
  final DateTime date;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final letter = names[date.weekday - 1];
    final colors = AppColorsOf(context);
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active
                ? AppColors.streakWarm.withValues(alpha: 0.22)
                : colors.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.local_fire_department_rounded,
            size: 18,
            color: active ? AppColors.streakWarm : colors.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          letter,
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }
}
