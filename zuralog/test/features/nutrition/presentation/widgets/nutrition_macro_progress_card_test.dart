import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_goals_model.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/nutrition/presentation/widgets/nutrition_macro_progress_card.dart';

Widget wrapInApp(Widget child) => ProviderScope(child: MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('renders protein bar when proteinMinG is set', (tester) async {
    await tester.pumpWidget(wrapInApp(
      ProviderScope(overrides: [
        nutritionGoalsProvider.overrideWith(
          (_) async => const NutritionGoals(proteinMinG: 150),
        ),
        nutritionDaySummaryProvider.overrideWith(
          (_) async => NutritionDaySummary(
            totalCalories: 0,
            totalProteinG: 100,
            totalCarbsG: 0,
            totalFatG: 0,
            fiberG: 0,
            sodiumMg: 0,
            sugarG: 0,
            exerciseCaloriesBurned: 0,
            mealCount: 0,
          ),
        ),
      ], child: const NutritionMacroProgressCard()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Protein'), findsOneWidget);
  });
}
