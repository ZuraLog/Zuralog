library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/data/mock_nutrition_repository.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';

void main() {
  late MockNutritionRepository repo;

  setUp(() => repo = const MockNutritionRepository());

  group('MockNutritionRepository.getNutritionAllData', () {
    test('7d returns 7 days', () async {
      final days = await repo.getNutritionAllData('7d');
      expect(days.length, 7);
    });

    test('each day has a non-empty values map', () async {
      final days = await repo.getNutritionAllData('7d');
      for (final day in days) {
        expect(day.values, isNotEmpty);
      }
    });

    test('today entry has isToday = true', () async {
      final days = await repo.getNutritionAllData('7d');
      final todayDays = days.where((d) => d.isToday).toList();
      expect(todayDays.length, 1);
    });

    test('calories values are positive when not null', () async {
      final days = await repo.getNutritionAllData('7d');
      for (final day in days) {
        final cal = day.values['calories'];
        if (cal != null) expect(cal, greaterThan(0));
      }
    });

    test('throws ArgumentError for unknown range', () async {
      await expectLater(
        () => repo.getNutritionAllData('invalid'),
        throwsArgumentError,
      );
    });

    test('date strings are YYYY-MM-DD formatted', () async {
      final days = await repo.getNutritionAllData('7d');
      final iso = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      for (final day in days) {
        expect(day.date, matches(iso));
      }
    });

    test('last entry is today', () async {
      final days = await repo.getNutritionAllData('7d');
      expect(days.last.isToday, isTrue);
    });
  });
}
