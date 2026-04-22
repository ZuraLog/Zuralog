import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';

void main() {
  // ── ExerciseEntry ────────────────────────────────────────────────────────────

  test('ExerciseEntry.fromJson parses correctly', () {
    final json = {
      'id': 'entry-1',
      'activity': 'Running',
      'duration_minutes': 30,
      'calories_burned': 320,
      'logged_at': '2026-04-23T10:00:00.000Z',
    };
    final entry = ExerciseEntry.fromJson(json);
    expect(entry.id, 'entry-1');
    expect(entry.activity, 'Running');
    expect(entry.durationMinutes, 30);
    expect(entry.caloriesBurned, 320);
    expect(entry.loggedAt, DateTime.parse('2026-04-23T10:00:00.000Z'));
  });

  // ── MealTemplate ─────────────────────────────────────────────────────────────

  test('MealTemplate.fromJson parses foods list', () {
    final json = {
      'id': 'tmpl-1',
      'name': 'My Lunch',
      'meal_type': 'lunch',
      'foods': [
        {
          'food_name': 'chicken',
          'calories': 330.0,
          'protein_g': 62.0,
          'carbs_g': 0.0,
          'fat_g': 7.0,
          'portion_amount': 200.0,
          'portion_unit': 'g',
          'fiber_g': 0.0,
          'sodium_mg': 80.0,
          'sugar_g': 0.0,
        }
      ],
      'created_at': '2026-04-23T10:00:00.000Z',
    };
    final tmpl = MealTemplate.fromJson(json);
    expect(tmpl.id, 'tmpl-1');
    expect(tmpl.name, 'My Lunch');
    expect(tmpl.mealType, 'lunch');
    expect(tmpl.foods.length, 1);
    expect(tmpl.foods.first.proteinG, 62.0);
    expect(tmpl.createdAt, DateTime.parse('2026-04-23T10:00:00.000Z'));
  });

  // ── MealFood ─────────────────────────────────────────────────────────────────

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
