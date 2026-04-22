import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';

void main() {
  test('MealFood fromJson maps fiberG sodiumMg sugarG', () {
    final json = {
      'food_name': 'oats',
      'portion_grams': 100,
      'portion_unit': 'g',
      'calories_kcal': 380,
      'protein_g': 13,
      'carbs_g': 66,
      'fat_g': 7,
      'fiber_g': 10,
      'sodium_mg': 0,
      'sugar_g': 1,
    };
    final food = MealFood.fromJson(json);
    expect(food.fiberG, 10.0);
    expect(food.sodiumMg, 0.0);
    expect(food.sugarG, 1.0);
  });

  test('NutritionDaySummary fromJson maps exerciseCaloriesBurned', () {
    final json = {
      'total_calories': 1800,
      'total_protein_g': 120,
      'total_carbs_g': 200,
      'total_fat_g': 60,
      'total_fiber_g': 25,
      'total_sodium_mg': 1500,
      'total_sugar_g': 40,
      'exercise_calories_burned': 320,
      'meal_count': 3,
    };
    final summary = NutritionDaySummary.fromJson(json);
    expect(summary.fiberG, 25.0);
    expect(summary.sodiumMg, 1500.0);
    expect(summary.sugarG, 40.0);
    expect(summary.exerciseCaloriesBurned, 320);
  });

  test('NutritionDaySummary.empty has zero new fields', () {
    expect(NutritionDaySummary.empty.fiberG, 0.0);
    expect(NutritionDaySummary.empty.exerciseCaloriesBurned, 0);
  });
}
