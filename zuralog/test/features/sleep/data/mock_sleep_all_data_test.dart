// zuralog/test/features/sleep/data/mock_sleep_all_data_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/sleep/data/mock_sleep_repository.dart';

void main() {
  late MockSleepRepository repo;

  setUp(() => repo = MockSleepRepository());

  group('MockSleepRepository.getSleepAllData', () {
    test('7d returns 7 days', () async {
      final days = await repo.getSleepAllData('7d');
      expect(days.length, 7);
    });

    test('each day has a non-empty values map', () async {
      final days = await repo.getSleepAllData('7d');
      for (final day in days) {
        expect(day.values, isNotEmpty);
      }
    });

    test('today entry has isToday = true', () async {
      final days = await repo.getSleepAllData('7d');
      final todayDays = days.where((d) => d.isToday).toList();
      expect(todayDays.length, 1);
    });

    test('duration values are in minutes (nullable)', () async {
      final days = await repo.getSleepAllData('7d');
      for (final day in days) {
        final dur = day.values['duration'];
        if (dur != null) {
          expect(dur, greaterThan(0));
          expect(dur, lessThan(900)); // < 15 hours
        }
      }
    });

    test('throws ArgumentError for unknown range', () async {
      await expectLater(
        () => repo.getSleepAllData('invalid'),
        throwsArgumentError,
      );
    });

    test('date strings are YYYY-MM-DD formatted', () async {
      final days = await repo.getSleepAllData('7d');
      final iso = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      for (final day in days) {
        expect(day.date, matches(iso));
      }
    });

    test('last entry is today', () async {
      final days = await repo.getSleepAllData('7d');
      expect(days.last.isToday, isTrue);
    });

    test('range day counts are correct', () async {
      final cases = {'7d': 7, '30d': 30, '3m': 90, '6m': 180, '1y': 365};
      for (final entry in cases.entries) {
        final days = await repo.getSleepAllData(entry.key);
        expect(days.length, entry.value, reason: 'range ${entry.key} should return ${entry.value} days');
      }
    });
  });
}
