/// Zuralog — Nutrition Budget Hero Card.
///
/// The main calorie ring card at the top of the Nutrition home screen.
/// Shows today's calories eaten vs. the daily budget as a progress ring,
/// and lists four key values: Budget, Eaten, Burned, and Remaining.
///
/// Remaining = Budget − Eaten + Burned (exercise adds back to your budget).
///
/// When no budget is set, only the eaten value is shown without percentages.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_goals_model.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';
import 'package:zuralog/shared/widgets/charts/z_goal_progress_ring.dart';

/// Formats an integer as a comma-separated string (e.g. 1250 → "1,250").
String _fmt(int value) => NumberFormat('#,###').format(value);

/// The calorie ring hero card for the Nutrition home screen.
///
/// Watches [nutritionGoalsProvider] and [nutritionDaySummaryProvider] and
/// renders immediately from cached data — no loading spinner is shown unless
/// both futures are still pending.
class NutritionBudgetHeroCard extends ConsumerWidget {
  const NutritionBudgetHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(nutritionGoalsProvider);
    final summaryAsync = ref.watch(nutritionDaySummaryProvider);

    // Resolve safe defaults while loading or on error.
    final goals = goalsAsync.valueOrNull ?? const NutritionGoals();
    final summary = summaryAsync.valueOrNull ?? NutritionDaySummary.empty;

    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: AppColors.categoryNutrition,
      child: _CardBody(goals: goals, summary: summary),
    );
  }
}

/// Inner layout: ring on the left, stat rows on the right.
class _CardBody extends StatelessWidget {
  const _CardBody({required this.goals, required this.summary});

  final NutritionGoals goals;
  final NutritionDaySummary summary;

  @override
  Widget build(BuildContext context) {
    final budget = goals.calorieBudget;
    final eaten = summary.totalCalories;
    final burned = summary.exerciseCaloriesBurned;
    final remaining = budget != null
        ? (budget.round() - eaten + burned)
        : null;

    // Ring fills based on eaten / budget only (exercise does not inflate ring).
    final ringFraction = budget != null && budget > 0
        ? (eaten / budget).clamp(0.0, 1.0)
        : 0.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: progress ring ──────────────────────────────────────────
          _CalorieRing(
            fraction: ringFraction,
            eaten: eaten,
            budget: budget,
          ),
          const SizedBox(width: AppDimens.spaceMd),
          // ── Right: stat rows ─────────────────────────────────────────────
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatRow(
                  label: 'Budget',
                  value: budget != null ? _fmt(budget.round()) : '—',
                  unit: budget != null ? 'kcal' : null,
                ),
                const SizedBox(height: AppDimens.spaceSm),
                _StatRow(
                  label: 'Eaten',
                  value: _fmt(eaten),
                  unit: 'kcal',
                  accent: AppColors.categoryNutrition,
                ),
                const SizedBox(height: AppDimens.spaceSm),
                _StatRow(
                  label: 'Burned',
                  value: _fmt(burned),
                  unit: 'kcal',
                ),
                const SizedBox(height: AppDimens.spaceSm),
                _StatRow(
                  label: 'Remaining',
                  value: remaining != null ? _fmt(remaining) : '—',
                  unit: remaining != null ? 'kcal' : null,
                  isRemaining: true,
                  remaining: remaining,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The donut-style progress ring showing calories eaten vs. budget.
class _CalorieRing extends StatelessWidget {
  const _CalorieRing({
    required this.fraction,
    required this.eaten,
    required this.budget,
  });

  final double fraction;
  final int eaten;
  final double? budget;

  @override
  Widget build(BuildContext context) {
    final centerLabel = budget != null
        ? '${(fraction * 100).round()}%'
        : null;

    return ZGoalProgressRing(
      value: budget != null ? eaten.toDouble() : 0,
      goal: budget ?? 1,
      color: AppColors.categoryNutrition,
      size: 120,
      strokeWidth: 11,
      centerValue: _fmt(eaten),
      centerLabel: centerLabel ?? 'kcal',
    );
  }
}

/// A single label + value stat row used on the right side of the card.
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.unit,
    this.accent,
    this.isRemaining = false,
    this.remaining,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? accent;
  final bool isRemaining;
  final int? remaining;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    // Remaining row turns amber when over budget (negative remaining).
    Color valueColor;
    if (isRemaining && remaining != null && remaining! < 0) {
      valueColor = AppColors.warning;
    } else if (accent != null) {
      valueColor = accent!;
    } else {
      valueColor = colors.textPrimary;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textTertiary,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Text(
                unit!,
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
