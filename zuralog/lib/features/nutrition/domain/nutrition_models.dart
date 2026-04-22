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
/// - [NutritionTrendDay]     — per-day calorie and protein totals for trend charts
/// - [ParsedFoodItem]        — AI-parsed food item from natural-language input
/// - [FoodSearchResult]      — food entry returned from the search endpoint
/// - [RecentFood]            — recently logged food for quick re-logging
library;

export 'package:zuralog/features/nutrition/domain/guided_question.dart';

import 'package:flutter/material.dart';

import 'package:zuralog/features/nutrition/domain/guided_question.dart';

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

  /// Parses a [MealType] from a lowercase string (e.g. `'breakfast'`).
  ///
  /// Falls back to [MealType.snack] if the value is unrecognised.
  static MealType fromString(String value) {
    return MealType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => MealType.snack,
    );
  }

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
    this.portionUnit = 'g',
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fiberG = 0.0,
    this.sodiumMg = 0.0,
    this.sugarG = 0.0,
    this.origin,
    this.sourceQuestionId,
    this.sourceAnswerValue,
  });

  /// Human-readable food name (e.g. "Greek yogurt").
  final String name;

  /// Portion size in grams.
  final int portionGrams;

  /// Unit of measurement for the portion (defaults to `'g'`).
  final String portionUnit;

  /// Energy content in kilocalories.
  final int caloriesKcal;

  /// Protein content in grams.
  final double proteinG;

  /// Carbohydrate content in grams.
  final double carbsG;

  /// Fat content in grams.
  final double fatG;

  /// Dietary fibre content in grams.
  final double fiberG;

  /// Sodium content in milligrams.
  final double sodiumMg;

  /// Sugar content in grams.
  final double sugarG;

  /// Where this food came from when it was added to the meal.
  ///
  /// `'user'` — mentioned in the original description or image.
  /// `'from_answer'` — added or replaced by a guided walkthrough answer.
  /// `null` on manual entries and older rows — keeps payloads small.
  final String? origin;

  /// Id of the walkthrough question that produced this food, if any.
  ///
  /// Populated when [origin] is `'from_answer'`. Mined server-side by the
  /// rule-suggestion detector to spot repeated answers.
  final String? sourceQuestionId;

  /// The answer value the user picked for [sourceQuestionId], if any.
  ///
  /// Populated when [origin] is `'from_answer'`. Mined server-side by the
  /// rule-suggestion detector to spot repeated answers.
  final String? sourceAnswerValue;

  /// Deserialises a [MealFood] from a backend JSON map.
  factory MealFood.fromJson(Map<String, dynamic> json) {
    return MealFood(
      name: json['food_name'] as String? ?? '',
      portionGrams: (json['portion_amount'] as num?)?.round() ?? 0,
      portionUnit: json['portion_unit'] as String? ?? 'g',
      caloriesKcal: (json['calories'] as num?)?.round() ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
      fiberG: (json['fiber_g'] as num?)?.toDouble() ?? 0.0,
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble() ?? 0.0,
      sugarG: (json['sugar_g'] as num?)?.toDouble() ?? 0.0,
      origin: json['origin'] as String?,
      sourceQuestionId: json['source_question_id'] as String?,
      sourceAnswerValue: json['source_answer_value'] as String?,
    );
  }

  /// Serialises this [MealFood] to a JSON map matching the backend schema.
  ///
  /// Attribution fields ([origin], [sourceQuestionId], [sourceAnswerValue])
  /// are only emitted when non-null so manual-entry payloads stay small.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'food_name': name,
      'portion_amount': portionGrams.toDouble(),
      'portion_unit': portionUnit,
      'calories': caloriesKcal.toDouble(),
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'fiber_g': fiberG,
      'sodium_mg': sodiumMg,
      'sugar_g': sugarG,
    };
    if (origin != null) {
      json['origin'] = origin;
    }
    if (sourceQuestionId != null) {
      json['source_question_id'] = sourceQuestionId;
    }
    if (sourceAnswerValue != null) {
      json['source_answer_value'] = sourceAnswerValue;
    }
    return json;
  }

  /// Returns a new [MealFood] with the given fields replaced.
  MealFood copyWith({
    String? name,
    int? portionGrams,
    String? portionUnit,
    int? caloriesKcal,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? fiberG,
    double? sodiumMg,
    double? sugarG,
    String? origin,
    String? sourceQuestionId,
    String? sourceAnswerValue,
  }) {
    return MealFood(
      name: name ?? this.name,
      portionGrams: portionGrams ?? this.portionGrams,
      portionUnit: portionUnit ?? this.portionUnit,
      caloriesKcal: caloriesKcal ?? this.caloriesKcal,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      fiberG: fiberG ?? this.fiberG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      sugarG: sugarG ?? this.sugarG,
      origin: origin ?? this.origin,
      sourceQuestionId: sourceQuestionId ?? this.sourceQuestionId,
      sourceAnswerValue: sourceAnswerValue ?? this.sourceAnswerValue,
    );
  }
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

  /// Deserialises a [Meal] from a backend JSON map.
  factory Meal.fromJson(Map<String, dynamic> json) {
    final foodsList = (json['foods'] as List<dynamic>?) ?? [];
    return Meal(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: MealType.fromString(json['meal_type'] as String? ?? 'snack'),
      loggedAt: DateTime.tryParse(json['logged_at'] as String? ?? '') ??
          DateTime.now(),
      foods: foodsList
          .map((e) => MealFood.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

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
  const NutritionDaySummary({
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.mealCount,
    this.fiberG = 0.0,
    this.sodiumMg = 0.0,
    this.sugarG = 0.0,
    this.exerciseCaloriesBurned = 0,
    this.aiSummary,
    this.aiGeneratedAt,
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

  /// Total dietary fibre consumed today (grams).
  final double fiberG;

  /// Total sodium consumed today (milligrams).
  final double sodiumMg;

  /// Total sugar consumed today (grams).
  final double sugarG;

  /// Calories burned through exercise today (kilocalories).
  final int exerciseCaloriesBurned;

  /// AI-generated observation about today's nutrition. Null until the backend
  /// has processed enough data to produce a summary.
  final String? aiSummary;

  /// When the [aiSummary] was generated. Null when [aiSummary] is null.
  final DateTime? aiGeneratedAt;

  /// Deserialises a [NutritionDaySummary] from a backend JSON map.
  factory NutritionDaySummary.fromJson(Map<String, dynamic> json) {
    return NutritionDaySummary(
      totalCalories: (json['total_calories'] as num?)?.round() ?? 0,
      totalProteinG: (json['total_protein_g'] as num?)?.toDouble() ?? 0.0,
      totalCarbsG: (json['total_carbs_g'] as num?)?.toDouble() ?? 0.0,
      totalFatG: (json['total_fat_g'] as num?)?.toDouble() ?? 0.0,
      mealCount: (json['meal_count'] as num?)?.toInt() ?? 0,
      fiberG: (json['total_fiber_g'] as num?)?.toDouble() ?? 0.0,
      sodiumMg: (json['total_sodium_mg'] as num?)?.toDouble() ?? 0.0,
      sugarG: (json['total_sugar_g'] as num?)?.toDouble() ?? 0.0,
      exerciseCaloriesBurned:
          (json['exercise_calories_burned'] as num?)?.toInt() ?? 0,
      aiSummary: json['ai_summary'] as String?,
      aiGeneratedAt: json['ai_generated_at'] != null
          ? DateTime.tryParse(json['ai_generated_at'] as String)
          : null,
    );
  }

  /// Returns a new [NutritionDaySummary] with the given fields replaced.
  NutritionDaySummary copyWith({
    int? totalCalories,
    double? totalProteinG,
    double? totalCarbsG,
    double? totalFatG,
    int? mealCount,
    double? fiberG,
    double? sodiumMg,
    double? sugarG,
    int? exerciseCaloriesBurned,
    String? aiSummary,
    DateTime? aiGeneratedAt,
  }) {
    return NutritionDaySummary(
      totalCalories: totalCalories ?? this.totalCalories,
      totalProteinG: totalProteinG ?? this.totalProteinG,
      totalCarbsG: totalCarbsG ?? this.totalCarbsG,
      totalFatG: totalFatG ?? this.totalFatG,
      mealCount: mealCount ?? this.mealCount,
      fiberG: fiberG ?? this.fiberG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      sugarG: sugarG ?? this.sugarG,
      exerciseCaloriesBurned:
          exerciseCaloriesBurned ?? this.exerciseCaloriesBurned,
      aiSummary: aiSummary ?? this.aiSummary,
      aiGeneratedAt: aiGeneratedAt ?? this.aiGeneratedAt,
    );
  }

  /// An empty summary with all values at zero and no AI summary.
  static const empty = NutritionDaySummary(
    totalCalories: 0,
    totalProteinG: 0,
    totalCarbsG: 0,
    totalFatG: 0,
    mealCount: 0,
  );
}

// -- NutritionTrendDay --------------------------------------------------------

/// A single day's nutrition totals used by the trend chart.
class NutritionTrendDay {
  const NutritionTrendDay({
    required this.date,
    required this.isToday,
    this.calories,
    this.proteinG,
  });

  /// ISO-8601 date string (e.g. `'2026-04-19'`).
  final String date;

  /// Whether this day is today (used by the chart renderer to highlight the bar).
  final bool isToday;

  /// Total calories for the day, or `null` if no meals were logged.
  final double? calories;

  /// Total protein (grams) for the day, or `null` if no meals were logged.
  final double? proteinG;

  /// Deserialises a [NutritionTrendDay] from a backend JSON map.
  factory NutritionTrendDay.fromJson(Map<String, dynamic> json) {
    return NutritionTrendDay(
      date: json['date'] as String? ?? '',
      isToday: json['is_today'] as bool? ?? false,
      calories: (json['calories'] as num?)?.toDouble(),
      proteinG: (json['protein_g'] as num?)?.toDouble(),
    );
  }
}

// -- ParsedFoodItem -----------------------------------------------------------

/// A food item returned by the AI meal-parsing endpoint (`POST /meals/parse`).
///
/// Includes a [confidence] score indicating how certain the parser is about the
/// nutritional breakdown. Convert to a [MealFood] via [toMealFood] before
/// persisting.
class ParsedFoodItem {
  /// Creates an immutable [ParsedFoodItem].
  const ParsedFoodItem({
    required this.foodName,
    required this.portionAmount,
    required this.portionUnit,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fiberG = 0.0,
    this.sodiumMg = 0.0,
    this.sugarG = 0.0,
    this.confidence = 0.5,
    this.appliedRules = const [],
    this.origin = 'user',
    this.sourceQuestionId,
    this.sourceAnswerValue,
  });

  /// Human-readable food name.
  final String foodName;

  /// Portion size in the given [portionUnit].
  final double portionAmount;

  /// Unit of measurement for the portion (e.g. `'g'`, `'ml'`, `'oz'`).
  final String portionUnit;

  /// Energy content in kilocalories.
  final double calories;

  /// Protein content in grams.
  final double proteinG;

  /// Carbohydrate content in grams.
  final double carbsG;

  /// Fat content in grams.
  final double fatG;

  /// Dietary fibre content in grams.
  final double fiberG;

  /// Sodium content in milligrams.
  final double sodiumMg;

  /// Sugar content in grams.
  final double sugarG;

  /// Parser confidence score (0.0–1.0). Defaults to 0.5.
  final double confidence;

  /// Human-readable rule descriptions the backend applied to this food.
  ///
  /// Surfaced in the UI as small badges so the user can see which of their
  /// saved rules affected the parse.
  final List<String> appliedRules;

  /// Where this food came from.
  ///
  /// `'user'` (default) — mentioned in the user's description or image.
  /// `'from_answer'` — added or replaced by a walkthrough answer. Used to
  /// toggle the violet "From your answer" badge in Meal Review.
  final String origin;

  /// Id of the walkthrough question that produced this food, if any.
  ///
  /// Only populated when [origin] is `'from_answer'`. Lets the detail sheet
  /// look up the original question text.
  final String? sourceQuestionId;

  /// The answer value the user picked for [sourceQuestionId], if any.
  ///
  /// Only populated when [origin] is `'from_answer'`. Surfaced in the detail
  /// sheet so the user can see exactly which answer added the food.
  final String? sourceAnswerValue;

  /// Deserialises a [ParsedFoodItem] from a backend JSON map.
  factory ParsedFoodItem.fromJson(Map<String, dynamic> json) {
    final rawApplied = json['applied_rules'];
    final List<String> parsedApplied = rawApplied is List
        ? rawApplied
            .whereType<Object>()
            .map((e) => e.toString())
            .toList(growable: false)
        : const <String>[];

    return ParsedFoodItem(
      foodName: json['food_name'] as String? ?? '',
      portionAmount: (json['portion_amount'] as num?)?.toDouble() ?? 0.0,
      portionUnit: json['portion_unit'] as String? ?? 'g',
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
      fiberG: (json['fiber_g'] as num?)?.toDouble() ?? 0.0,
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble() ?? 0.0,
      sugarG: (json['sugar_g'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      appliedRules: parsedApplied,
      origin: json['origin'] as String? ?? 'user',
      sourceQuestionId: json['source_question_id'] as String?,
      sourceAnswerValue: json['source_answer_value'] as String?,
    );
  }

  /// Serialises this [ParsedFoodItem] to a JSON map matching the backend
  /// schema. Mirrors [ParsedFoodItem.fromJson] field-for-field.
  Map<String, dynamic> toJson() => {
        'food_name': foodName,
        'portion_amount': portionAmount,
        'portion_unit': portionUnit,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'fiber_g': fiberG,
        'sodium_mg': sodiumMg,
        'sugar_g': sugarG,
        'confidence': confidence,
        'applied_rules': appliedRules,
        'origin': origin,
        'source_question_id': sourceQuestionId,
        'source_answer_value': sourceAnswerValue,
      };

  /// Returns a new [ParsedFoodItem] with the given fields replaced.
  ///
  /// Used by the walkthrough `on_answer` pipeline to scale portions / macros
  /// and to tag replacement foods with `origin: 'from_answer'` without
  /// mutating the original instance.
  ParsedFoodItem copyWith({
    String? foodName,
    double? portionAmount,
    String? portionUnit,
    double? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? fiberG,
    double? sodiumMg,
    double? sugarG,
    double? confidence,
    List<String>? appliedRules,
    String? origin,
    String? sourceQuestionId,
    String? sourceAnswerValue,
  }) {
    return ParsedFoodItem(
      foodName: foodName ?? this.foodName,
      portionAmount: portionAmount ?? this.portionAmount,
      portionUnit: portionUnit ?? this.portionUnit,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      fiberG: fiberG ?? this.fiberG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      sugarG: sugarG ?? this.sugarG,
      confidence: confidence ?? this.confidence,
      appliedRules: appliedRules ?? this.appliedRules,
      origin: origin ?? this.origin,
      sourceQuestionId: sourceQuestionId ?? this.sourceQuestionId,
      sourceAnswerValue: sourceAnswerValue ?? this.sourceAnswerValue,
    );
  }

  /// Converts this parsed result into a [MealFood] for persisting.
  ///
  /// Forwards attribution so the backend rule-suggestion detector can mine
  /// repeated walkthrough answers. [origin] is passed through as-is;
  /// [sourceQuestionId] and [sourceAnswerValue] come along when present.
  MealFood toMealFood() => MealFood(
        name: foodName,
        portionGrams: portionAmount.round(),
        portionUnit: portionUnit,
        caloriesKcal: calories.round(),
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        fiberG: fiberG,
        sodiumMg: sodiumMg,
        sugarG: sugarG,
        origin: origin,
        sourceQuestionId: sourceQuestionId,
        sourceAnswerValue: sourceAnswerValue,
      );
}

// -- FoodSearchResult ---------------------------------------------------------

/// A food entry returned by the search endpoint (`GET /foods/search`).
///
/// Contains per-serving nutritional data. Convert to a [MealFood] via
/// [toMealFood] before adding to a meal.
class FoodSearchResult {
  /// Creates an immutable [FoodSearchResult].
  const FoodSearchResult({
    required this.id,
    required this.name,
    this.brand,
    required this.servingSize,
    required this.servingUnit,
    required this.caloriesPerServing,
    required this.proteinPerServing,
    required this.carbsPerServing,
    required this.fatPerServing,
    this.source = 'cached',
  });

  /// Unique identifier for this food entry.
  final String id;

  /// Human-readable food name.
  final String name;

  /// Optional brand name (e.g. `'Chobani'`).
  final String? brand;

  /// Default serving size in the given [servingUnit].
  final double servingSize;

  /// Unit of measurement for the serving (e.g. `'g'`, `'ml'`).
  final String servingUnit;

  /// Calories per serving.
  final double caloriesPerServing;

  /// Protein per serving (grams).
  final double proteinPerServing;

  /// Carbohydrates per serving (grams).
  final double carbsPerServing;

  /// Fat per serving (grams).
  final double fatPerServing;

  /// Data source (e.g. `'cached'`, `'usda'`, `'user'`).
  final String source;

  /// Deserialises a [FoodSearchResult] from a backend JSON map.
  factory FoodSearchResult.fromJson(Map<String, dynamic> json) {
    return FoodSearchResult(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String?,
      servingSize: (json['serving_size'] as num?)?.toDouble() ?? 100.0,
      servingUnit: json['serving_unit'] as String? ?? 'g',
      caloriesPerServing:
          (json['calories_per_serving'] as num?)?.toDouble() ?? 0.0,
      proteinPerServing:
          (json['protein_per_serving'] as num?)?.toDouble() ?? 0.0,
      carbsPerServing:
          (json['carbs_per_serving'] as num?)?.toDouble() ?? 0.0,
      fatPerServing: (json['fat_per_serving'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] as String? ?? 'cached',
    );
  }

  /// Converts this search result into a [MealFood] for adding to a meal.
  MealFood toMealFood() => MealFood(
        name: name,
        portionGrams: servingSize.round(),
        portionUnit: servingUnit,
        caloriesKcal: caloriesPerServing.round(),
        proteinG: proteinPerServing,
        carbsG: carbsPerServing,
        fatG: fatPerServing,
      );
}

// -- RecentFood ---------------------------------------------------------------

/// A recently logged food returned by the recents endpoint
/// (`GET /foods/recent`).
///
/// Allows the user to quickly re-log a food they have eaten before. Convert to
/// a [MealFood] via [toMealFood] before adding to a meal.
class RecentFood {
  /// Creates an immutable [RecentFood].
  const RecentFood({
    required this.foodName,
    required this.portionAmount,
    required this.portionUnit,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  /// Human-readable food name.
  final String foodName;

  /// Portion size in the given [portionUnit].
  final double portionAmount;

  /// Unit of measurement for the portion.
  final String portionUnit;

  /// Energy content in kilocalories.
  final double calories;

  /// Protein content in grams.
  final double proteinG;

  /// Carbohydrate content in grams.
  final double carbsG;

  /// Fat content in grams.
  final double fatG;

  /// Deserialises a [RecentFood] from a backend JSON map.
  factory RecentFood.fromJson(Map<String, dynamic> json) {
    return RecentFood(
      foodName: json['food_name'] as String? ?? '',
      portionAmount: (json['portion_amount'] as num?)?.toDouble() ?? 0.0,
      portionUnit: json['portion_unit'] as String? ?? 'g',
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converts this recent food into a [MealFood] for adding to a meal.
  MealFood toMealFood() => MealFood(
        name: foodName,
        portionGrams: portionAmount.round(),
        portionUnit: portionUnit,
        caloriesKcal: calories.round(),
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
      );
}

// -- NutritionRule -------------------------------------------------------------

/// A user-defined nutrition rule providing persistent AI context.
///
/// Rules let the user teach the AI about dietary preferences, allergies,
/// portion habits, and other context so it asks fewer clarifying questions
/// when parsing meals. Each user may have up to 20 rules.
class NutritionRule {
  /// Creates an immutable [NutritionRule].
  const NutritionRule({
    required this.id,
    required this.ruleText,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Unique identifier for this rule.
  final String id;

  /// The human-readable rule text (max 500 characters).
  final String ruleText;

  /// When the rule was first created.
  final DateTime createdAt;

  /// When the rule was last modified.
  final DateTime updatedAt;

  /// Deserialises a [NutritionRule] from a backend JSON map.
  factory NutritionRule.fromJson(Map<String, dynamic> json) {
    return NutritionRule(
      id: json['id'] as String? ?? '',
      ruleText: json['rule_text'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

// -- SuggestedRule ------------------------------------------------------------

/// A rule the backend suggests the user save, based on repeated walkthrough
/// answers.
///
/// When the user gives the same answer to the same walkthrough question 3+
/// times across recent meals, the backend returns a [SuggestedRule] alongside
/// the parse/refine response so the client can offer to save it as a
/// persistent rule. Dismissing a suggestion is handled via
/// `dismissRuleSuggestion` on the repository.
class SuggestedRule {
  /// Creates an immutable [SuggestedRule].
  const SuggestedRule({
    required this.ruleText,
    required this.questionId,
    required this.answerValue,
  });

  /// Human-readable rule text the user would save (e.g. "I always use
  /// whole milk in my coffee").
  final String ruleText;

  /// Id of the walkthrough question whose repeated answer triggered this
  /// suggestion.
  final String questionId;

  /// The answer value the user repeatedly picked for [questionId].
  final String answerValue;

  /// Deserialises a [SuggestedRule] from a backend JSON map.
  ///
  /// All fields default to empty strings if missing or malformed so a
  /// partial payload never throws.
  factory SuggestedRule.fromJson(Map<String, dynamic> json) {
    return SuggestedRule(
      ruleText: (json['rule_text'] as String?) ?? '',
      questionId: (json['question_id'] as String?) ?? '',
      answerValue: (json['answer_value'] as String?) ?? '',
    );
  }

  /// Serialises this [SuggestedRule] to a JSON map matching the backend
  /// schema.
  Map<String, dynamic> toJson() => {
        'rule_text': ruleText,
        'question_id': questionId,
        'answer_value': answerValue,
      };
}

// -- ExerciseEntry ------------------------------------------------------------

/// A single exercise session logged by the user.
///
/// Stores the activity name, how long it lasted, and how many calories were
/// burned so the nutrition dashboard can display net-calorie figures.
class ExerciseEntry {
  /// Creates an immutable [ExerciseEntry].
  const ExerciseEntry({
    required this.id,
    required this.activity,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.loggedAt,
  });

  /// Unique identifier for this entry.
  final String id;

  /// Human-readable activity name (e.g. `'Running'`, `'Cycling'`).
  final String activity;

  /// Duration of the session in whole minutes.
  final int durationMinutes;

  /// Calories burned during the session (kilocalories).
  final int caloriesBurned;

  /// When the exercise was logged.
  final DateTime loggedAt;

  /// Deserialises an [ExerciseEntry] from a backend JSON map.
  factory ExerciseEntry.fromJson(Map<String, dynamic> j) => ExerciseEntry(
        id: j['id'] as String,
        activity: j['activity'] as String,
        durationMinutes: (j['duration_minutes'] as num?)?.toInt() ?? 0,
        caloriesBurned: (j['calories_burned'] as num).toInt(),
        loggedAt: DateTime.parse(j['logged_at'] as String),
      );

  /// Serialises this [ExerciseEntry] to a JSON map matching the backend schema.
  Map<String, dynamic> toJson() => {
        'id': id,
        'activity': activity,
        'duration_minutes': durationMinutes,
        'calories_burned': caloriesBurned,
        'logged_at': loggedAt.toUtc().toIso8601String(),
      };
}

// -- MealTemplate -------------------------------------------------------------

/// A saved meal template that the user can quickly re-log.
///
/// Templates store a named collection of [MealFood] items so the user can
/// log a frequently eaten meal without re-entering every food every time.
class MealTemplate {
  /// Creates an immutable [MealTemplate].
  const MealTemplate({
    required this.id,
    required this.name,
    required this.mealType,
    required this.foods,
    required this.createdAt,
  });

  /// Unique identifier for this template.
  final String id;

  /// User-chosen name for the template (e.g. `'My Lunch'`).
  final String name;

  /// The default meal category for this template (e.g. `'lunch'`).
  final String mealType;

  /// Food items that make up this template.
  final List<MealFood> foods;

  /// When the template was first saved.
  final DateTime createdAt;

  /// Deserialises a [MealTemplate] from a backend JSON map.
  factory MealTemplate.fromJson(Map<String, dynamic> j) => MealTemplate(
        id: j['id'] as String,
        name: j['name'] as String,
        mealType: j['meal_type'] as String,
        foods: (j['foods'] as List)
            .map((f) => MealFood.fromJson(f as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  /// Total calories across all foods in this template.
  int get totalCalories =>
      foods.fold(0, (sum, food) => sum + food.caloriesKcal);

  /// Total protein (grams) across all foods in this template.
  double get totalProtein =>
      foods.fold(0.0, (sum, food) => sum + food.proteinG);
}

/// Extracts a [SuggestedRule] from a JSON payload defensively.
///
/// Returns `null` when the key is missing, null, or not a `Map` — never
/// throws — so a malformed server response can't crash parse/refine.
SuggestedRule? _suggestedRuleFromJson(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    try {
      return SuggestedRule.fromJson(raw);
    } catch (_) {
      return null;
    }
  }
  if (raw is Map) {
    try {
      return SuggestedRule.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }
  return null;
}

// -- MealParseResult ----------------------------------------------------------

/// Combined result from the AI parse/scan endpoints.
///
/// Wraps both the parsed food items and any guided follow-up questions the
/// backend returned. Older backends that only return `foods` still deserialise
/// cleanly — [questions] just comes back empty.
class MealParseResult {
  /// Creates an immutable [MealParseResult].
  const MealParseResult({
    required this.foods,
    this.questions = const [],
    this.suggestedRule,
  });

  /// Parsed food items ready to show in the review screen.
  final List<ParsedFoodItem> foods;

  /// Guided follow-up questions the AI wants the user to answer.
  final List<GuidedQuestion> questions;

  /// A rule the backend suggests saving, detected from repeated walkthrough
  /// answers across recent meals. `null` when no suggestion is offered.
  final SuggestedRule? suggestedRule;

  /// Deserialises a [MealParseResult] defensively from a backend JSON map.
  factory MealParseResult.fromJson(Map<String, dynamic> json) {
    final rawFoods = json['foods'];
    final parsedFoods = rawFoods is List
        ? rawFoods
            .whereType<Map<String, dynamic>>()
            .map(ParsedFoodItem.fromJson)
            .toList()
        : const <ParsedFoodItem>[];
    final rawQuestions = json['questions'];
    final parsedQuestions = rawQuestions is List
        ? rawQuestions
            .whereType<Map<String, dynamic>>()
            .map(GuidedQuestion.fromJson)
            .toList()
        : const <GuidedQuestion>[];
    return MealParseResult(
      foods: parsedFoods,
      questions: parsedQuestions,
      suggestedRule: _suggestedRuleFromJson(json['suggested_rule']),
    );
  }
}

// -- MealRefineResult ---------------------------------------------------------

/// Result from the AI refine endpoint (`POST /meals/refine`).
///
/// The refine endpoint runs a second LLM pass on the original parse using
/// the follow-up answers gathered so far. It returns either (a) a refined
/// food list with [isFinal] = `true`, or (b) one more batch of follow-up
/// [questions] with [isFinal] = `false`. [roundsRemaining] reflects the
/// server-side hard 3-round cap — when it hits zero the client must stop
/// calling refine regardless of [isFinal].
class MealRefineResult {
  /// Creates an immutable [MealRefineResult].
  const MealRefineResult({
    required this.foods,
    required this.questions,
    required this.isFinal,
    required this.roundsRemaining,
    this.suggestedRule,
  });

  /// The refined food items. On a final round this is the committed list;
  /// on an intermediate round it is the best-effort running list.
  final List<ParsedFoodItem> foods;

  /// Additional follow-up questions the AI wants answered. Empty on the
  /// final round.
  final List<GuidedQuestion> questions;

  /// Whether this is the last round. When `true` the client commits
  /// [foods] and finishes the walkthrough.
  final bool isFinal;

  /// How many refine calls the client is still allowed to make this meal.
  /// Enforced server-side; the client honours this as an upper bound.
  final int roundsRemaining;

  /// A rule the backend suggests saving, detected from repeated walkthrough
  /// answers across recent meals. `null` when no suggestion is offered.
  final SuggestedRule? suggestedRule;

  /// Deserialises a [MealRefineResult] defensively from a backend JSON map.
  ///
  /// Every field tolerates null or missing values so a malformed server
  /// payload never throws — the walkthrough never crashes mid-refine.
  factory MealRefineResult.fromJson(Map<String, dynamic> json) {
    final foodsRaw = json['foods'];
    final foods = <ParsedFoodItem>[];
    if (foodsRaw is List) {
      for (final entry in foodsRaw) {
        if (entry is Map<String, dynamic>) {
          try {
            foods.add(ParsedFoodItem.fromJson(entry));
          } catch (_) {
            // Skip invalid food entries.
          }
        } else if (entry is Map) {
          try {
            foods.add(
              ParsedFoodItem.fromJson(Map<String, dynamic>.from(entry)),
            );
          } catch (_) {
            // Skip invalid food entries.
          }
        }
      }
    }
    final questionsRaw = json['questions'];
    final questions = <GuidedQuestion>[];
    if (questionsRaw is List) {
      for (final entry in questionsRaw) {
        if (entry is Map<String, dynamic>) {
          try {
            questions.add(GuidedQuestion.fromJson(entry));
          } catch (_) {
            // Skip invalid question entries.
          }
        } else if (entry is Map) {
          try {
            questions.add(
              GuidedQuestion.fromJson(Map<String, dynamic>.from(entry)),
            );
          } catch (_) {
            // Skip invalid question entries.
          }
        }
      }
    }
    return MealRefineResult(
      foods: foods,
      questions: questions,
      isFinal: (json['is_final'] as bool?) ?? false,
      roundsRemaining: (json['rounds_remaining'] as num?)?.toInt() ?? 0,
      suggestedRule: _suggestedRuleFromJson(json['suggested_rule']),
    );
  }
}
