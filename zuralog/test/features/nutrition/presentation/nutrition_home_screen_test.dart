import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_goals_model.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/nutrition/presentation/nutrition_home_screen.dart';
import 'package:zuralog/features/nutrition/presentation/widgets/nutrition_budget_hero_card.dart';

/// A stub notifier that returns an empty meal list immediately.
class _EmptyMealsNotifier extends TodayMealsNotifier {
  @override
  Future<List<Meal>> build() async => [];
}

Widget wrapInApp(Widget child) => ProviderScope(child: MaterialApp(home: child));

void main() {
  testWidgets('shows NutritionBudgetHeroCard when goals set', (tester) async {
    await tester.pumpWidget(wrapInApp(
      ProviderScope(overrides: [
        nutritionGoalsProvider.overrideWith(
          (_) async => const NutritionGoals(calorieBudget: 2000),
        ),
        nutritionDaySummaryProvider.overrideWith(
          (_) async => NutritionDaySummary.empty,
        ),
        todayMealsProvider.overrideWith(_EmptyMealsNotifier.new),
      ], child: const NutritionHomeScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(NutritionBudgetHeroCard), findsOneWidget);
  });

  testWidgets('shows setup CTA when no calorie goal', (tester) async {
    await tester.pumpWidget(wrapInApp(
      ProviderScope(overrides: [
        nutritionGoalsProvider.overrideWith(
          (_) async => const NutritionGoals(),
        ),
        nutritionDaySummaryProvider.overrideWith(
          (_) async => NutritionDaySummary.empty,
        ),
        todayMealsProvider.overrideWith(_EmptyMealsNotifier.new),
      ], child: const NutritionHomeScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Look for CTA text
    expect(find.textContaining('Set up'), findsAtLeastNWidgets(1));
  });
}
