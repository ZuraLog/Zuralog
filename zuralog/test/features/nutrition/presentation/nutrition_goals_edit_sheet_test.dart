import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_goals_model.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/nutrition/presentation/nutrition_goals_edit_sheet.dart';

void main() {
  testWidgets('shows Calorie Budget field with current value', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nutritionGoalsProvider.overrideWith(
            (_) async => const NutritionGoals(calorieBudget: 2000.0),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: NutritionGoalsEditSheet()),
        ),
      ),
    );
    // pump once to trigger the async provider
    await tester.pump();
    // pump again to let it resolve
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Calorie'), findsAtLeastNWidgets(1));
    expect(find.textContaining('2000'), findsAtLeastNWidgets(1));
  });
}
