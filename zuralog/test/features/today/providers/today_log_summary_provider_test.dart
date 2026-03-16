import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/data/today_repository.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

// Minimal stub repository — returns empty data for all methods.
// Used so provider tests don't require a real network or platform binding.
class _StubRepo implements TodayRepositoryInterface {
  @override Future<HealthScoreData> getHealthScore() async => const HealthScoreData(score: 0, trend: [], dataDays: 0);
  @override Future<TodayFeedData> getTodayFeed() async => TodayFeedData(insights: [], streak: null);
  @override void invalidateFeedCache() {}
  @override Future<InsightDetail> getInsightDetail(String id) async => throw UnimplementedError();
  @override Future<void> markInsightRead(String id) async {}
  @override Future<void> dismissInsight(String id) async {}
  @override Future<void> submitQuickLog(Map<String, dynamic> payload) async {}
  @override Future<NotificationPage> getNotifications({int page = 1}) async => const NotificationPage(items: [], totalCount: 0, page: 1, hasMore: false);
  @override Future<void> markNotificationRead(String id) async {}
  @override Future<List<DailyGoal>> getDailyGoals() async => const [];
  @override Future<TodayLogSummary> getTodayLogSummary() async => TodayLogSummary.empty;
  @override Future<Set<String>> getUserLoggedTypes() async => const {};
  @override Future<List<SupplementEntry>> getSupplementsList() async => const [];
  @override Future<List<SupplementEntry>> updateSupplementsList(List<SupplementEntry> supplements) async => supplements;
  @override Future<void> logSleep({required DateTime bedtime, required DateTime wakeTime, required int durationMinutes, int? qualityRating, int? interruptions, List<String> factors = const [], String? notes}) async {}
  @override Future<void> logRun({required String activityType, required double distanceKm, required int durationSeconds, int? avgPaceSecondsPerKm, String? effortLevel, String? notes}) async {}
  @override Future<void> logMeal({required String mealType, required bool quickMode, String? description, int? caloriesKcal, List<String> feelChips = const [], List<String> tags = const [], String? notes}) async {}
  @override Future<void> logSupplements({required List<String> takenIds, String? notes}) async {}
  @override Future<void> logSymptom({required List<String> bodyAreas, required String severity, String? symptomType, String? timing, String? notes}) async {}
  @override Future<void> logSteps({required int steps, String mode = 'add', String source = 'manual'}) async {}
}

ProviderContainer _container({List<Override> overrides = const []}) =>
    ProviderContainer(overrides: [
      todayRepositoryProvider.overrideWithValue(_StubRepo()),
      ...overrides,
    ]);

void main() {
  group('todayLogSummaryProvider', () {
    test('returns empty summary by default', () async {
      final container = _container();
      addTearDown(container.dispose);
      final summary = await container.read(todayLogSummaryProvider.future);
      expect(summary.loggedTypes, isEmpty);
      expect(summary.latestValues, isEmpty);
    });
  });

  group('userLoggedTypesProvider', () {
    test('returns empty set by default', () async {
      final container = _container();
      addTearDown(container.dispose);
      final types = await container.read(userLoggedTypesProvider.future);
      expect(types, isEmpty);
    });
  });

  group('logRingProvider', () {
    test('is in loading state before resolving', () async {
      final container = _container();
      addTearDown(container.dispose);
      final ringAsync = container.read(logRingProvider);
      expect(ringAsync, isA<AsyncLoading>());
    });

    test('fraction is 0.0 when nothing logged', () async {
      final container = _container();
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
      final container = _container();
      addTearDown(container.dispose);
      final cards = await container.read(snapshotProvider.future);
      expect(cards, isEmpty);
    });

    test('returns cards in grid order when types exist', () async {
      final container = _container(overrides: [
        userLoggedTypesProvider.overrideWith(
          (ref) async => {'water', 'mood'},
        ),
      ]);
      addTearDown(container.dispose);
      final cards = await container.read(snapshotProvider.future);
      // mood comes before water in the ordered list
      expect(cards.length, 2);
      expect(cards[0].metricType, 'mood');
      expect(cards[1].metricType, 'water');
    });
  });
}
