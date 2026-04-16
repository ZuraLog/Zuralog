/// ZuraLog — Nutrition Domain Models.
///
/// Strongly-typed data models for the Nutrition feature. All models are
/// immutable with const constructors.
///
/// Model overview:
/// - [MealType]              — categorises a meal (breakfast, lunch, etc.)
/// - [MealFood]              — a single food item with macro breakdown
/// - [Meal]                  — a logged meal containing one or more foods
/// - [NutritionDaySummary]   — aggregated calorie and macro totals for a day
library;

import 'package:flutter/material.dart';

// -- MealType -----------------------------------------------------------------

/// The type of meal logged by the user.
///
/// Each value carries a human-readable [label] and a Material [icon] so that
/// UI code can display the meal type without a separate mapping.
enum MealType {
  /// Morning meal.
  breakfast,

  /// Midday meal.
  lunch,

  /// Evening meal.
  dinner,

  /// Between-meal snack.
  snack;

  /// Human-readable label with the first letter capitalised.
  String get label => switch (this) {
        MealType.breakfast => 'Breakfast',
        MealType.lunch => 'Lunch',
        MealType.dinner => 'Dinner',
        MealType.snack => 'Snack',
      };

  /// Material icon representing the meal type.
  IconData get icon => switch (this) {
        MealType.breakfast => Icons.wb_sunny_outlined,
        MealType.lunch => Icons.restaurant_outlined,
        MealType.dinner => Icons.nightlight_outlined,
        MealType.snack => Icons.cookie_outlined,
      };
}

// -- MealFood -----------------------------------------------------------------

/// A single food item within a [Meal].
///
/// Stores the portion size and full macronutrient breakdown so that the UI can
/// show per-item detail and the [Meal] can compute totals by folding over its
/// food list.
class MealFood {
  /// Creates an immutable [MealFood].
  const MealFood({
    required this.name,
    required this.portionGrams,
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  /// Human-readable food name (e.g. "Greek yogurt").
  final String name;

  /// Portion size in grams.
  final int portionGrams;

  /// Energy content in kilocalories.
  final int caloriesKcal;

  /// Protein content in grams.
  final double proteinG;

  /// Carbohydrate content in grams.
  final double carbsG;

  /// Fat content in grams.
  final double fatG;
}

// -- Meal ---------------------------------------------------------------------

/// A single logged meal composed of one or more [MealFood] items.
///
/// Provides computed getters that aggregate macros across all foods so the UI
/// never needs to perform its own summation.
class Meal {
  /// Creates an immutable [Meal].
  const Meal({
    required this.id,
    required this.name,
    required this.type,
    required this.loggedAt,
    required this.foods,
  });

  /// Unique identifier for this meal.
  final String id;

  /// Short description shown in the feed (e.g. "Greek yogurt + berries").
  final String name;

  /// Meal category (breakfast, lunch, dinner, snack).
  final MealType type;

  /// When the meal was logged.
  final DateTime loggedAt;

  /// Individual food items that make up this meal.
  final List<MealFood> foods;

  /// Total calories across all foods in this meal.
  int get totalCalories =>
      foods.fold(0, (sum, food) => sum + food.caloriesKcal);

  /// Total protein (grams) across all foods in this meal.
  double get totalProtein =>
      foods.fold(0.0, (sum, food) => sum + food.proteinG);

  /// Total carbohydrates (grams) across all foods in this meal.
  double get totalCarbs => foods.fold(0.0, (sum, food) => sum + food.carbsG);

  /// Total fat (grams) across all foods in this meal.
  double get totalFat => foods.fold(0.0, (sum, food) => sum + food.fatG);
}

// -- NutritionDaySummary ------------------------------------------------------

/// Aggregated nutrition totals for a single day.
///
/// Used by the nutrition dashboard to show daily calorie and macro progress.
class NutritionDaySummary {
  /// Creates an immutable [NutritionDaySummary].
  const NutritionDaySummary({
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.mealCount,
  });

  /// Total kilocalories consumed today.
  final int totalCalories;

  /// Total protein consumed today (grams).
  final double totalProteinG;

  /// Total carbohydrates consumed today (grams).
  final double totalCarbsG;

  /// Total fat consumed today (grams).
  final double totalFatG;

  /// Number of meals logged today.
  final int mealCount;

  /// An empty summary with all values at zero.
  static const empty = NutritionDaySummary(
    totalCalories: 0,
    totalProteinG: 0,
    totalCarbsG: 0,
    totalFatG: 0,
    mealCount: 0,
  );
}
