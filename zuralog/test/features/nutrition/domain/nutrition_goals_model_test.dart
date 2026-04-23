import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_goals_model.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';

void main() {
  test('NutritionGoals.fromGoalList maps calorieBudget from dailyCalorieLimit',
      () {
    final goals = [
      Goal(
        id: '1',
        userId: 'user1',
        type: GoalType.dailyCalorieLimit,
        period: GoalPeriod.daily,
        title: 'Daily Calorie Limit',
        targetValue: 2000.0,
        currentValue: 1800.0,
        unit: 'kcal',
        startDate: '2026-04-23',
        progressHistory: [],
        isCompleted: false,
      ),
    ];
    final ng = NutritionGoals.fromGoalList(goals);
    expect(ng.calorieBudget, 2000.0);
  });

  test('NutritionGoals.fromGoalList excludes completed goals', () {
    final goals = [
      Goal(
        id: '1',
        userId: 'user1',
        type: GoalType.dailyCalorieLimit,
        period: GoalPeriod.daily,
        title: 'Daily Calorie Limit',
        targetValue: 2000.0,
        currentValue: 1800.0,
        unit: 'kcal',
        startDate: '2026-04-23',
        progressHistory: [],
        isCompleted: true,
      ),
    ];
    final ng = NutritionGoals.fromGoalList(goals);
    expect(ng.calorieBudget, isNull);
  });

  test('NutritionGoals.fromGoalList returns all nulls when no matching goals',
      () {
    final ng = NutritionGoals.fromGoalList([]);
    expect(ng.calorieBudget, isNull);
    expect(ng.proteinMinG, isNull);
    expect(ng.carbsMaxG, isNull);
    expect(ng.fatMaxG, isNull);
    expect(ng.fiberMinG, isNull);
    expect(ng.sodiumMaxMg, isNull);
    expect(ng.sugarMaxG, isNull);
  });

  test('NutritionGoals.hasGoals is true when any goal is set', () {
    final goals = [
      Goal(
        id: '1',
        userId: 'user1',
        type: GoalType.dailyCalorieLimit,
        period: GoalPeriod.daily,
        title: 'Daily Calorie Limit',
        targetValue: 2000.0,
        currentValue: 1800.0,
        unit: 'kcal',
        startDate: '2026-04-23',
        progressHistory: [],
        isCompleted: false,
      ),
    ];
    final ng = NutritionGoals.fromGoalList(goals);
    expect(ng.hasGoals, true);
  });

  test('NutritionGoals.hasGoals is false when no goals are set', () {
    final ng = NutritionGoals.fromGoalList([]);
    expect(ng.hasGoals, false);
  });

  test('nutritionGoalStatus onTrack when actual >= target (min goal)', () {
    expect(
      nutritionGoalStatus(actual: 150, target: 150, isMin: true),
      NutritionGoalStatus.onTrack,
    );
  });

  test('nutritionGoalStatus atRisk when 50-99% (min goal)', () {
    expect(
      nutritionGoalStatus(actual: 90, target: 150, isMin: true),
      NutritionGoalStatus.atRisk,
    );
  });

  test('nutritionGoalStatus offTrack when <50% (min goal)', () {
    expect(
      nutritionGoalStatus(actual: 50, target: 150, isMin: true),
      NutritionGoalStatus.offTrack,
    );
  });

  test('nutritionGoalStatus onTrack when <=75% (max goal)', () {
    expect(
      nutritionGoalStatus(actual: 1400, target: 2000, isMin: false),
      NutritionGoalStatus.onTrack,
    );
  });

  test('nutritionGoalStatus atRisk when 75-100% (max goal)', () {
    expect(
      nutritionGoalStatus(actual: 1800, target: 2000, isMin: false),
      NutritionGoalStatus.atRisk,
    );
  });

  test('nutritionGoalStatus offTrack when >100% (max goal)', () {
    expect(
      nutritionGoalStatus(actual: 2100, target: 2000, isMin: false),
      NutritionGoalStatus.offTrack,
    );
  });

  test('nutritionGoalStatus handles zero target (returns onTrack)', () {
    expect(
      nutritionGoalStatus(actual: 100, target: 0, isMin: true),
      NutritionGoalStatus.onTrack,
    );
  });
}
