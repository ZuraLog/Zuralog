/// Today Tab — Nutrition Pillar Card.
///
/// Reads from [todayMealsProvider] and [nutritionDaySummaryProvider] to show
/// live data from the nutrition repository. Shows a minimal prompt when no
/// meals are logged yet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/widgets/cards/z_pillar_card.dart';

/// Nutrition pillar card wired to live provider data.
class NutritionPillarCard extends ConsumerWidget {
  const NutritionPillarCard({super.key, this.onTap});

  /// Called when the card body is tapped (navigates to Nutrition Home).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    const catColor = AppColors.categoryNutrition;

    final mealsAsync = ref.watch(todayMealsProvider);
    final summaryAsync = ref.watch(nutritionDaySummaryProvider);

    final meals = mealsAsync.valueOrNull ?? const <Meal>[];
    final summary = summaryAsync.valueOrNull ?? NutritionDaySummary.empty;

    // When no meals are logged, show a minimal prompt instead of zeros.
    if (meals.isEmpty && !mealsAsync.isLoading) {
      return ZPillarCard(
        icon: Icons.restaurant_rounded,
        categoryColor: catColor,
        label: 'Nutrition',
        headline: 'No meals yet',
        onTap: onTap,
      );
    }

    return ZPillarCard(
      icon: Icons.restaurant_rounded,
      categoryColor: catColor,
      label: 'Nutrition',
      headline: '${summary.totalCalories}',
      headlineUnit: 'kcal',
      secondaryStats: [
        PillarStat(label: 'P', value: '${summary.totalProteinG.round()}g'),
        PillarStat(label: 'C', value: '${summary.totalCarbsG.round()}g'),
        PillarStat(label: 'F', value: '${summary.totalFatG.round()}g'),
      ],
      onTap: onTap,
      bottomChild: Wrap(
        spacing: AppDimens.spaceSm,
        runSpacing: AppDimens.spaceXs,
        children: [
          for (final meal in meals)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceSm,
                vertical: AppDimens.spaceXs,
              ),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimens.shapeXs),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: meal.name,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: '  ${meal.totalCalories} kcal',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
