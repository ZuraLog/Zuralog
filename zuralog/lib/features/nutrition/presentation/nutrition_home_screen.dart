/// Zuralog — Nutrition Home Screen.
///
/// Displays today's nutrition summary, a list of logged meals, and a
/// call-to-action to log a new meal. Opens when the user taps the
/// Nutrition pillar card on the Today tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/features/nutrition/presentation/log_meal_sheet.dart';
import 'package:zuralog/features/nutrition/presentation/meal_edit_screen.dart' show MealEditArgs;
import 'package:zuralog/features/nutrition/presentation/nutrition_goals_edit_sheet.dart';
import 'package:zuralog/features/nutrition/presentation/nutrition_goals_setup_sheet.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_goals_model.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/nutrition/presentation/widgets/nutrition_ai_summary_card.dart';
import 'package:zuralog/features/nutrition/presentation/widgets/nutrition_budget_hero_card.dart';
import 'package:zuralog/features/nutrition/presentation/widgets/nutrition_macro_progress_card.dart';
import 'package:zuralog/features/nutrition/presentation/widgets/nutrition_trend_section.dart';
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
    final goalsAsync = ref.watch(nutritionGoalsProvider);
    final goals = goalsAsync.valueOrNull ?? const NutritionGoals();
    const catColor = AppColors.categoryNutrition;

    return ZuralogScaffold(
      appBar: ZuralogAppBar(
        title: 'Nutrition',
        showProfileAvatar: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: goals.hasGoals ? 'Edit goals' : 'Set up goals',
            onPressed: () => goals.hasGoals
                ? NutritionGoalsEditSheet.show(context)
                : NutritionGoalsSetupSheet.show(context),
          ),
        ],
      ),
      body: mealsAsync.when(
        loading: () => ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Date header skeleton.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                0,
              ),
              child: ZLoadingSkeleton(
                width: 140,
                height: 16,
                borderRadius: AppDimens.shapeSm,
              ),
            ),

            // Daily summary card skeleton.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
                0,
              ),
              child: ZLoadingSkeleton(
                width: double.infinity,
                height: 80,
                borderRadius: AppDimens.shapeLg,
              ),
            ),

            // Section header skeleton.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: ZLoadingSkeleton(
                width: 120,
                height: 16,
                borderRadius: AppDimens.shapeSm,
              ),
            ),

            // Meal card skeleton 1.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                0,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: ZLoadingSkeleton(
                width: double.infinity,
                height: 72,
                borderRadius: AppDimens.shapeLg,
              ),
            ),

            // Meal card skeleton 2.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                0,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: ZLoadingSkeleton(
                width: double.infinity,
                height: 72,
                borderRadius: AppDimens.shapeLg,
              ),
            ),
          ],
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

          Future<void> onRefresh() async {
            ref.invalidate(todayMealsProvider);
            ref.invalidate(nutritionDaySummaryProvider);
            ref.invalidate(nutritionTrendProvider('7d'));
            ref.invalidate(nutritionTrendProvider('30d'));
            await Future.wait([
              ref
                  .read(todayMealsProvider.future)
                  .catchError((_) => <Meal>[]),
              ref
                  .read(nutritionDaySummaryProvider.future)
                  .catchError((_) => NutritionDaySummary.empty),
            ]);
          }

          if (meals.isEmpty) {
            return ZPullToRefresh(
              onRefresh: onRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Budget hero card ─────────────────────────────
                        const ZFadeSlideIn(
                          delay: Duration(milliseconds: 60),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              AppDimens.spaceMd,
                              AppDimens.spaceMd,
                              AppDimens.spaceMd,
                              0,
                            ),
                            child: NutritionBudgetHeroCard(),
                          ),
                        ),

                        // ── Macro progress card (goals set) ──────────────
                        if (goals.hasGoals)
                          const ZFadeSlideIn(
                            delay: Duration(milliseconds: 90),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                AppDimens.spaceMd,
                                AppDimens.spaceMd,
                                AppDimens.spaceMd,
                                0,
                              ),
                              child: NutritionMacroProgressCard(),
                            ),
                          ),

                        // ── Goals empty-state banner (no goals) ──────────
                        if (!goals.hasGoals)
                          ZFadeSlideIn(
                            delay: const Duration(milliseconds: 90),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppDimens.spaceMd,
                                AppDimens.spaceMd,
                                AppDimens.spaceMd,
                                0,
                              ),
                              child: ZuralogCard(
                                variant: ZCardVariant.plain,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.flag_outlined,
                                      size: AppDimens.iconMd,
                                      color: catColor,
                                    ),
                                    const SizedBox(width: AppDimens.spaceMd),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'No goals set yet',
                                            style:
                                                AppTextStyles.titleMedium.copyWith(
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(
                                              height: AppDimens.spaceXxs),
                                          Text(
                                            'Set up your calorie budget and macro targets.',
                                            style:
                                                AppTextStyles.bodySmall.copyWith(
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppDimens.spaceSm),
                                    TextButton(
                                      onPressed: () =>
                                          NutritionGoalsSetupSheet.show(
                                              context),
                                      child: const Text('Set up'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
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
                                onAction: () => LogMealSheet.show(context),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppDimens.spaceMd,
                            AppDimens.spaceSm,
                            AppDimens.spaceMd,
                            AppDimens.spaceLg,
                          ),
                          child: InkWell(
                            onTap: () =>
                                context.pushNamed(RouteNames.nutritionAllData),
                            borderRadius:
                                BorderRadius.circular(AppDimens.shapeSm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppDimens.spaceXs,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'View All Data',
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: AppDimens.spaceXs),
                                  const ZProBadge(showLock: true),
                                  const SizedBox(width: AppDimens.spaceXs),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: AppDimens.iconSm,
                                    color: colors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return ZPullToRefresh(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // ── Date header ────────────────────────────────────────
                ZFadeSlideIn(
                  child: Padding(
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
                ),

                // ── Budget hero card ───────────────────────────────────
                const ZFadeSlideIn(
                  delay: Duration(milliseconds: 60),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      AppDimens.spaceMd,
                      AppDimens.spaceMd,
                      0,
                    ),
                    child: NutritionBudgetHeroCard(),
                  ),
                ),

                // ── Macro progress card (only when goals are set) ───────
                if (goals.hasGoals)
                  const ZFadeSlideIn(
                    delay: Duration(milliseconds: 90),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppDimens.spaceMd,
                        AppDimens.spaceMd,
                        AppDimens.spaceMd,
                        0,
                      ),
                      child: NutritionMacroProgressCard(),
                    ),
                  ),

                // ── Goals empty-state banner ────────────────────────────
                if (!goals.hasGoals)
                  ZFadeSlideIn(
                    delay: const Duration(milliseconds: 90),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.spaceMd,
                        AppDimens.spaceMd,
                        AppDimens.spaceMd,
                        0,
                      ),
                      child: ZuralogCard(
                        variant: ZCardVariant.plain,
                        child: Row(
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              size: AppDimens.iconMd,
                              color: catColor,
                            ),
                            const SizedBox(width: AppDimens.spaceMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No goals set yet',
                                    style: AppTextStyles.titleMedium.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: AppDimens.spaceXxs),
                                  Text(
                                    'Set up your calorie budget and macro targets.',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppDimens.spaceSm),
                            TextButton(
                              onPressed: () =>
                                  NutritionGoalsSetupSheet.show(context),
                              child: const Text('Set up'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── AI Summary card ─────────────────────────────────────
                ZFadeSlideIn(
                  delay: const Duration(milliseconds: 120),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      AppDimens.spaceMd,
                      AppDimens.spaceMd,
                      0,
                    ),
                    child: NutritionAiSummaryCard(
                      aiSummary: summary.aiSummary,
                      generatedAt: summary.aiGeneratedAt,
                    ),
                  ),
                ),

                // ── Nutrition Trend ──────────────────────────────────────
                ZFadeSlideIn(
                  delay: const Duration(milliseconds: 180),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      AppDimens.spaceMd,
                      AppDimens.spaceMd,
                      0,
                    ),
                    child: NutritionTrendSection(),
                  ),
                ),

                // ── View All Data row ────────────────────────────────────
                ZFadeSlideIn(
                  delay: const Duration(milliseconds: 240),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      AppDimens.spaceSm,
                      AppDimens.spaceMd,
                      0,
                    ),
                    child: InkWell(
                      onTap: () => context.pushNamed(RouteNames.nutritionAllData),
                      borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimens.spaceXs,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'View All Data',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: AppDimens.spaceXs),
                            const ZProBadge(showLock: true),
                            const SizedBox(width: AppDimens.spaceXs),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: AppDimens.iconSm,
                              color: colors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Section header ─────────────────────────────────────
                ZFadeSlideIn(
                  delay: const Duration(milliseconds: 300),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      AppDimens.spaceLg,
                      AppDimens.spaceMd,
                      AppDimens.spaceSm,
                    ),
                    child: SectionHeader(title: "Today's Meals"),
                  ),
                ),

                // ── Meal cards ─────────────────────────────────────────
                for (int i = 0; i < meals.length; i++)
                  ZFadeSlideIn(
                    delay: Duration(milliseconds: 360 + (i * 60)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.spaceMd,
                        0,
                        AppDimens.spaceMd,
                        AppDimens.spaceSm,
                      ),
                      child: _SlidableMealCard(
                        meal: meals[i],
                        onEdit: () => _handleEditMeal(context, meals[i]),
                        onDelete: () =>
                            _handleDeleteMeal(context, ref, meals[i]),
                      ),
                    ),
                  ),

                // ── Log a meal CTA ─────────────────────────────────────
                ZFadeSlideIn(
                  delay: Duration(
                    milliseconds: 360 + (meals.length * 60) + 60,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceLg,
                    ),
                    child: ZButton(
                      label: 'Log a meal',
                      icon: Icons.add_rounded,
                      onPressed: () => LogMealSheet.show(context),
                    ),
                  ),
                ),

                // ── Bottom clearance ───────────────────────────────────
                const SizedBox(height: AppDimens.spaceLg),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleEditMeal(BuildContext context, Meal meal) {
    context.pushNamed(
      RouteNames.nutritionMealEdit,
      extra: MealEditArgs(meal: meal),
    );
  }

  void _handleDeleteMeal(BuildContext context, WidgetRef ref, Meal meal) {
    ref.read(todayMealsProvider.notifier).deleteOptimistic(meal);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted ${meal.name}'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            ref.read(todayMealsProvider.notifier).undoDelete(meal.id);
          },
        ),
      ),
    );
  }
}

