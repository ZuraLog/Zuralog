// zuralog/test/features/sleep/data/mock_sleep_all_data_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/sleep/data/mock_sleep_repository.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';

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
  });
}
