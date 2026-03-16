import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

void main() {
  group('todayLogSummaryProvider invalidation', () {
    test(
        'invalidating todayLogSummaryProvider causes logRingProvider to recompute',
        () async {
      var fetchCount = 0;
      final container = ProviderContainer(
        overrides: [
          todayLogSummaryProvider.overrideWith((ref) async {
            fetchCount++;
            return TodayLogSummary.empty;
          }),
          userLoggedTypesProvider.overrideWith(
            (ref) async => const <String>{},
          ),
        ],
      );
      addTearDown(container.dispose);

      // First read — triggers one fetch.
      await container.read(todayLogSummaryProvider.future);
      expect(fetchCount, 1);

      // Invalidate — should trigger a re-fetch.
      container.invalidate(todayLogSummaryProvider);
      await container.read(todayLogSummaryProvider.future);
      expect(fetchCount, 2);
    });

    test('logRingProvider updates after todayLogSummaryProvider invalidation',
        () async {
      var summaryData = TodayLogSummary.empty;

      final container = ProviderContainer(
        overrides: [
          todayLogSummaryProvider.overrideWith((ref) async => summaryData),
          userLoggedTypesProvider.overrideWith(
            (ref) async => const {'water', 'mood', 'steps'},
          ),
        ],
      );
      addTearDown(container.dispose);

      // Initial state: nothing logged → fraction 0.
      final ringBefore = await container.read(logRingProvider.future);
      expect(ringBefore.fraction, 0.0);

      // Simulate a successful log — update summaryData and invalidate.
      summaryData = const TodayLogSummary(
        loggedTypes: {'water'},
        latestValues: {'water': 750.0},
      );
      container.invalidate(todayLogSummaryProvider);

      // After re-fetch: 1 of 3 types logged → fraction ≈ 0.333.
      final ringAfter = await container.read(logRingProvider.future);
      expect(ringAfter.fraction, closeTo(1 / 3, 0.001));
    });

    test('snapshotProvider rebuilds after todayLogSummaryProvider invalidation',
        () async {
      var summaryData = TodayLogSummary.empty;

      final container = ProviderContainer(
        overrides: [
          todayLogSummaryProvider.overrideWith((ref) async => summaryData),
          userLoggedTypesProvider.overrideWith(
            (ref) async => const {'water'},
          ),
        ],
      );
      addTearDown(container.dispose);

      // Initial state: water card is empty.
      final snapBefore = await container.read(snapshotProvider.future);
      expect(snapBefore.first.isEmpty, isTrue);

      // Simulate a successful water log.
      summaryData = const TodayLogSummary(
        loggedTypes: {'water'},
        latestValues: {'water': 500.0},
      );
      container.invalidate(todayLogSummaryProvider);

      // After re-fetch: water card should have data.
      final snapAfter = await container.read(snapshotProvider.future);
      expect(snapAfter.first.isEmpty, isFalse);
      expect(snapAfter.first.value, '500');
    });
  });
}
