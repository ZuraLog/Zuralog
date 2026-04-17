/// ZuraLog — Nutrition Repository Interface & Mock Implementation.
///
/// Defines the contract that any nutrition data source must satisfy and
/// provides an in-memory mock implementation for development and testing.
///
/// The mock returns two realistic meals with today's date so every nutrition
/// widget path can be exercised without a running backend.
///
/// Type overview:
/// - [NutritionRepositoryInterface] — abstract contract for nutrition data
/// - [MockNutritionRepository]      — hardcoded fixture implementation
library;

import 'dart:io';

import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';

// -- NutritionRepositoryInterface ---------------------------------------------

/// Contract for fetching and managing nutrition data.
///
/// All methods are asynchronous to accommodate both local caches and remote
/// API calls. Implementations must never throw — callers rely on the
/// never-error pattern enforced at the provider layer.
abstract interface class NutritionRepositoryInterface {
  /// Returns every meal logged today, ordered by [Meal.loggedAt].
  Future<List<Meal>> getTodayMeals();

  /// Returns an aggregated calorie and macro summary for today.
  Future<NutritionDaySummary> getTodaySummary();

  /// Returns the meal matching [id], or `null` if no match exists.
  Future<Meal?> getMealById(String id);

  /// Deletes the meal matching [id]. No-op if the meal does not exist.
  Future<void> deleteMeal(String id);

  /// Create a new meal with food items.
  Future<Meal> createMeal({
    required String mealType,
    String? name,
    required DateTime loggedAt,
    required List<MealFood> foods,
  });

  /// Replace an existing meal entirely.
  Future<Meal> updateMeal(
    String id, {
    required String mealType,
    String? name,
    required DateTime loggedAt,
    required List<MealFood> foods,
  });

  /// Get the user's most recently logged foods.
  Future<List<RecentFood>> getRecentFoods();

  /// Search foods by name (cache-first, AI-fallback on backend).
  Future<List<FoodSearchResult>> searchFoods(String query, {int limit = 10});

  /// Parse a natural-language meal description into structured food items.
  ///
  /// [mode] is `'quick'` for a one-shot parse (no follow-up questions) or
  /// `'guided'` to also return guided walkthrough questions.
  Future<MealParseResult> parseMealDescription(
    String description, {
    required String mode,
  });

  /// Submit a correction for a food's nutrition values.
  Future<void> submitCorrection({
    required String foodName,
    required double originalCalories,
    required double correctedCalories,
    required double originalProteinG,
    required double correctedProteinG,
    required double originalCarbsG,
    required double correctedCarbsG,
    required double originalFatG,
    required double correctedFatG,
  });

  /// Analyse a food photo and return structured food items.
  ///
  /// [mode] is `'quick'` for a one-shot parse or `'guided'` to also return
  /// guided walkthrough questions.
  Future<MealParseResult> scanFoodImage(
    File imageFile, {
    required String mode,
  });

  /// Look up a product by its barcode (UPC/EAN).
  Future<FoodSearchResult?> lookupBarcode(String code);

  /// Returns all nutrition rules for the current user.
  Future<List<NutritionRule>> getRules();

  /// Creates a new nutrition rule with the given [ruleText].
  Future<NutritionRule> createRule(String ruleText);

  /// Updates an existing rule's text.
  Future<NutritionRule> updateRule(String ruleId, String ruleText);

  /// Deletes the rule matching [ruleId].
  Future<void> deleteRule(String ruleId);
}

// -- MockNutritionRepository --------------------------------------------------

/// Debug-only stub implementation of [NutritionRepositoryInterface].
///
/// Returns hardcoded fixture data after a short artificial delay so that
/// loading skeletons and populated states are both exercisable in development.
final class MockNutritionRepository implements NutritionRepositoryInterface {
  /// Creates a const [MockNutritionRepository].
  const MockNutritionRepository();

  /// Simulated network latency for read operations.
  static const Duration _readDelay = Duration(milliseconds: 400);

  /// Simulated network latency for write operations.
  static const Duration _writeDelay = Duration(milliseconds: 200);

  // -- Public API -------------------------------------------------------------

  @override
  Future<List<Meal>> getTodayMeals() async {
    await Future<void>.delayed(_readDelay);
    return _mockMeals();
  }

  @override
  Future<NutritionDaySummary> getTodaySummary() async {
    await Future<void>.delayed(_readDelay);
    final meals = _mockMeals();
    final totalCalories =
        meals.fold(0, (sum, meal) => sum + meal.totalCalories);
    final totalProtein =
        meals.fold(0.0, (sum, meal) => sum + meal.totalProtein);
    final totalCarbs = meals.fold(0.0, (sum, meal) => sum + meal.totalCarbs);
    final totalFat = meals.fold(0.0, (sum, meal) => sum + meal.totalFat);
    return NutritionDaySummary(
      totalCalories: totalCalories,
      totalProteinG: totalProtein,
      totalCarbsG: totalCarbs,
      totalFatG: totalFat,
      mealCount: meals.length,
    );
  }

