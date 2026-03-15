import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

void main() {
  group('todayLogSummaryProvider', () {
    test('returns empty summary by default', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final summary = await container.read(todayLogSummaryProvider.future);
      expect(summary.loggedTypes, isEmpty);
      expect(summary.latestValues, isEmpty);
    });
  });

  group('userLoggedTypesProvider', () {
    test('returns empty set by default', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final types = await container.read(userLoggedTypesProvider.future);
      expect(types, isEmpty);
    });
  });

  group('logRingProvider', () {
    test('is in loading state before resolving', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ringAsync = container.read(logRingProvider);
      expect(ringAsync, isA<AsyncLoading>());
    });

    test('fraction is 0.0 when nothing logged', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ring = await container.read(logRingProvider.future);
      expect(ring.fraction, 0.0);
    });
  });

  group('LogRingState', () {
    test('fraction clamps to 0.0 when totalCount is 0', () {
      const state = LogRingState(loggedCount: 0, totalCount: 0);
      expect(state.fraction, 0.0);
    });

    test('fraction is correct for partial completion', () {
      const state = LogRingState(loggedCount: 3, totalCount: 9);
      expect(state.fraction, closeTo(0.333, 0.001));
    });

    test('fraction clamps to 1.0 when loggedCount exceeds total', () {
      const state = LogRingState(loggedCount: 10, totalCount: 9);
      expect(state.fraction, 1.0);
    });
  });

  group('snapshotProvider', () {
    test('returns empty list when no types ever logged', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cards = await container.read(snapshotProvider.future);
      expect(cards, isEmpty);
    });

    test('returns cards in grid order when types exist', () async {
      final container = ProviderContainer(
        overrides: [
          userLoggedTypesProvider.overrideWith(
            (ref) async => {'water', 'mood'},
          ),
        ],
      );
      addTearDown(container.dispose);
      final cards = await container.read(snapshotProvider.future);
      // mood comes before water in the ordered list
      expect(cards.length, 2);
      expect(cards[0].metricType, 'mood');
      expect(cards[1].metricType, 'water');
    });
  });
}
