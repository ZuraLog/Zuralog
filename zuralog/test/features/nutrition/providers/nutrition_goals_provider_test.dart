import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/nutrition/domain/nutrition_goals_model.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';

void main() {
  group('nutritionGoalsProvider', () {
    test('returns NutritionGoals with calorieBudget from goals', () async {
      final container = ProviderContainer(overrides: [
        goalsProvider.overrideWith((_) async => GoalList(
          goals: [
            Goal(
              id: 'goal-1',
              userId: 'user-1',
              type: GoalType.dailyCalorieLimit,
              period: GoalPeriod.daily,
              title: 'Daily Calorie Limit',
              targetValue: 2000.0,
              currentValue: 1500.0,
              unit: 'kcal',
              startDate: '2026-01-01',
              progressHistory: const [],
            ),
          ],
        )),
      ]);
      addTearDown(container.dispose);

      final ng = await container.read(nutritionGoalsProvider.future);
      expect(ng.calorieBudget, 2000.0);
    });

    test('returns NutritionGoals with null fields for missing goals', () async {
      final container = ProviderContainer(overrides: [
        goalsProvider.overrideWith((_) async => const GoalList(goals: [])),
      ]);
      addTearDown(container.dispose);

      final ng = await container.read(nutritionGoalsProvider.future);
      expect(ng.calorieBudget, isNull);
      expect(ng.proteinMinG, isNull);
      expect(ng.carbsMaxG, isNull);
    });

    test('ignores completed goals', () async {
      final container = ProviderContainer(overrides: [
        goalsProvider.overrideWith((_) async => GoalList(
          goals: [
            Goal(
              id: 'goal-1',
              userId: 'user-1',
              type: GoalType.dailyCalorieLimit,
              period: GoalPeriod.daily,
              title: 'Daily Calorie Limit',
              targetValue: 2000.0,
              currentValue: 1500.0,
              unit: 'kcal',
              startDate: '2026-01-01',
              progressHistory: const [],
              isCompleted: true,
            ),
          ],
        )),
      ]);
      addTearDown(container.dispose);

      final ng = await container.read(nutritionGoalsProvider.future);
      expect(ng.calorieBudget, isNull);
    });

    test('returns NutritionGoals with multiple goals', () async {
      final container = ProviderContainer(overrides: [
        goalsProvider.overrideWith((_) async => GoalList(
          goals: [
            Goal(
              id: 'goal-1',
              userId: 'user-1',
              type: GoalType.dailyCalorieLimit,
              period: GoalPeriod.daily,
              title: 'Daily Calorie Limit',
              targetValue: 2000.0,
              currentValue: 1500.0,
              unit: 'kcal',
              startDate: '2026-01-01',
              progressHistory: const [],
            ),
            Goal(
              id: 'goal-2',
              userId: 'user-1',
              type: GoalType.stepCount,
              period: GoalPeriod.daily,
              title: 'Daily Steps',
              targetValue: 10000.0,
              currentValue: 8000.0,
              unit: 'steps',
              startDate: '2026-01-01',
              progressHistory: const [],
            ),
          ],
        )),
      ]);
      addTearDown(container.dispose);

      final ng = await container.read(nutritionGoalsProvider.future);
      expect(ng.calorieBudget, 2000.0);
      expect(ng.hasGoals, isTrue);
    });
  });
}
