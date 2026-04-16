/// Today Tab — Nutrition Pillar Card.
// TODO(backend): Replace hardwired data with provider data.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/cards/z_pillar_card.dart';

class _MealEntry {
  const _MealEntry({required this.name, required this.calories});
  final String name;
  final int calories;
}

class NutritionPillarCard extends StatelessWidget {
  const NutritionPillarCard({super.key, this.onTap, this.onAddMeal});

  final VoidCallback? onTap;
  final VoidCallback? onAddMeal;

  static const _meals = [
    _MealEntry(name: 'Greek yogurt + berries', calories: 320),
    _MealEntry(name: 'Salmon poke bowl', calories: 540),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    const catColor = AppColors.categoryNutrition;

    return ZPillarCard(
      icon: Icons.restaurant_rounded,
      categoryColor: catColor,
      label: 'Nutrition',
      headline: '860',
      headlineUnit: 'kcal',
      secondaryStats: const [
        PillarStat(label: 'P', value: '62g'),
        PillarStat(label: 'C', value: '180g'),
        PillarStat(label: 'F', value: '48g'),
      ],
      onTap: onTap,
      bottomChild: Wrap(
        spacing: AppDimens.spaceSm,
        runSpacing: AppDimens.spaceXs,
        children: [
          for (final meal in _meals)
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
                      text: '  ${meal.calories} kcal',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          GestureDetector(
            onTap: onAddMeal,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceSm,
                vertical: AppDimens.spaceXs,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimens.shapeXs),
                border: Border.all(
                  color: catColor.withValues(alpha: 0.30),
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                size: AppDimens.iconSm,
                color: catColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
