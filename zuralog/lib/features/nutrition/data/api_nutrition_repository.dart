/// ZuraLog — API-backed Nutrition Repository.
///
/// Calls the Cloud Brain nutrition endpoints via [ApiClient].
/// Implements the full [NutritionRepositoryInterface] contract with real
/// HTTP calls. Exceptions propagate to the provider layer, except for
/// 404 responses in [getMealById] which return `null`.
library;

import 'dart:io';

import 'package:dio/dio.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/nutrition/data/mock_nutrition_repository.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';

/// Production implementation of [NutritionRepositoryInterface].
///
/// Every method maps directly to a Cloud Brain REST endpoint under
/// `/api/v1/nutrition/`. Authentication is handled automatically by
/// [ApiClient]'s interceptor — callers don't need to pass tokens.
class ApiNutritionRepository implements NutritionRepositoryInterface {
  /// Creates an [ApiNutritionRepository] backed by the given [ApiClient].
  ApiNutritionRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ── Today ──────────────────────────────────────────────────────────────────

  @override
  Future<List<Meal>> getTodayMeals() async {
    final response = await _api.get('/api/v1/nutrition/today');
    final meals = response.data['meals'] as List<dynamic>? ?? [];
    return meals
        .map((e) => Meal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<NutritionDaySummary> getTodaySummary() async {
    final response = await _api.get('/api/v1/nutrition/today');
    final summary = response.data['summary'] as Map<String, dynamic>?;
    if (summary == null) return NutritionDaySummary.empty;
    return NutritionDaySummary.fromJson(summary);
  }

  // ── Single Meal ────────────────────────────────────────────────────────────

  @override
  Future<Meal?> getMealById(String id) async {
    try {
      final response = await _api.get('/api/v1/nutrition/meals/$id');
      return Meal.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<void> deleteMeal(String id) async {
    await _api.delete('/api/v1/nutrition/meals/$id');
  }

  // ── Create & Update ────────────────────────────────────────────────────────

  @override
  Future<Meal> createMeal({
    required String mealType,
    String? name,
    required DateTime loggedAt,
    required List<MealFood> foods,
  }) async {
    final response = await _api.post('/api/v1/nutrition/meals', data: {
      'meal_type': mealType,
      'name': name,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'foods': foods.map((f) => f.toJson()).toList(),
    });
    return Meal.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Meal> updateMeal(
    String id, {
    required String mealType,
    String? name,
    required DateTime loggedAt,
    required List<MealFood> foods,
  }) async {
    final response = await _api.put('/api/v1/nutrition/meals/$id', data: {
      'meal_type': mealType,
      'name': name,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'foods': foods.map((f) => f.toJson()).toList(),
    });
    return Meal.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Foods ──────────────────────────────────────────────────────────────────

  @override
  Future<List<RecentFood>> getRecentFoods() async {
    final response = await _api.get('/api/v1/nutrition/foods/recent');
    final foods = response.data['foods'] as List<dynamic>? ?? [];
    return foods
        .map((e) => RecentFood.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<FoodSearchResult>> searchFoods(
    String query, {
    int limit = 10,
  }) async {
    final response = await _api.get(
      '/api/v1/nutrition/foods/search',
      queryParameters: {'q': query, 'limit': '$limit'},
    );
    final foods = response.data['foods'] as List<dynamic>? ?? [];
    return foods
        .map((e) => FoodSearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── AI Parsing ─────────────────────────────────────────────────────────────

  @override
  Future<MealParseResult> parseMealDescription(
    String description, {
    required String mode,
  }) async {
    final response = await _api.post(
      '/api/v1/nutrition/meals/parse',
      data: {'description': description, 'mode': mode},
    );
    return MealParseResult.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<String?> fetchFoodImage(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    try {
      final response = await _api.get(
        '/api/v1/nutrition/food-image',
        queryParameters: {'q': trimmed},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      final url = data['image_url'];
      return url is String ? url : null;
    } catch (_) {
      // Loading-state image is non-critical — swallow errors, caller shows pattern.
      return null;
    }
  }

  @override
  Future<MealRefineResult> refineMeal({
    required String description,
    required List<ParsedFoodItem> foods,
    required List<GuidedQuestion> questionsHistory,
    required List<Map<String, dynamic>> answersHistory,
    required int round,
  }) async {
    final response = await _api.post(
      '/api/v1/nutrition/meals/refine',
      data: {
        'description': description,
        'foods': foods.map((f) => f.toJson()).toList(),
        'questions_history':
            questionsHistory.map((q) => q.toJson()).toList(),
        'answers_history': answersHistory,
        'round': round,
      },
    );
    return MealRefineResult.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Corrections ────────────────────────────────────────────────────────────

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
  }) async {
    await _api.post('/api/v1/nutrition/foods/corrections', data: {
      'food_name': foodName,
      'original_calories': originalCalories,
      'corrected_calories': correctedCalories,
      'original_protein_g': originalProteinG,
      'corrected_protein_g': correctedProteinG,
      'original_carbs_g': originalCarbsG,
      'corrected_carbs_g': correctedCarbsG,
      'original_fat_g': originalFatG,
      'corrected_fat_g': correctedFatG,
    });
  }

  // ── Camera / Barcode ──────────────────────────────────────────────────────

  @override
  Future<MealParseResult> scanFoodImage(
    File imageFile, {
    required String mode,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split(Platform.pathSeparator).last,
      ),
      'mode': mode,
    });
    final response = await _api.post(
      '/api/v1/nutrition/meals/scan-image',
      data: formData,
    );
    return MealParseResult.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<FoodSearchResult?> lookupBarcode(String code) async {
    try {
      final response = await _api.get('/api/v1/nutrition/foods/barcode/$code');
      final data = response.data as Map<String, dynamic>;
      final foodData = data['food'] as Map<String, dynamic>?;
      if (foodData == null) return null;
      return FoodSearchResult.fromJson(foodData);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // ── Nutrition Rules ────────────────────────────────────────────────────────

  @override
  Future<List<NutritionRule>> getRules() async {
    final response = await _api.get('/api/v1/nutrition/rules');
    final rules = response.data['rules'] as List<dynamic>? ?? [];
    return rules
        .map((e) => NutritionRule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<NutritionRule> createRule(
    String ruleText, {
    String? suppressedQuestionId,
    String? suppressedAnswerValue,
  }) async {
    final Map<String, dynamic> body = {'rule_text': ruleText};
    if (suppressedQuestionId != null) {
      body['suppressed_question_id'] = suppressedQuestionId;
    }
    if (suppressedAnswerValue != null) {
      body['suppressed_answer_value'] = suppressedAnswerValue;
    }
    final response = await _api.post(
      '/api/v1/nutrition/rules',
      data: body,
    );
    return NutritionRule.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<NutritionRule> updateRule(String ruleId, String ruleText) async {
    final response = await _api.put(
      '/api/v1/nutrition/rules/$ruleId',
      data: {'rule_text': ruleText},
    );
    return NutritionRule.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteRule(String ruleId) async {
    await _api.delete('/api/v1/nutrition/rules/$ruleId');
  }

  @override
  Future<void> dismissRuleSuggestion({
    required String questionId,
    required String answerValue,
  }) async {
    await _api.post(
      '/api/v1/nutrition/meals/rule-suggestion/dismiss',
      data: {
        'question_id': questionId,
        'answer_value': answerValue,
      },
    );
  }

  // ── Trend ──────────────────────────────────────────────────────────────────

  @override
  Future<List<NutritionTrendDay>> getTrend(String range) async {
    final response = await _api.get(
      '/api/v1/nutrition/trend',
      queryParameters: {'range': range},
    );
    final days = response.data['days'] as List<dynamic>? ?? [];
    return days
        .map((e) => NutritionTrendDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
