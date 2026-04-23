/// Zuralog — Nutrition Weekly Summary Card.
///
/// Shows a 7-day view of calorie-goal adherence as coloured dots plus
/// a running streak count. Rendered on the Nutrition Home Screen below
/// the trend section.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_goals_model.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Dot colour constants ──────────────────────────────────────────────────────

const _colorGreen = Color(0xFF34C759);
const _colorAmber = Color(0xFFFF9500);
const _colorRed = Color(0xFFFF3B30);
const _colorGrey = Color(0xFF8E8E93);

const _dotSize = 18.0;

// ── Day labels ────────────────────────────────────────────────────────────────

/// ISO weekday → single-letter label (Mon=1 … Sun=7).
String _dayLabel(int isoWeekday) {
  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return labels[(isoWeekday - 1) % 7];
}

// ── Dot colour logic ──────────────────────────────────────────────────────────

Color _dotColor({
  required double? calories,
  required double? calorieBudget,
}) {
  if (calories == null || calorieBudget == null || calorieBudget <= 0) {
    return _colorGrey;
  }
  if (calories <= calorieBudget) return _colorGreen;
  if (calories <= calorieBudget * 1.1) return _colorAmber;
  return _colorRed;
}

// ── Streak calculation ────────────────────────────────────────────────────────

/// Counts consecutive days going backwards from the most recent entry where
/// [calories] <= [calorieBudget]. Days with no data break the streak.
int _calculateStreak(
  List<NutritionTrendDay> trend,
  double? calorieBudget,
) {
  if (calorieBudget == null || calorieBudget <= 0) return 0;

  // Sort newest first so we can walk backwards from today.
  final sorted = [...trend]..sort((a, b) => b.date.compareTo(a.date));

  var streak = 0;
  for (final day in sorted) {
    final calories = day.calories;
    if (calories == null) break;
    if (calories <= calorieBudget) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

// ── NutritionWeeklySummaryCard ────────────────────────────────────────────────

/// Card showing a 7-day calorie-adherence dot row and a streak count.
class NutritionWeeklySummaryCard extends ConsumerWidget {
  const NutritionWeeklySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(nutritionGoalsProvider);
    final trendAsync = ref.watch(nutritionTrendProvider('7d'));

    final goals = goalsAsync.valueOrNull ?? const NutritionGoals();
    final trend = trendAsync.valueOrNull ?? const <NutritionTrendDay>[];

    final calorieBudget = goals.calorieBudget;
    final streak = _calculateStreak(trend, calorieBudget);

    // Build a map from ISO date string to trend day for O(1) lookup.
    final trendByDate = <String, NutritionTrendDay>{
      for (final d in trend) d.date: d,
    };

    // Generate the last 7 calendar days ending today (oldest → newest).
    final today = DateTime.now();
    final days = List.generate(7, (i) {
      return today.subtract(Duration(days: 6 - i));
    });

    final colors = AppColorsOf(context);

    return ZuralogCard(
      variant: ZCardVariant.data,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  'Weekly Goal Check-In',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              // Streak pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceSm,
                  vertical: AppDimens.spaceXxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.categoryNutrition.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 14,
                      color: AppColors.categoryNutrition,
                    ),
                    const SizedBox(width: AppDimens.spaceXxs),
                    Text(
                      '$streak day streak',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.categoryNutrition,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Dot row ────────────────────────────────────────────────────────
          Row(
            key: const ValueKey('weekly_dot_row'),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in days)
                _DayDot(
                  label: _dayLabel(day.weekday),
                  color: _dotColor(
                    calories:
                        trendByDate[_dateKey(day)]?.calories,
                    calorieBudget: calorieBudget,
                  ),
                  isToday: _isSameDay(day, today),
                ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceSm),

          // ── Legend ─────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: _colorGreen, label: 'Goal met'),
              const SizedBox(width: AppDimens.spaceMd),
              _LegendDot(color: _colorAmber, label: 'Close'),
              const SizedBox(width: AppDimens.spaceMd),
              _LegendDot(color: _colorRed, label: 'Over'),
              const SizedBox(width: AppDimens.spaceMd),
              _LegendDot(color: _colorGrey, label: 'No data'),
            ],
          ),
        ],
      ),
    );
  }

  /// Returns `'YYYY-MM-DD'` for the given [DateTime].
  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── _DayDot ───────────────────────────────────────────────────────────────────

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.color,
    required this.isToday,
  });

  final String label;
  final Color color;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(
                    color: colors.textPrimary,
                    width: 2,
                  )
                : null,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXxs),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isToday ? colors.textPrimary : colors.textSecondary,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── _LegendDot ────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppDimens.spaceXxs),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
