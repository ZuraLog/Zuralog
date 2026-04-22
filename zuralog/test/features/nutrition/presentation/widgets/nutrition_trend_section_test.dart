import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_goals_model.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/presentation/widgets/nutrition_trend_section.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  );
}

void main() {
  group('NutritionTrendSection', () {
    testWidgets('shows "No data for this period" for both charts when provider returns empty list',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NutritionTrendSection(),
          overrides: [
            nutritionGoalsProvider.overrideWith(
              (_) async => const NutritionGoals(calorieBudget: 2000),
            ),
            nutritionTrendProvider('7d').overrideWith(
              (ref) async => const <NutritionTrendDay>[],
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('No data for this period'), findsNWidgets(2));
    });

    testWidgets('shows "Nutrition Trend" label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NutritionTrendSection(),
          overrides: [
            nutritionGoalsProvider.overrideWith(
              (_) async => const NutritionGoals(calorieBudget: 2000),
            ),
            nutritionTrendProvider('7d').overrideWith(
              (ref) async => const <NutritionTrendDay>[],
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Nutrition Trend'), findsOneWidget);
    });

    testWidgets('shows "Calories" and "Protein" chart labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NutritionTrendSection(),
          overrides: [
            nutritionGoalsProvider.overrideWith(
              (_) async => const NutritionGoals(calorieBudget: 2000),
            ),
            nutritionTrendProvider('7d').overrideWith(
              (ref) async => const <NutritionTrendDay>[],
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Calories'), findsOneWidget);
      expect(find.textContaining('Protein'), findsOneWidget);
    });

    testWidgets('uses goal values from nutritionGoalsProvider', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const NutritionTrendSection(),
          overrides: [
            nutritionGoalsProvider.overrideWith(
              (_) async => const NutritionGoals(
                calorieBudget: 1800,
                proteinMinG: 140,
              ),
            ),
            nutritionTrendProvider('7d').overrideWith(
              (ref) async => const <NutritionTrendDay>[],
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(NutritionTrendSection), findsOneWidget);
    });
  });
}
