/// Zuralog — Nutrition Weekly Summary Card.
///
/// Shows a 7-day view of calorie-goal adherence as coloured dots, enriched
/// stats (calorie/protein days hit, average calories, weekly balance,
/// projected outcome), and a running streak count.
///
/// The card is dismissible — tapping the × hides it for the remainder of
/// the ISO week (keyed by the Monday date of the current week).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_goals_model.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _colorGreen = Color(0xFF34C759);
const _colorAmber = Color(0xFFFF9500);
const _colorRed = Color(0xFFFF3B30);
const _colorGrey = Color(0xFF8E8E93);
const _cardCategory = Color(0xFFF59E0B); // amber

const _dotSize = 18.0;

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Returns a SharedPreferences key unique to the current ISO week.
///
/// Keyed by the Monday of the current week so the dismissal resets
/// automatically every Monday.
String _weekKey() {
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  return 'nutrition_weekly_dismissed_'
      '${monday.year}_'
      '${monday.month.toString().padLeft(2, '0')}_'
      '${monday.day.toString().padLeft(2, '0')}';
}

/// ISO weekday → single-letter label (Mon=1 … Sun=7).
String _dayLabel(int isoWeekday) {
  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return labels[(isoWeekday - 1) % 7];
}

Color _dotColor({required double? calories, required double? calorieBudget}) {
  if (calories == null || calorieBudget == null || calorieBudget <= 0) {
    return _colorGrey;
  }
  if (calories <= calorieBudget) return _colorGreen;
  if (calories <= calorieBudget * 1.1) return _colorAmber;
  return _colorRed;
}

