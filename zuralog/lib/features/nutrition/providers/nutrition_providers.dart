/// ZuraLog — Nutrition Riverpod Providers.
///
/// All state for the Nutrition feature is managed here. Screens read from
/// these providers and trigger invalidations via [ref.invalidate] after
/// mutations (e.g. logging or deleting a meal).
///
/// Every async provider follows the **never-error** pattern: network and
/// parse failures are caught and resolved to safe empty/default values so the
/// UI always reaches the `data:` branch and never needs an error widget.
///
/// Provider inventory:
/// - [nutritionRepositoryProvider]  — singleton repository
/// - [todayMealsProvider]           — async list of today's meals
/// - [nutritionDaySummaryProvider]  — async aggregated day summary
/// - [mealDetailProvider]           — family: detail for a single meal by ID
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/nutrition/data/mock_nutrition_repository.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';

// -- Repository ---------------------------------------------------------------

/// Singleton [NutritionRepositoryInterface] for the nutrition feature.
///
/// Currently wired to the [MockNutritionRepository] for development. Swap to
/// the real API-backed implementation when the Cloud Brain nutrition endpoints
/// are ready.
final nutritionRepositoryProvider =
    Provider<NutritionRepositoryInterface>((ref) {
  return const MockNutritionRepository();
});

// -- Today Meals --------------------------------------------------------------

/// Async provider for the list of meals logged today.
///
/// Never puts the UI into an error state. All failures resolve to an empty
/// list so the UI always reaches the `data:` branch and renders the
/// appropriate empty state.
///
/// Invalidate with `ref.invalidate(todayMealsProvider)` after logging or
/// deleting a meal to trigger a fresh fetch.
final todayMealsProvider = FutureProvider<List<Meal>>((ref) async {
  final repo = ref.read(nutritionRepositoryProvider);
  try {
    return await repo.getTodayMeals();
  } catch (e, st) {
    debugPrint('todayMealsProvider failed: $e\n$st');
    return const [];
  }
});

// -- Day Summary --------------------------------------------------------------

/// Async provider for today's aggregated calorie and macro totals.
///
/// Never puts the UI into an error state. All failures resolve to
/// [NutritionDaySummary.empty] so the dashboard always has safe values
/// to display.
///
/// Invalidate alongside [todayMealsProvider] after any mutation.
final nutritionDaySummaryProvider =
    FutureProvider<NutritionDaySummary>((ref) async {
  final repo = ref.read(nutritionRepositoryProvider);
  try {
    return await repo.getTodaySummary();
  } catch (e, st) {
    debugPrint('nutritionDaySummaryProvider failed: $e\n$st');
    return NutritionDaySummary.empty;
  }
});

// -- Meal Detail --------------------------------------------------------------

/// Async family provider for a single meal's full detail.
///
/// Keyed by the meal [id] string. The detail screen uses
/// `ref.watch(mealDetailProvider(mealId))`.
///
/// Returns `null` for unknown IDs or on failure so the UI can show a
/// "not found" state without entering an error branch.
final mealDetailProvider =
    FutureProvider.family<Meal?, String>((ref, id) async {
  final repo = ref.read(nutritionRepositoryProvider);
  try {
    return await repo.getMealById(id);
  } catch (e, st) {
    debugPrint('mealDetailProvider($id) failed: $e\n$st');
    return null;
  }
});
