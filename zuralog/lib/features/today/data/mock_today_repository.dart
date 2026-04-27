/// Zuralog — Mock Today Repository.
///
/// In-memory stub implementation of [TodayRepositoryInterface] used in
/// debug builds (`kDebugMode`) to allow the Today tab to render without a
/// running backend.
///
/// Simulates realistic network latency (400 ms) and returns fixed health data
/// that exercises every Today-tab widget path.
library;

import 'package:zuralog/features/today/data/today_repository.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/supplement_scan_result.dart';
import 'package:zuralog/features/today/domain/supplement_today_entry.dart';
import 'package:zuralog/features/today/domain/today_models.dart';

// ── MockTodayRepository ───────────────────────────────────────────────────────

/// Debug-only stub implementation of [TodayRepositoryInterface].
///
/// Returns hardcoded fixture data after a short artificial delay so that
/// loading skeletons and data states are both exercisable in development.
final class MockTodayRepository implements TodayRepositoryInterface {
  /// Creates a const [MockTodayRepository].
  const MockTodayRepository();

  static const Duration _delay = Duration(milliseconds: 400);

  // ── Health Score ─────────────────────────────────────────────────────────

  @override
  Future<HealthScoreData> getHealthScore() async {
    await Future<void>.delayed(_delay);
    return const HealthScoreData(
      score: 76,
      trend: [68, 71, 74, 72, 75, 73, 76],
      commentary:
          'Your score improved 3 points from yesterday. Sleep quality is driving today\'s gain.',
    );
  }

  // ── Today Feed ────────────────────────────────────────────────────────────

  @override
  Future<TodayFeedData> getTodayFeed() async {
    await Future<void>.delayed(_delay);
    return TodayFeedData(
      insights: _mockInsights(),
      streak: const StreakData(
        currentStreak: 7,
        isFrozen: false,
        longestStreak: 14,
      ),
    );
  }

  @override
  void invalidateFeedCache() {
    // No-op: mock has no cache to invalidate.
  }

  // ── Insights ──────────────────────────────────────────────────────────────

  @override
  Future<InsightDetail> getInsightDetail(String id) async {
    await Future<void>.delayed(_delay);

    // Return matching fixture or fall back to a generic detail.
    final details = _mockInsightDetails();
    return details.firstWhere(
      (d) => d.id == id,
      orElse: () => details.first,
    );
  }

  @override
  Future<void> markInsightRead(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // No-op in mock — read state is not persisted.
  }

  @override
  Future<void> dismissInsight(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // No-op in mock.
  }

  // ── Unified Ingest ─────────────────────────────────────────────────────────

