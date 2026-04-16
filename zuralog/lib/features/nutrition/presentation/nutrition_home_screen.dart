/// Zuralog — Nutrition Home Screen.
///
/// Displays today's nutrition summary, a list of logged meals, and a
/// call-to-action to log a new meal. Opens when the user taps the
/// Nutrition pillar card on the Today tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── NutritionHomeScreen ──────────────────────────────────────────────────────

/// Nutrition Home — shows daily summary, meal list, and log CTA.
class NutritionHomeScreen extends ConsumerWidget {
  const NutritionHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final mealsAsync = ref.watch(todayMealsProvider);
    final summaryAsync = ref.watch(nutritionDaySummaryProvider);
    const catColor = AppColors.categoryNutrition;

    return ZuralogScaffold(
      appBar: const ZuralogAppBar(
        title: 'Nutrition',
        showProfileAvatar: false,
      ),
      body: mealsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(catColor),
          ),
        ),
        error: (_, _) => ZErrorState(
          message: 'Something went wrong loading your meals.',
          onRetry: () {
            ref.invalidate(todayMealsProvider);
            ref.invalidate(nutritionDaySummaryProvider);
          },
        ),
        data: (meals) {
          final summary =
              summaryAsync.valueOrNull ?? NutritionDaySummary.empty;

          if (meals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: ZEmptyState(
                  icon: Icons.restaurant_outlined,
                  title: 'No meals logged yet',
                  message:
                      'Tap below to log your first meal of the day.',
                  actionLabel: 'Log a meal',
                  onAction: () =>
                      context.pushNamed(RouteNames.mealLog),
                ),
              ),
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ── Date header ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceLg,
                  AppDimens.spaceMd,
                  0,
                ),
                child: Text(
                  DateFormat('EEEE, MMM d').format(DateTime.now()),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),

              // ── Daily summary card ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  0,
                ),
                child: ZuralogCard(
                  variant: ZCardVariant.feature,
                  category: catColor,
                  child: Row(
                    children: [
                      _SummaryStat(
                        value: '${summary.totalCalories}',
                        label: 'kcal',
                        color: colors,
                      ),
                      _SummaryStat(
                        value: '${summary.totalProteinG.round()}',
                        label: 'protein',
                        color: colors,
                      ),
                      _SummaryStat(
                        value: '${summary.totalCarbsG.round()}',
                        label: 'carbs',
                        color: colors,
                      ),
                      _SummaryStat(
                        value: '${summary.totalFatG.round()}',
                        label: 'fat',
                        color: colors,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Section header ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceLg,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: SectionHeader(title: "Today's Meals"),
              ),

              // ── Meal cards ─────────────────────────────────────────
              for (final meal in meals)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    0,
                    AppDimens.spaceMd,
                    AppDimens.spaceSm,
                  ),
                  child: _MealCard(meal: meal),
                ),

              // ── Log a meal CTA ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceLg,
                ),
                child: ZButton(
                  label: 'Log a meal',
                  icon: Icons.add_rounded,
                  onPressed: () =>
                      context.pushNamed(RouteNames.mealLog),
                ),
              ),

              // ── Bottom clearance ───────────────────────────────────
              const SizedBox(height: AppDimens.spaceLg),
            ],
          );
        },
      ),
    );
  }
}

// ── _SummaryStat ─────────────────────────────────────────────────────────────

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final AppColorsOf color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              color: color.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXxs),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _MealCard ────────────────────────────────────────────────────────────────

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    const catColor = AppColors.categoryNutrition;

    return ZuralogCard(
      variant: ZCardVariant.plain,
      onTap: () => context.pushNamed(
        RouteNames.nutritionMealDetail,
        pathParameters: {'id': meal.id},
      ),
      child: Row(
        children: [
          // Meal type icon
          Container(
            width: AppDimens.iconContainerMd,
            height: AppDimens.iconContainerMd,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimens.shapeSm),
            ),
            child: Center(
              child: Icon(
                meal.type.icon,
                size: AppDimens.iconMd,
                color: catColor,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),

          // Meal info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXxs),
                Text(
                  '${meal.type.label}  ·  ${DateFormat('h:mm a').format(meal.loggedAt)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Calorie total
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${meal.totalCalories}',
                style: AppTextStyles.titleMedium.copyWith(
                  color: catColor,
                ),
              ),
              Text(
                'kcal',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
