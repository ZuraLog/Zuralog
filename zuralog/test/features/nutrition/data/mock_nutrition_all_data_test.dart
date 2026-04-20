library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/data/mock_nutrition_repository.dart';

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

    test('range day counts are correct', () async {
      final cases = {'7d': 7, '30d': 30, '3m': 90, '6m': 180, '1y': 365};
      for (final entry in cases.entries) {
        final days = await repo.getNutritionAllData(entry.key);
        expect(days.length, entry.value, reason: 'range ${entry.key} should return ${entry.value} days');
      }
    });
  });
}
