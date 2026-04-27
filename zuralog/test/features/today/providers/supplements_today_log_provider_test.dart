import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:zuralog/features/today/data/today_repository.dart';
import 'package:zuralog/features/today/domain/supplement_today_entry.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

class MockTodayRepository extends Mock implements TodayRepositoryInterface {}

void main() {
  group('supplementsTodayLogProvider', () {
    test('returns list from repository on success', () async {
      final mockRepo = MockTodayRepository();
      when(() => mockRepo.getSupplementsTodayLog()).thenAnswer((_) async => [
            const SupplementTodayLogEntry(
                supplementId: 'sup-1', logId: 'log-a'),
          ]);

      final container = ProviderContainer(
        overrides: [
          todayRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final result =
          await container.read(supplementsTodayLogProvider.future);
      expect(result.length, 1);
      expect(result[0].supplementId, 'sup-1');
    });

    test('returns empty list on repository failure', () async {
      final mockRepo = MockTodayRepository();
      when(() => mockRepo.getSupplementsTodayLog())
          .thenThrow(Exception('network error'));

      final container = ProviderContainer(
        overrides: [
          todayRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final result =
          await container.read(supplementsTodayLogProvider.future);
      expect(result, isEmpty);
    });
  });
}
