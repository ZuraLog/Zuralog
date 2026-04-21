/// Nutrition-variant body for the Insight Detail screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_hero_card.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_primary_chart.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_stats_grid.dart';

List<Widget> nutritionInsightSlivers(BuildContext context, WidgetRef ref) {
  return const [
    SliverToBoxAdapter(child: _NutritionHero()),
    SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),
    SliverToBoxAdapter(child: _NutritionTrendChart()),
    SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),
    SliverToBoxAdapter(child: _NutritionStats()),
  ];
}

class _NutritionHero extends ConsumerWidget {
  const _NutritionHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(nutritionDaySummaryProvider).valueOrNull ??
        NutritionDaySummary.empty;
    final kcal = summary.totalCalories;
    return InsightHeroCard(
      eyebrow: 'Today',
      categoryIcon: Icons.local_fire_department_rounded,
      categoryColor: AppColors.categoryNutrition,
      value: kcal > 0 ? '$kcal kcal' : '—',
      deltaLabel: null,
      deltaIsPositive: null,
      qualityLabel: null,
    );
  }
}

class _NutritionTrendChart extends ConsumerWidget {
  const _NutritionTrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(nutritionTrendProvider('7d')).valueOrNull ??
        const <NutritionTrendDay>[];
    if (days.isEmpty) return const SizedBox.shrink();
    return InsightPrimaryChart(
      title: 'Calories — 7 days',
      categoryColor: AppColors.categoryNutrition,
      points: [
        for (final day in days)
          InsightPrimaryChartPoint(
            label: _weekdayShort(day.date),
            value: (day.calories ?? 0).toDouble(),
            isToday: day.isToday,
          ),
      ],
      formatTooltip: (v) => '${v.round()} kcal',
      formatYAxis: (v) => v >= 1000
          ? '${(v / 1000).toStringAsFixed(1)}k'
          : v.round().toString(),
    );
  }

  String _weekdayShort(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    if (d == null) return '';
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return names[d.weekday - 1];
  }
}

class _NutritionStats extends ConsumerWidget {
  const _NutritionStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(nutritionDaySummaryProvider).valueOrNull ??
        NutritionDaySummary.empty;
    final tiles = <InsightStatTile>[
      InsightStatTile(
        icon: Icons.local_fire_department_rounded,
        label: 'Calories',
        value: '${summary.totalCalories} kcal',
      ),
      InsightStatTile(
        icon: Icons.set_meal_rounded,
        label: 'Protein',
        value: '${summary.totalProteinG.round()} g',
      ),
      InsightStatTile(
        icon: Icons.grain_rounded,
        label: 'Carbs',
        value: '${summary.totalCarbsG.round()} g',
      ),
      InsightStatTile(
        icon: Icons.opacity_rounded,
        label: 'Fat',
        value: '${summary.totalFatG.round()} g',
      ),
    ];
    return InsightStatsGrid(
      title: 'The details',
      categoryColor: AppColors.categoryNutrition,
      tiles: tiles,
    );
  }
}