  @override
  Future<Meal?> getMealById(String id) async {
    await Future<void>.delayed(_readDelay);
    final meals = _mockMeals();
    for (final meal in meals) {
      if (meal.id == id) return meal;
    }
    return null;
  }

  @override
  Future<void> deleteMeal(String id) async {
    await Future<void>.delayed(_writeDelay);
    // No-op: mock does not persist state.
  }

  @override
  Future<Meal> createMeal({
    required String mealType,
    String? name,
    required DateTime loggedAt,
    required List<MealFood> foods,
  }) =>
      throw UnimplementedError('Mock does not support createMeal');

  @override
  Future<Meal> updateMeal(
    String id, {
    required String mealType,
    String? name,
    required DateTime loggedAt,
    required List<MealFood> foods,
  }) =>
      throw UnimplementedError('Mock does not support updateMeal');

  @override
  Future<List<RecentFood>> getRecentFoods() =>
      throw UnimplementedError('Mock does not support getRecentFoods');

  @override
  Future<List<FoodSearchResult>> searchFoods(String query,
          {int limit = 10}) =>
      throw UnimplementedError('Mock does not support searchFoods');

  @override
  Future<MealParseResult> parseMealDescription(
    String description, {
    required String mode,
  }) =>
      throw UnimplementedError('Mock does not support parseMealDescription');

  @override
  Future<void> submitCorrection({
    required String foodName,
    required double originalCalories,
    required double correctedCalories,
    required double originalProteinG,
    required double correctedProteinG,
    required double originalCarbsG,
    required double correctedCarbsG,
    required double originalFatG,
    required double correctedFatG,
  }) =>
      throw UnimplementedError('Mock does not support submitCorrection');

  @override
  Future<MealParseResult> scanFoodImage(
    File imageFile, {
    required String mode,
  }) =>
      throw UnimplementedError('Mock does not support scanFoodImage');

  @override
  Future<FoodSearchResult?> lookupBarcode(String code) =>
      throw UnimplementedError('Mock does not support lookupBarcode');

  @override
  Future<List<NutritionRule>> getRules() =>
      throw UnimplementedError('Mock does not support getRules');

  @override
  Future<NutritionRule> createRule(String ruleText) =>
      throw UnimplementedError('Mock does not support createRule');

  @override
  Future<NutritionRule> updateRule(String ruleId, String ruleText) =>
      throw UnimplementedError('Mock does not support updateRule');

  @override
  Future<void> deleteRule(String ruleId) =>
      throw UnimplementedError('Mock does not support deleteRule');

  // -- Fixture Builder --------------------------------------------------------

  /// Builds the fixed list of mock meals using today's date.
  List<Meal> _mockMeals() {
    final today = DateTime.now();
    return [
      Meal(
        id: 'meal-1',
        name: 'Greek yogurt + berries',
        type: MealType.breakfast,
        loggedAt: DateTime(today.year, today.month, today.day, 8, 30),
        foods: const [
          MealFood(
            name: 'Greek yogurt',
            portionGrams: 150,
            caloriesKcal: 130,
            proteinG: 12,
            carbsG: 10,
            fatG: 5,
          ),
          MealFood(
            name: 'Mixed berries',
            portionGrams: 100,
            caloriesKcal: 57,
            proteinG: 0.7,
            carbsG: 14,
            fatG: 0.3,
          ),
          MealFood(
            name: 'Granola',
            portionGrams: 30,
            caloriesKcal: 133,
            proteinG: 3,
            carbsG: 18,
            fatG: 5.5,
          ),
        ],
      ),
      Meal(
        id: 'meal-2',
        name: 'Salmon poke bowl',
        type: MealType.lunch,
        loggedAt: DateTime(today.year, today.month, today.day, 12, 40),
        foods: const [
          MealFood(
            name: 'Salmon fillet',
            portionGrams: 120,
            caloriesKcal: 250,
            proteinG: 25,
            carbsG: 0,
            fatG: 16,
          ),
          MealFood(
            name: 'Sushi rice',
            portionGrams: 150,
            caloriesKcal: 195,
            proteinG: 4,
            carbsG: 44,
            fatG: 0.3,
          ),
          MealFood(
            name: 'Edamame',
            portionGrams: 50,
            caloriesKcal: 63,
            proteinG: 5.5,
            carbsG: 5,
            fatG: 2.5,
          ),
          MealFood(
            name: 'Avocado',
            portionGrams: 40,
            caloriesKcal: 64,
            proteinG: 0.8,
            carbsG: 3.4,
            fatG: 5.9,
          ),
        ],
      ),
    ];
  }
}
