library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/today/presentation/widgets/nutrition_pillar_card.dart';

// -- Stub AsyncNotifier for todayMealsProvider --------------------------------

class _StubMealsNotifier extends TodayMealsNotifier {
  _StubMealsNotifier(this._meals);

  final List<Meal> _meals;

  @override
  Future<List<Meal>> build() async => _meals;
}

// -- Helpers ------------------------------------------------------------------

Widget _buildCard({
  required List<Meal> meals,
  required NutritionDaySummary summary,
}) {
  return ProviderScope(
    overrides: [
      todayMealsProvider.overrideWith(() => _StubMealsNotifier(meals)),
      nutritionDaySummaryProvider.overrideWith((ref) async => summary),
    ],
    child: const MaterialApp(
      home: Scaffold(body: NutritionPillarCard()),
    ),
  );
}

// -- Tests --------------------------------------------------------------------

void main() {
  group('NutritionPillarCard — empty state', () {
    testWidgets('shows "No meals yet" headline', (tester) async {
      await tester.pumpWidget(_buildCard(
        meals: const [],
        summary: NutritionDaySummary.empty,
      ));
      await tester.pump(); // let AsyncNotifier and FutureProvider resolve
      expect(find.text('No meals yet'), findsOneWidget);
    });

    testWidgets('does NOT show "Add meal" text', (tester) async {
      await tester.pumpWidget(_buildCard(
        meals: const [],
        summary: NutritionDaySummary.empty,
      ));
      await tester.pump();
      expect(find.text('Add meal'), findsNothing);
    });

    testWidgets('shows NUTRITION label', (tester) async {
      await tester.pumpWidget(_buildCard(
        meals: const [],
        summary: NutritionDaySummary.empty,
      ));
      await tester.pump();
      expect(find.text('NUTRITION'), findsOneWidget);
    });
  });

  group('NutritionPillarCard — data state', () {
    final testMeal = Meal(
      id: 'meal-1',
      name: 'Oatmeal',
      type: MealType.breakfast,
      loggedAt: DateTime.now(),
      foods: [
        const MealFood(
          name: 'Oats',
          portionGrams: 80,
          caloriesKcal: 310,
          proteinG: 11,
          carbsG: 55,
          fatG: 6,
        ),
      ],
    );

    const testSummary = NutritionDaySummary(
      totalCalories: 310,
      totalProteinG: 11,
      totalCarbsG: 55,
      totalFatG: 6,
      mealCount: 1,
    );

    testWidgets('shows calorie total', (tester) async {
      await tester.pumpWidget(_buildCard(
        meals: [testMeal],
        summary: testSummary,
      ));
      await tester.pump();
      expect(find.text('310'), findsOneWidget);
    });

    testWidgets('shows meal name chip', (tester) async {
      await tester.pumpWidget(_buildCard(
        meals: [testMeal],
        summary: testSummary,
      ));
      await tester.pump();
      expect(find.textContaining('Oatmeal'), findsOneWidget);
    });

    testWidgets('does NOT show add icon', (tester) async {
      await tester.pumpWidget(_buildCard(
        meals: [testMeal],
        summary: testSummary,
      ));
      await tester.pump();
      expect(find.byIcon(Icons.add_rounded), findsNothing);
    });
  });
}