// ── _SummaryStat ─────────────────────────────────────────────────────────────


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

// ── _SlidableMealCard ────────────────────────────────────────────────────────

/// Wraps [_MealCard] in a [Slidable] with trailing Edit + Delete actions.
///
/// Partial swipe reveals both buttons; full swipe past the dismissible
/// threshold triggers delete. Both the full-swipe dismiss and the Delete
/// button tap route through [onDelete]; the Edit button routes through
/// [onEdit].
class _SlidableMealCard extends StatelessWidget {
  const _SlidableMealCard({
    required this.meal,
    required this.onEdit,
    required this.onDelete,
  });

  final Meal meal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    // Simple, reliable: default SlidableAction rectangles filling the
    // full row height, with an outer ClipRRect that rounds Delete's
    // right edge to match the meal card radius. Edit stays flush
    // between the card and Delete — the sandwich position means it
    // can't carry its own rounding without drifting into floating
    // capsules, which we tried and rejected.
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Slidable(
        key: ValueKey(meal.id),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.5,
          dismissible: DismissiblePane(onDismissed: onDelete),
          children: [
            SlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: colors.surfaceRaised,
              foregroundColor: colors.textPrimary,
              icon: Icons.edit_rounded,
              label: 'Edit',
            ),
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
            ),
          ],
        ),
        child: _MealCard(meal: meal),
      ),
    );
  }
}