/// Counts consecutive days backwards from the most recent entry where
/// calories ≤ calorieBudget. Days with no data break the streak.
int _calculateStreak(List<NutritionTrendDay> trend, double? calorieBudget) {
  if (calorieBudget == null || calorieBudget <= 0) return 0;
  final sorted = [...trend]..sort((a, b) => b.date.compareTo(a.date));
  var streak = 0;
  for (final day in sorted) {
    final cal = day.calories;
    if (cal == null) break;
    if (cal <= calorieBudget) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ── NutritionWeeklySummaryCard ────────────────────────────────────────────────

/// Card showing a 7-day calorie-adherence dot row with enriched weekly stats.
class NutritionWeeklySummaryCard extends ConsumerStatefulWidget {
  const NutritionWeeklySummaryCard({super.key});

  @override
  ConsumerState<NutritionWeeklySummaryCard> createState() =>
      _NutritionWeeklySummaryCardState();
}

class _NutritionWeeklySummaryCardState
    extends ConsumerState<NutritionWeeklySummaryCard> {
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _dismissed = ref.read(prefsProvider).getBool(_weekKey()) ?? false;
  }

  void _dismiss() {
    ref.read(prefsProvider).setBool(_weekKey(), true);
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final goalsAsync = ref.watch(nutritionGoalsProvider);
    final trendAsync = ref.watch(nutritionTrendProvider('7d'));

    final goals = goalsAsync.valueOrNull ?? const NutritionGoals();
    final trend = trendAsync.valueOrNull ?? const <NutritionTrendDay>[];

    final calorieBudget = goals.calorieBudget;
    final proteinMinG = goals.proteinMinG;
    final streak = _calculateStreak(trend, calorieBudget);

    // Build a map from ISO date string to trend day for O(1) lookup.
    final trendByDate = <String, NutritionTrendDay>{
      for (final d in trend) d.date: d,
    };

    // Generate the last 7 calendar days ending today (oldest → newest).
    final today = DateTime.now();
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    // ── Enriched stats ──────────────────────────────────────────────────────

    int calorieDaysHit = 0;
    int proteinDaysHit = 0;
    double totalCalories = 0;
    int daysWithData = 0;

    for (final day in trend) {
      if (day.calories != null) {
        daysWithData++;
        totalCalories += day.calories!;
        if (calorieBudget != null && calorieBudget > 0 && day.calories! <= calorieBudget) {
          calorieDaysHit++;
        }
      }
      if (day.proteinG != null && proteinMinG != null && proteinMinG > 0 && day.proteinG! >= proteinMinG) {
        proteinDaysHit++;
      }
    }

    final avgCalories = daysWithData > 0 ? totalCalories / daysWithData : null;

    // Weekly balance: positive = deficit (under budget), negative = surplus.
    double? weeklyBalance;
    String? projectedLabel;
    if (calorieBudget != null && calorieBudget > 0 && daysWithData > 0) {
      weeklyBalance = calorieBudget * daysWithData - totalCalories;
      // Project to a full week, then to kg/year (7700 kcal ≈ 1 kg body fat).
      final weeklyProjected = weeklyBalance * 7.0 / daysWithData;
      final kgPerYear = (weeklyProjected * 52.0 / 7700.0).abs();
      if (kgPerYear < 0.5) {
        projectedLabel = '~Maintenance pace';
      } else if (weeklyBalance > 0) {
        projectedLabel = '~${kgPerYear.toStringAsFixed(1)} kg loss/yr at this pace';
      } else {
        projectedLabel = '~${kgPerYear.toStringAsFixed(1)} kg gain/yr at this pace';
      }
    }

    final colors = AppColorsOf(context);

    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: _cardCategory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  'This Week',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              // Streak pill
              if (streak > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceSm,
                    vertical: AppDimens.spaceXxs,
                  ),
                  decoration: BoxDecoration(
                    color: _cardCategory.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 14,
                        color: _cardCategory,
                      ),
                      const SizedBox(width: AppDimens.spaceXxs),
                      Text(
                        '$streak day streak',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: _cardCategory,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
              ],
              // Dismiss button
              GestureDetector(
                onTap: _dismiss,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: AppDimens.spaceXs),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Enriched stats row ─────────────────────────────────────────────
          if (daysWithData > 0 && goals.hasGoals) ...[
            Row(
              children: [
                if (calorieBudget != null)
                  Expanded(
                    child: _StatCell(
                      label: 'Calorie days',
                      value: '$calorieDaysHit / $daysWithData',
                    ),
                  ),
                if (proteinMinG != null)
                  Expanded(
                    child: _StatCell(
                      label: 'Protein days',
                      value: '$proteinDaysHit / $daysWithData',
                    ),
                  ),
                if (avgCalories != null)
                  Expanded(
                    child: _StatCell(
                      label: 'Avg calories',
                      value: '${avgCalories.round()} kcal',
                    ),
                  ),
              ],
            ),
            if (weeklyBalance != null) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Row(
                children: [
                  Icon(
                    weeklyBalance >= 0
                        ? Icons.trending_down_rounded
                        : Icons.trending_up_rounded,
                    size: 14,
                    color: weeklyBalance >= 0 ? _colorGreen : _colorRed,
                  ),
                  const SizedBox(width: AppDimens.spaceXxs),
                  Text(
                    weeklyBalance >= 0
                        ? '${weeklyBalance.abs().round()} kcal deficit this week'
                        : '${weeklyBalance.abs().round()} kcal surplus this week',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: weeklyBalance >= 0 ? _colorGreen : _colorRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (projectedLabel != null) ...[
                const SizedBox(height: AppDimens.spaceXxs),
                Text(
                  projectedLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
            const SizedBox(height: AppDimens.spaceMd),
          ],

          // ── Dot row ────────────────────────────────────────────────────────
          Row(
            key: const ValueKey('weekly_dot_row'),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in days)
                _DayDot(
                  label: _dayLabel(day.weekday),
                  color: _dotColor(
                    calories: trendByDate[_dateKey(day)]?.calories,
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
}

// ── _StatCell ─────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
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
                ? Border.all(color: colors.textPrimary, width: 2)
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
          style: AppTextStyles.labelSmall.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}