  @override
  Future<IngestResult> submitIngest({
    required String metricType,
    required double value,
    required String unit,
    required String source,
    required DateTime recordedAt,
    String? idempotencyKey,
    Map<String, dynamic>? metadata,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return IngestResult(
      eventId: 'mock-event-id',
      dailyTotal: value,
      unit: unit,
      date: '${recordedAt.year}-${recordedAt.month.toString().padLeft(2, '0')}-${recordedAt.day.toString().padLeft(2, '0')}',
    );
  }

  @override
  Future<TodayTimeline> getTodayTimeline({
    int limit = 50,
    String? before,
  }) async {
    await Future<void>.delayed(_delay);
    return const TodayTimeline(events: [], nextCursor: null);
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // No-op in mock.
  }

  @override
  Future<SessionIngestResult> submitSession({
    required String sessionType,
    required String source,
    required DateTime recordedAt,
    DateTime? endedAt,
    String? notes,
    required List<SessionMetricPayload> metrics,
    Map<String, dynamic>? metadata,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return SessionIngestResult(
      sessionId: 'mock-session-id',
      eventIds: List.generate(metrics.length, (i) => 'mock-event-$i'),
      date: '${recordedAt.year}-${recordedAt.month.toString().padLeft(2, '0')}-${recordedAt.day.toString().padLeft(2, '0')}',
    );
  }

  @override
  Future<BulkIngestResult> bulkIngest({
    required String source,
    required List<BulkEventPayload> events,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return BulkIngestResult(
      taskId: 'mock-task-id',
      eventCount: events.length,
      status: 'accepted',
    );
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  @override
  Future<NotificationPage> getNotifications({int page = 1}) async {
    await Future<void>.delayed(_delay);
    final now = DateTime.now();
    return NotificationPage(
      items: [
        NotificationItem(
          id: 'n1',
          title: 'Your health score improved!',
          body: 'You\'re up 4 points since yesterday — keep it up.',
          isRead: false,
          deepLinkRoute: 'data',
          receivedAt: now.subtract(const Duration(hours: 1)),
        ),
        NotificationItem(
          id: 'n2',
          title: 'New insight: Sleep trend',
          body:
              'Your deep sleep has increased by 12% over the past week. Tap to learn more.',
          isRead: false,
          deepLinkRoute: 'insightDetail',
          deepLinkId: 'i1',
          receivedAt: now.subtract(const Duration(hours: 3)),
        ),
        NotificationItem(
          id: 'n3',
          title: '7-day streak — keep going!',
          body:
              'You\'ve logged data 7 days in a row. One more day to beat your personal best.',
          isRead: true,
          receivedAt: now.subtract(const Duration(days: 1, hours: 2)),
        ),
        NotificationItem(
          id: 'n4',
          title: 'Resting heart rate trending down',
          body:
              'Your RHR has dropped 5 bpm over the past 2 weeks — a strong recovery signal.',
          isRead: true,
          deepLinkRoute: 'insightDetail',
          deepLinkId: 'i3',
          receivedAt: now.subtract(const Duration(days: 2)),
        ),
      ],
      totalCount: 4,
      page: 1,
      hasMore: false,
    );
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // No-op in mock.
  }

  // ── Daily Goals ───────────────────────────────────────────────────────────

  @override
  Future<List<DailyGoal>> getDailyGoals() async {
    await Future<void>.delayed(_delay);
    return const [
      DailyGoal(
        id: 'goal-steps',
        label: 'Steps',
        current: 6240,
        target: 8000,
        unit: 'steps',
      ),
      DailyGoal(
        id: 'goal-water',
        label: 'Water',
        current: 600,
        target: 2000,
        unit: 'ml',
      ),
      DailyGoal(
        id: 'goal-sleep',
        label: 'Sleep',
        current: 5.9,
        target: 7,
        unit: 'hrs',
      ),
    ];
  }

  // ── Today Log Summary ─────────────────────────────────────────────────────

  @override
  Future<TodayLogSummary> getTodayLogSummary() async {
    await Future<void>.delayed(_delay);
    return TodayLogSummary.empty;
  }

  @override
  Future<Set<String>> getUserLoggedTypes() async {
    await Future<void>.delayed(_delay);
    return const <String>{};
  }

  // ── Supplements ───────────────────────────────────────────────────────────

  @override
  Future<List<SupplementEntry>> getSupplementsList() async {
    await Future<void>.delayed(_delay);
    return const [];
  }

  @override
  Future<List<SupplementEntry>> updateSupplementsList(
      List<SupplementEntry> supplements) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return supplements;
  }

  @override
  Future<List<SupplementTodayLogEntry>> getSupplementsTodayLog() async {
    await Future<void>.delayed(_delay);
    return const [];
  }

  @override
  Future<void> deleteSupplementLogEntry(String logEntryId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // No-op in mock.
  }

  @override
  Future<SupplementScanResult> scanSupplementLabel({
    String? imageBase64,
    String? barcode,
  }) async {
    await Future<void>.delayed(_delay);
    return const SupplementScanResult(
      name: 'Vitamin D3',
      doseAmount: 5000.0,
      doseUnit: 'IU',
      form: 'softgel',
      confidence: 0.92,
    );
  }

  // ── Log Endpoints ─────────────────────────────────────────────────────────

  @override
  Future<void> logSleep({
    required DateTime bedtime,
    required DateTime wakeTime,
    required int durationMinutes,
    int? qualityRating,
    int? interruptions,
    List<String> factors = const [],
    String? notes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // No-op in mock.
  }

  @override
  Future<void> logRun({
    required String activityType,
    required double distanceKm,
    required int durationSeconds,
    int? avgPaceSecondsPerKm,
    String? effortLevel,
    String? notes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // No-op in mock.
  }

  @override
  Future<void> logMeal({
    required String mealType,
    required bool quickMode,
    String? description,
    int? caloriesKcal,
    List<String> feelChips = const [],
    List<String> tags = const [],
    String? notes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // No-op in mock.
  }

  @override
  Future<void> logSupplements({
    required List<String> takenIds,
    String? notes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // No-op in mock.
  }

  @override
  Future<void> logSymptom({
    required List<String> bodyAreas,
    required String severity,
    String? symptomType,
    String? timing,
    String? notes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // No-op in mock.
  }

  @override
  Future<void> logSteps({
    required int steps,
    String mode = 'add',
    String source = 'manual',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // No-op in mock.
  }

  @override
  Future<void> logWater({
    required double amountMl,
    String? vesselKey,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // No-op in mock.
  }

  @override
  Future<void> logWellness({
    double? mood,
    double? energy,
    double? stress,
    String? notes,
    String? aiSummary,
    String? transcript,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // No-op in mock.
  }

  @override
  Future<WellnessParseResult> parseWellnessTranscript(
      String transcript) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return const WellnessParseResult(
      mood: 6.0,
      energy: 5.0,
      stress: 4.0,
      tags: ['calm'],
      summary: 'Seems like a decent day.',
    );
  }

  @override
  Future<void> logWeight({
    required double valueKg,
    required String timeOfDay,
    double? bodyFatPct,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // No-op in mock.
  }

  @override
  Future<Map<String, dynamic>> getLatestLogValues(Set<String> types) async {
    return const {};
  }

  @override
  Future<List<double?>> getWeightHistory({int days = 7}) async {
    return List<double?>.filled(days, null);
  }

  // ── Fixture Builders ──────────────────────────────────────────────────────

  List<InsightCard> _mockInsights() {
    final now = DateTime.now();
    return [
      InsightCard(
        id: 'i1',
        title: 'Sleep quality improved this week',
        summary:
            'Your deep sleep increased by 12% over the last 7 days, correlating with your earlier bedtimes.',
        type: InsightType.trend,
        category: 'sleep',
        isRead: false,
        priorityScore: 0.92,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      InsightCard(
        id: 'i2',
        title: 'Step count on track for weekly goal',
        summary:
            'You\'re averaging 8,400 steps/day — 84% of your 10,000 step goal. A 20-min walk today closes the gap.',
        type: InsightType.recommendation,
        category: 'activity',
        isRead: false,
        priorityScore: 0.81,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      InsightCard(
        id: 'i3',
        title: 'Resting heart rate trending down',
        summary:
            'Your RHR has dropped from 68 to 63 bpm over 14 days — an indicator of improving cardiovascular fitness.',
        type: InsightType.trend,
        category: 'heart',
        isRead: true,
        priorityScore: 0.74,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  List<InsightDetail> _mockInsightDetails() {
    final now = DateTime.now();
    return [
      InsightDetail(
        id: 'i1',
        title: 'Sleep quality improved this week',
        summary:
            'Your deep sleep increased by 12% over the last 7 days, correlating with your earlier bedtimes.',
        reasoning:
            'Comparing your sleep stages over the past two weeks, deep sleep duration rose from '
            'an average of 68 min to 76 min per night. This improvement coincides with a consistent '
            'shift of your bedtime from 11:30 PM to 10:45 PM. Research consistently links earlier, '
            'more consistent sleep onset with higher slow-wave sleep percentages.',
        type: InsightType.trend,
        category: 'sleep',
        dataPoints: const [
          InsightDataPoint(label: 'Mon', value: 62),
          InsightDataPoint(label: 'Tue', value: 65),
          InsightDataPoint(label: 'Wed', value: 70),
          InsightDataPoint(label: 'Thu', value: 68),
          InsightDataPoint(label: 'Fri', value: 74),
          InsightDataPoint(label: 'Sat', value: 78),
          InsightDataPoint(label: 'Sun', value: 76),
        ],
        sources: const [
          InsightSource(name: 'Apple Health', iconName: 'apple_health'),
        ],
        chartTitle: '7-day deep sleep (min)',
        chartUnit: 'min',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      InsightDetail(
        id: 'i2',
        title: 'Step count on track for weekly goal',
        summary:
            'You\'re averaging 8,400 steps/day — 84% of your 10,000 step goal.',
        reasoning:
            'Your daily step count over the last 7 days averages 8,400. At this pace you\'ll end the '
            'week ~11% short of your 10,000-step goal. Adding one 20-minute brisk walk (≈2,200 steps) '
            'today would close that gap. Your most active day was Saturday with 11,200 steps.',
        type: InsightType.recommendation,
        category: 'activity',
        dataPoints: const [
          InsightDataPoint(label: 'Mon', value: 7800),
          InsightDataPoint(label: 'Tue', value: 9200),
          InsightDataPoint(label: 'Wed', value: 6500),
          InsightDataPoint(label: 'Thu', value: 8900),
          InsightDataPoint(label: 'Fri', value: 8100),
          InsightDataPoint(label: 'Sat', value: 11200),
          InsightDataPoint(label: 'Sun', value: 7400),
        ],
        sources: const [
          InsightSource(name: 'Apple Health', iconName: 'apple_health'),
        ],
        chartTitle: '7-day step count',
        chartUnit: 'steps',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      InsightDetail(
        id: 'i3',
        title: 'Resting heart rate trending down',
        summary:
            'Your RHR dropped from 68 to 63 bpm over 14 days — a strong cardiovascular fitness signal.',
        reasoning:
            'A declining resting heart rate over several weeks typically indicates improving '
            'cardiovascular efficiency. Your RHR peaked at 68 bpm two weeks ago and has steadily '
            'declined to 63 bpm today. This trajectory correlates with your increased Zone 2 '
            'training volume (+18% this month) and improved sleep quality.',
        type: InsightType.trend,
        category: 'heart',
        dataPoints: const [
          InsightDataPoint(label: 'W1', value: 68),
          InsightDataPoint(label: 'W2', value: 66),
          InsightDataPoint(label: 'W3', value: 65),
          InsightDataPoint(label: 'W4', value: 63),
        ],
        sources: const [
          InsightSource(name: 'Apple Health', iconName: 'apple_health'),
          InsightSource(name: 'Strava', iconName: 'strava'),
        ],
        chartTitle: '4-week RHR trend',
        chartUnit: 'bpm',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}
