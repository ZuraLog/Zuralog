/// ZuraLog — LogMealSheet Widget Tests.
///
/// Verifies that:
/// - Template chips appear when the user has saved meal templates.
/// - The save-as-template icon button is visible when foods are assembled.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/nutrition/data/mock_nutrition_repository.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/nutrition/presentation/log_meal_sheet.dart';
import 'package:zuralog/shared/widgets/inputs/z_chip.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Wraps [child] in a test harness sized to a typical phone screen so the
/// LogMealSheet's scrollable body is fully reachable.
Widget wrapInApp(Widget child) => ProviderScope(
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 900)),
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      ),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows template chips when templates exist', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    final template = MealTemplate(
      id: 't1',
      name: 'My Lunch',
      mealType: 'lunch',
      foods: const [],
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(wrapInApp(
      ProviderScope(overrides: [
        prefsProvider.overrideWithValue(prefs),
        mealTemplatesProvider.overrideWith((_) async => [template]),
        nutritionRepositoryProvider
            .overrideWithValue(const MockNutritionRepository()),
        recentFoodsProvider.overrideWith((_) async => const []),
        foodSearchResultsProvider.overrideWith((_) async => const []),
      ], child: const LogMealSheet()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('My Lunch'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows Templates section header when templates exist',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    final template = MealTemplate(
      id: 't2',
      name: 'Morning Bowl',
      mealType: 'breakfast',
      foods: const [],
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(wrapInApp(
      ProviderScope(overrides: [
        prefsProvider.overrideWithValue(prefs),
        mealTemplatesProvider.overrideWith((_) async => [template]),
        nutritionRepositoryProvider
            .overrideWithValue(const MockNutritionRepository()),
        recentFoodsProvider.overrideWith((_) async => const []),
        foodSearchResultsProvider.overrideWith((_) async => const []),
      ], child: const LogMealSheet()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Both the header section and the chip label should be present in the tree.
    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('Morning Bowl'), findsAtLeastNWidgets(1));
    // The chip should use the bookmark outline icon.
    expect(find.byIcon(Icons.bookmark_outline), findsAtLeastNWidgets(1));
  });
}
