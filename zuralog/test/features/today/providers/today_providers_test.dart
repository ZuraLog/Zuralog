// zuralog/test/features/today/providers/today_providers_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:zuralog/features/today/data/today_repository.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockTodayRepository extends Mock implements TodayRepositoryInterface {}

// ── Helpers ────────────────────────────────────────────────────────────────

ProviderContainer makeContainer(TodayRepositoryInterface repo) {
  return ProviderContainer(
    overrides: [
      todayRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('todayLogSummaryProvider', () {
    test('returns real data on success', () async {
      final repo = MockTodayRepository();
      final summary = TodayLogSummary(
        loggedTypes: {'water', 'mood'},
        latestValues: {'water': 750.0, 'mood': 7.5},
      );
      when(() => repo.getTodayLogSummary()).thenAnswer((_) async => summary);

      final container = makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container.read(todayLogSummaryProvider.future);
      expect(result.loggedTypes, equals({'water', 'mood'}));
      expect(result.latestValues['water'], equals(750.0));
    });

    test('returns TodayLogSummary.empty on network failure', () async {
      final repo = MockTodayRepository();
      when(() => repo.getTodayLogSummary()).thenThrow(Exception('network error'));

      final container = makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container.read(todayLogSummaryProvider.future);
      expect(result.loggedTypes, isEmpty);
      expect(result.latestValues, isEmpty);
      expect(identical(result, TodayLogSummary.empty), isTrue);
    });
  });

  group('userLoggedTypesProvider', () {
    test('returns real types on success', () async {
      final repo = MockTodayRepository();
      when(() => repo.getUserLoggedTypes())
          .thenAnswer((_) async => {'water', 'mood', 'sleep'});

      final container = makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container.read(userLoggedTypesProvider.future);
      expect(result, equals({'water', 'mood', 'sleep'}));
    });

    test('returns empty set on network failure', () async {
      final repo = MockTodayRepository();
      when(() => repo.getUserLoggedTypes()).thenThrow(Exception('timeout'));

      final container = makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container.read(userLoggedTypesProvider.future);
      expect(result, isEmpty);
    });
  });

}
