import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/data/mock_today_repository.dart';
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
  @override Future<void> logWater({required double amountMl, String? vesselKey}) async {}
  @override Future<void> logWellness({double? mood, double? energy, double? stress, String? notes}) async {}
  @override Future<void> logWeight({required double valueKg, required String timeOfDay, double? bodyFatPct}) async {}
  @override Future<Map<String, dynamic>> getLatestLogValues(Set<String> types) async => const {};
  @override Future<IngestResult> submitIngest({required String metricType, required double value, required String unit, required String source, required DateTime recordedAt, String? idempotencyKey, Map<String, dynamic>? metadata}) async => IngestResult(eventId: '', dailyTotal: 0, unit: unit, date: '');
  @override Future<TodayTimeline> getTodayTimeline({int limit = 50, String? before}) async => const TodayTimeline(events: []);
  @override Future<void> deleteEvent(String eventId) async {}
  @override Future<SessionIngestResult> submitSession({required String sessionType, required String source, required DateTime recordedAt, DateTime? endedAt, required List<SessionMetricPayload> metrics, String? notes, Map<String, dynamic>? metadata}) async => SessionIngestResult(sessionId: '', eventIds: [], date: '');
  @override Future<BulkIngestResult> bulkIngest({required String source, required List<BulkEventPayload> events}) async => BulkIngestResult(eventCount: 0, status: 'ok', taskId: '');
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

  // --- latestLogValuesProvider ---

  group('latestLogValuesProvider', () {
    test('returns empty map when types set is empty', () async {
      final container = ProviderContainer(overrides: [
        todayRepositoryProvider.overrideWithValue(MockTodayRepository()),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(
        latestLogValuesProvider(latestLogValuesKey(const {})).future,
      );
      expect(result, isEmpty);
    });

    test('returns map from repository for requested types', () async {
      final mockRepo = _MockRepoWithLatestValues({
        'weight': {'value': 78.4, 'date': '2026-03-15T08:22:00Z'},
      });
      final container = ProviderContainer(overrides: [
        todayRepositoryProvider.overrideWithValue(mockRepo),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(
        latestLogValuesProvider(latestLogValuesKey(const {'weight'})).future,
      );
      final weightEntry = result['weight'] as Map<String, dynamic>?;
      expect(weightEntry?['value'], closeTo(78.4, 0.01));
    });
  });

  // snapshotProvider tests removed — provider was deleted as dead code.
}

// Helper mock for latestLogValuesProvider tests.
// MockTodayRepository is final so we implement the interface directly,
// forwarding all other methods to a real MockTodayRepository instance.
class _MockRepoWithLatestValues implements TodayRepositoryInterface {
  _MockRepoWithLatestValues(this._data);
  final Map<String, dynamic> _data;
  final _delegate = const MockTodayRepository();

  @override
  Future<Map<String, dynamic>> getLatestLogValues(Set<String> types) async {
    return Map.fromEntries(
      _data.entries.where((e) => types.contains(e.key)),
    );
  }

  // Delegate everything else to the mock.
  @override Future<HealthScoreData> getHealthScore() => _delegate.getHealthScore();
  @override Future<TodayFeedData> getTodayFeed() => _delegate.getTodayFeed();
  @override void invalidateFeedCache() => _delegate.invalidateFeedCache();
  @override Future<InsightDetail> getInsightDetail(String id) => _delegate.getInsightDetail(id);
  @override Future<void> markInsightRead(String id) => _delegate.markInsightRead(id);
  @override Future<void> dismissInsight(String id) => _delegate.dismissInsight(id);
  @override Future<NotificationPage> getNotifications({int page = 1}) => _delegate.getNotifications(page: page);
  @override Future<void> markNotificationRead(String id) => _delegate.markNotificationRead(id);
  @override Future<List<DailyGoal>> getDailyGoals() => _delegate.getDailyGoals();
  @override Future<TodayLogSummary> getTodayLogSummary() => _delegate.getTodayLogSummary();
  @override Future<Set<String>> getUserLoggedTypes() => _delegate.getUserLoggedTypes();
  @override Future<List<SupplementEntry>> getSupplementsList() => _delegate.getSupplementsList();
  @override Future<List<SupplementEntry>> updateSupplementsList(List<SupplementEntry> supplements) => _delegate.updateSupplementsList(supplements);
  @override Future<void> logSleep({required DateTime bedtime, required DateTime wakeTime, required int durationMinutes, int? qualityRating, int? interruptions, List<String> factors = const [], String? notes}) => _delegate.logSleep(bedtime: bedtime, wakeTime: wakeTime, durationMinutes: durationMinutes, qualityRating: qualityRating, interruptions: interruptions, factors: factors, notes: notes);
  @override Future<void> logRun({required String activityType, required double distanceKm, required int durationSeconds, int? avgPaceSecondsPerKm, String? effortLevel, String? notes}) => _delegate.logRun(activityType: activityType, distanceKm: distanceKm, durationSeconds: durationSeconds, avgPaceSecondsPerKm: avgPaceSecondsPerKm, effortLevel: effortLevel, notes: notes);
  @override Future<void> logMeal({required String mealType, required bool quickMode, String? description, int? caloriesKcal, List<String> feelChips = const [], List<String> tags = const [], String? notes}) => _delegate.logMeal(mealType: mealType, quickMode: quickMode, description: description, caloriesKcal: caloriesKcal, feelChips: feelChips, tags: tags, notes: notes);
  @override Future<void> logSupplements({required List<String> takenIds, String? notes}) => _delegate.logSupplements(takenIds: takenIds, notes: notes);
  @override Future<void> logSymptom({required List<String> bodyAreas, required String severity, String? symptomType, String? timing, String? notes}) => _delegate.logSymptom(bodyAreas: bodyAreas, severity: severity, symptomType: symptomType, timing: timing, notes: notes);
  @override Future<void> logSteps({required int steps, String mode = 'add', String source = 'manual'}) => _delegate.logSteps(steps: steps, mode: mode, source: source);
  @override Future<void> logWater({required double amountMl, String? vesselKey}) => _delegate.logWater(amountMl: amountMl, vesselKey: vesselKey);
  @override Future<void> logWellness({double? mood, double? energy, double? stress, String? notes}) => _delegate.logWellness(mood: mood, energy: energy, stress: stress, notes: notes);
  @override Future<void> logWeight({required double valueKg, required String timeOfDay, double? bodyFatPct}) => _delegate.logWeight(valueKg: valueKg, timeOfDay: timeOfDay, bodyFatPct: bodyFatPct);
  @override Future<IngestResult> submitIngest({required String metricType, required double value, required String unit, required String source, required DateTime recordedAt, String? idempotencyKey, Map<String, dynamic>? metadata}) => _delegate.submitIngest(metricType: metricType, value: value, unit: unit, source: source, recordedAt: recordedAt, idempotencyKey: idempotencyKey, metadata: metadata);
  @override Future<TodayTimeline> getTodayTimeline({int limit = 50, String? before}) => _delegate.getTodayTimeline(limit: limit, before: before);
  @override Future<void> deleteEvent(String eventId) => _delegate.deleteEvent(eventId);
  @override Future<SessionIngestResult> submitSession({required String sessionType, required String source, required DateTime recordedAt, DateTime? endedAt, required List<SessionMetricPayload> metrics, String? notes, Map<String, dynamic>? metadata}) => _delegate.submitSession(sessionType: sessionType, source: source, recordedAt: recordedAt, endedAt: endedAt, metrics: metrics, notes: notes, metadata: metadata);
  @override Future<BulkIngestResult> bulkIngest({required String source, required List<BulkEventPayload> events}) => _delegate.bulkIngest(source: source, events: events);
}
