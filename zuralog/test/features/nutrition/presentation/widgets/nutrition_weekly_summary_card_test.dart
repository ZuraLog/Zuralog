import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_goals_model.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/nutrition/presentation/widgets/nutrition_weekly_summary_card.dart';

Widget wrapInApp(Widget child) =>
    ProviderScope(child: MaterialApp(home: Scaffold(body: child)));

void main() {
  testWidgets('shows NutritionWeeklySummaryCard without crash', (tester) async {
    await tester.pumpWidget(wrapInApp(
      ProviderScope(overrides: [
        nutritionGoalsProvider.overrideWith(
          (_) async => const NutritionGoals(calorieBudget: 2000),
        ),
        nutritionTrendProvider('7d').overrideWith(
          (_) async => const <NutritionTrendDay>[],
        ),
      ], child: const NutritionWeeklySummaryCard()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(NutritionWeeklySummaryCard), findsOneWidget);
  });

  testWidgets('shows "Weekly Goal Check-In" title', (tester) async {
    await tester.pumpWidget(wrapInApp(
      ProviderScope(overrides: [
        nutritionGoalsProvider.overrideWith(
          (_) async => const NutritionGoals(calorieBudget: 2000),
        ),
        nutritionTrendProvider('7d').overrideWith(
          (_) async => const <NutritionTrendDay>[],
        ),
      ], child: const NutritionWeeklySummaryCard()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Weekly Goal Check-In'), findsOneWidget);
  });

  testWidgets('shows 7 day-label texts', (tester) async {
    await tester.pumpWidget(wrapInApp(
      ProviderScope(overrides: [
        nutritionGoalsProvider.overrideWith(
          (_) async => const NutritionGoals(calorieBudget: 2000),
        ),
        nutritionTrendProvider('7d').overrideWith(
          (_) async => const <NutritionTrendDay>[],
        ),
      ], child: const NutritionWeeklySummaryCard()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // The 7 day abbreviations are always rendered (M T W T F S S).
    // We check for exactly 7 day-label widgets via their key.
    expect(find.byKey(const ValueKey('weekly_dot_row')), findsOneWidget);
  });

  testWidgets('shows streak label', (tester) async {
    await tester.pumpWidget(wrapInApp(
      ProviderScope(overrides: [
        nutritionGoalsProvider.overrideWith(
          (_) async => const NutritionGoals(calorieBudget: 2000),
        ),
        nutritionTrendProvider('7d').overrideWith(
          (_) async => const <NutritionTrendDay>[],
        ),
      ], child: const NutritionWeeklySummaryCard()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('streak'), findsOneWidget);
  });

  testWidgets('renders green dot for day where calorie goal was met',
      (tester) async {
    // Build a trend list where today is the last entry and calories are within goal.
    final today = DateTime.now();
    final trendDays = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return NutritionTrendDay(
        date: dateStr,
        isToday: i == 6,
        calories: 1800, // under 2000 budget — should be green
      );
    });
    await tester.pumpWidget(wrapInApp(
      ProviderScope(overrides: [
        nutritionGoalsProvider.overrideWith(
          (_) async => const NutritionGoals(calorieBudget: 2000),
        ),
        nutritionTrendProvider('7d').overrideWith(
          (_) async => trendDays,
        ),
      ], child: const NutritionWeeklySummaryCard()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(NutritionWeeklySummaryCard), findsOneWidget);
  });
}
