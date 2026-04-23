import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_goals_model.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/nutrition/presentation/widgets/nutrition_budget_hero_card.dart';

Widget wrapInApp(Widget child) => ProviderScope(child: MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('shows budget and eaten values', (tester) async {
    await tester.pumpWidget(wrapInApp(
      ProviderScope(overrides: [
        nutritionGoalsProvider.overrideWith(
          (_) async => const NutritionGoals(calorieBudget: 2000),
        ),
        nutritionDaySummaryProvider.overrideWith(
          (_) async => NutritionDaySummary(
            totalCalories: 1250,
            totalProteinG: 0,
            totalCarbsG: 0,
            totalFatG: 0,
            fiberG: 0,
            sodiumMg: 0,
            sugarG: 0,
            exerciseCaloriesBurned: 320,
            mealCount: 2,
          ),
        ),
      ], child: const NutritionBudgetHeroCard()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('2,000'), findsAtLeastNWidgets(1));
    expect(find.textContaining('1,250'), findsAtLeastNWidgets(1));
    expect(find.textContaining('320'), findsAtLeastNWidgets(1));
    // Remaining = 2000 - 1250 + 320 = 1,070
    expect(find.textContaining('1,070'), findsAtLeastNWidgets(1));
  });
}
