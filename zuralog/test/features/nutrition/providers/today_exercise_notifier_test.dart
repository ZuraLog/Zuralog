import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/nutrition/data/mock_nutrition_repository.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';

void main() {
  group('TodayExerciseNotifier', () {
    test('todayExerciseProvider resolves to list', () async {
      final container = ProviderContainer(overrides: [
        nutritionRepositoryProvider.overrideWithValue(MockNutritionRepository()),
      ]);
      addTearDown(container.dispose);
      expect(
        await container.read(todayExerciseProvider.future),
        isA<List<ExerciseEntry>>(),
      );
    });
  });
}
