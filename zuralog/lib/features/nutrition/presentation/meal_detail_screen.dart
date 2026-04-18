/// Zuralog — Meal Detail Screen.
///
/// Deep-dive view for a single logged meal. Shows the meal header, a list
/// of food items with macros, totals, and edit/delete actions.
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
import 'package:zuralog/features/nutrition/presentation/meal_edit_screen.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── MealDetailScreen ─────────────────────────────────────────────────────────

/// Full detail view for a single [Meal] identified by [mealId].
class MealDetailScreen extends ConsumerStatefulWidget {
  const MealDetailScreen({super.key, required this.mealId});

  /// The meal ID passed from GoRouter path parameters.
  final String mealId;

  @override
  ConsumerState<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends ConsumerState<MealDetailScreen> {
  bool _isDeleting = false;

  Future<void> _confirmDelete(Meal meal) async {
    final confirmed = await ZAlertDialog.show(
      context,
      title: 'Delete meal?',
      body:
          'This will permanently remove "${meal.name}" from today\'s log.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isDeleting = true);

    try {
      await ref
          .read(nutritionRepositoryProvider)
          .deleteMeal(widget.mealId);
      ref.invalidate(todayMealsProvider);
      ref.invalidate(nutritionDaySummaryProvider);
      ref.invalidate(mealDetailProvider(widget.mealId));
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final mealAsync = ref.watch(mealDetailProvider(widget.mealId));
    const catColor = AppColors.categoryNutrition;

    return ZuralogScaffold(
      appBar: const ZuralogAppBar(
        title: 'Meal Detail',
        showProfileAvatar: false,
      ),
      body: mealAsync.when(
        loading: () => ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Meal header card skeleton.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                0,
              ),
              child: ZLoadingSkeleton(
                width: double.infinity,
                height: 100,
                borderRadius: AppDimens.shapeLg,
              ),
            ),

            // Foods section header skeleton.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: ZLoadingSkeleton(
                width: 80,
                height: 16,
                borderRadius: AppDimens.shapeSm,
              ),
            ),

            // Three food row skeletons.
            for (int i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  0,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: ZLoadingSkeleton(
                  width: double.infinity,
                  height: 60,
                  borderRadius: AppDimens.shapeMd,
                ),
              ),

            // Totals card skeleton.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceSm,
                AppDimens.spaceMd,
                0,
              ),
              child: ZLoadingSkeleton(
                width: double.infinity,
                height: 80,
                borderRadius: AppDimens.shapeLg,
              ),
            ),
          ],
        ),
        error: (_, _) => ZErrorState(
          message: 'Something went wrong loading this meal.',
          onRetry: () =>
              ref.invalidate(mealDetailProvider(widget.mealId)),
        ),
        data: (meal) {
          if (meal == null) {
            return const Center(
              child: ZEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Meal not found',
                message: 'This meal may have been deleted.',
              ),
            );
          }

          final foodCount = meal.foods.length;
          final totalsDelay = 120 + (foodCount * 60) + 60;
          final buttonsDelay = totalsDelay + 60;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ── Meal header card ─────────────────────────────────
              ZFadeSlideIn(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceLg,
                    AppDimens.spaceMd,
                    0,
                  ),
                  child: ZuralogCard(
                    variant: ZCardVariant.feature,
                    category: catColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal.name,
                          style: AppTextStyles.displaySmall.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceSm),
                        Row(
                          children: [
                            Icon(
                              meal.type.icon,
                              size: AppDimens.iconSm,
                              color: catColor,
                            ),
                            const SizedBox(width: AppDimens.spaceXs),
                            Text(
                              '${meal.type.label} at ${DateFormat('h:mm a').format(meal.loggedAt)}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Foods section header ─────────────────────────────
              ZFadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceLg,
                    AppDimens.spaceMd,
                    AppDimens.spaceSm,
                  ),
                  child: SectionHeader(title: 'Foods'),
                ),
              ),

              // ── Food items ───────────────────────────────────────
              for (int i = 0; i < foodCount; i++)
                ZFadeSlideIn(
                  delay: Duration(milliseconds: 120 + (i * 60)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      0,
                      AppDimens.spaceMd,
                      AppDimens.spaceSm,
                    ),
                    child: _FoodRow(food: meal.foods[i]),
                  ),
                ),

              // ── Totals card ──────────────────────────────────────
              ZFadeSlideIn(
                delay: Duration(milliseconds: totalsDelay),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceSm,
                    AppDimens.spaceMd,
                    0,
                  ),
                  child: ZuralogCard(
                    variant: ZCardVariant.feature,
                    category: catColor,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              'Total',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${meal.totalCalories} kcal',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: catColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimens.spaceMd),
                        Row(
                          children: [
                            _MacroChip(
                              label: 'Protein',
                              value: '${meal.totalProtein.round()}g',
                              colors: colors,
                            ),
                            _MacroChip(
                              label: 'Carbs',
                              value: '${meal.totalCarbs.round()}g',
                              colors: colors,
                            ),
                            _MacroChip(
                              label: 'Fat',
                              value: '${meal.totalFat.round()}g',
                              colors: colors,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Action buttons ───────────────────────────────────
              ZFadeSlideIn(
                delay: Duration(milliseconds: buttonsDelay),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceLg,
                    AppDimens.spaceMd,
                    0,
                  ),
                  child: ZButton(
                    label: 'Edit meal',
                    variant: ZButtonVariant.secondary,
                    icon: Icons.edit_outlined,
                    onPressed: () => context.pushNamed(
                      RouteNames.nutritionMealEdit,
                      extra: MealEditArgs(meal: meal),
                    ),
                  ),
                ),
              ),
              ZFadeSlideIn(
                delay: Duration(milliseconds: buttonsDelay),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceSm,
                    AppDimens.spaceMd,
                    0,
                  ),
                  child: ZButton(
                    label: 'Delete meal',
                    variant: ZButtonVariant.destructive,
                    icon: Icons.delete_outline_rounded,
                    isLoading: _isDeleting,
                    onPressed:
                        _isDeleting ? null : () => _confirmDelete(meal),
                  ),
                ),
              ),

              // ── Bottom clearance ─────────────────────────────────
              const SizedBox(height: AppDimens.spaceXl),
            ],
          );
        },
      ),
    );
  }
}

// ── _FoodRow ─────────────────────────────────────────────────────────────────

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.food});

  final MealFood food;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return ZuralogCard(
      variant: ZCardVariant.data,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXxs),
                Text(
                  '${food.portionGrams}g',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${food.caloriesKcal} kcal',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceXxs),
              Text(
                'P ${food.proteinG.toStringAsFixed(food.proteinG.truncateToDouble() == food.proteinG ? 0 : 1)}g · '
                'C ${food.carbsG.toStringAsFixed(food.carbsG.truncateToDouble() == food.carbsG ? 0 : 1)}g · '
                'F ${food.fatG.toStringAsFixed(food.fatG.truncateToDouble() == food.fatG ? 0 : 1)}g',
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

// ── _MacroChip ───────────────────────────────────────────────────────────────

class _MacroChip extends StatelessWidget {
  const _MacroChip({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXxs),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
