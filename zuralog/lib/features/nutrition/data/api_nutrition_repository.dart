/// ZuraLog — API-backed Nutrition Repository.
///
/// Calls the Cloud Brain nutrition endpoints via [ApiClient].
/// Implements the full [NutritionRepositoryInterface] contract with real
/// HTTP calls. Exceptions propagate to the provider layer, except for
/// 404 responses in [getMealById] which return `null`.
library;

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
  Future<List<ParsedFoodItem>> parseMealDescription(String description) async {
    final response = await _api.post(
      '/api/v1/nutrition/meals/parse',
      data: {'description': description},
    );
    final foods = response.data['foods'] as List<dynamic>? ?? [];
    return foods
        .map((e) => ParsedFoodItem.fromJson(e as Map<String, dynamic>))
        .toList();
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
}
