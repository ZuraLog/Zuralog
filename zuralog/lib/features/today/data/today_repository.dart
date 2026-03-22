/// Zuralog — Today Repository.
///
/// Data layer for the Today tab. Wraps all API calls for:
///   - Health score + 7-day trend  (`GET /api/v1/health-score`)
///   - AI insights list             (`GET /api/v1/insights`)
///   - Single insight detail        (`GET /api/v1/insights/:id`)
///   - Mark insight read/dismissed  (`PATCH /api/v1/insights/:id`)
///   - Current streak               (`GET /api/v1/streaks`)
///   - Quick log submit             (`POST /api/v1/quick-log`)
///   - Notifications history        (`GET /api/v1/notifications`)
///   - Mark notification read       (`PATCH /api/v1/notifications/:id`)
///
/// All responses are deserialized into strongly-typed domain models.
/// Includes a 5-minute in-memory TTL cache for the feed data to avoid
/// redundant requests on rapid tab switches.
library;

import 'package:dio/dio.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/today_models.dart';

// ── TodayRepositoryInterface ──────────────────────────────────────────────────

/// Abstract contract for all Today-tab data operations.
///
/// Implemented by [TodayRepository] (real) and [MockTodayRepository] (debug).
abstract interface class TodayRepositoryInterface {
  /// Fetches the current health score and 7-day trend.
  Future<HealthScoreData> getHealthScore();

  /// Fetches all feed data in parallel: insights and streak.
  Future<TodayFeedData> getTodayFeed();

  /// Invalidates the feed cache, forcing the next [getTodayFeed] call to
  /// fetch fresh data from the server.
  void invalidateFeedCache();

  /// Fetches the full detail for a single insight by [id].
  Future<InsightDetail> getInsightDetail(String id);

  /// Marks insight [id] as read.
  Future<void> markInsightRead(String id);

  /// Dismisses insight [id].
  Future<void> dismissInsight(String id);

  /// Submits a quick-log payload.
  @Deprecated('Use submitIngest instead')
  Future<void> submitQuickLog(Map<String, dynamic> payload);

  /// Submits a single health event via the unified ingest API.
  Future<IngestResult> submitIngest({
    required String metricType,
    required double value,
    required String unit,
    required String source,
    required DateTime recordedAt,
    String? idempotencyKey,
    Map<String, dynamic>? metadata,
  });

  /// Fetches the paginated today timeline.
  Future<TodayTimeline> getTodayTimeline({int limit = 50, String? before});

  /// Soft-deletes a health event by ID.
  Future<void> deleteEvent(String eventId);

  /// Fetches the paginated notification history.
  Future<NotificationPage> getNotifications({int page = 1});

  /// Marks notification [id] as read.
  Future<void> markNotificationRead(String id);

  /// Fetch the user's daily goals with today's progress.
  /// Returns an empty list if the user has no goals configured.
  Future<List<DailyGoal>> getDailyGoals();

  /// Fetches the aggregated summary of today's logs.
  ///
  /// Returns [TodayLogSummary.empty] on any network or parse failure.
  Future<TodayLogSummary> getTodayLogSummary();

  /// Fetches the set of metric types the user has ever logged.
  ///
  /// Returns an empty set on any network or parse failure.
  Future<Set<String>> getUserLoggedTypes();

  /// Fetch the user's saved supplement list.
  Future<List<SupplementEntry>> getSupplementsList();

  /// Replace the user's supplement list with [supplements].
  Future<List<SupplementEntry>> updateSupplementsList(
      List<SupplementEntry> supplements);

  /// Submit a sleep log entry.
  Future<void> logSleep({
    required DateTime bedtime,
    required DateTime wakeTime,
    required int durationMinutes,
    int? qualityRating,
    int? interruptions,
    List<String> factors,
    String? notes,
  });

  /// Submit a run or cardio activity log.
  Future<void> logRun({
    required String activityType,
    required double distanceKm,
    required int durationSeconds,
    int? avgPaceSecondsPerKm,
    String? effortLevel,
    String? notes,
  });

  /// Submit a meal log entry.
  Future<void> logMeal({
    required String mealType,
    required bool quickMode,
    String? description,
    int? caloriesKcal,
    List<String> feelChips,
    List<String> tags,
    String? notes,
  });

  /// Submit a supplements log — which items were taken today.
  Future<void> logSupplements({
    required List<String> takenIds,
    String? notes,
  });

  /// Submit a symptom log entry.
  Future<void> logSymptom({
    required List<String> bodyAreas,
    required String severity,
    String? symptomType,
    String? timing,
    String? notes,
  });

  /// Submit a step count log entry.
  Future<void> logSteps({
    required int steps,
    String mode = 'add',
    String source = 'manual',
  });

  /// Submit a water intake log entry.
  Future<void> logWater({
    required double amountMl,
    String? vesselKey,
  });

  /// Submit a wellness check-in.
  ///
  /// At least one of [mood], [energy], or [stress] must be non-null.
  Future<void> logWellness({
    double? mood,
    double? energy,
    double? stress,
    String? notes,
  });

  /// Submit a body weight log entry. Always in kg — caller converts.
  Future<void> logWeight({required double valueKg});

  /// Fetch the most recent log entry for each of the requested [types].
  ///
  /// Returns a map keyed by metric type. Types the user has never logged
  /// are absent. The Cloud Brain is the single source of truth — all
  /// data ingested from connected health apps is surfaced here.
  ///
  /// Example:
  /// ```dart
  /// final latest = await repo.getLatestLogValues({'weight', 'steps'});
  /// // latest['weight'] → { 'value_kg': 78.4, 'logged_at': '...', 'source': 'apple_health' }
  /// ```
  Future<Map<String, dynamic>> getLatestLogValues(Set<String> types);
}

// ── TodayRepository ──────────────────────────────────────────────────────────

/// Repository for all Today-tab data.
///
/// Injected via [todayRepositoryProvider]. All public methods throw
/// [DioException] on network errors unless a cached fallback is available.
class TodayRepository implements TodayRepositoryInterface {
  /// Creates a [TodayRepository] backed by the given [ApiClient].
  TodayRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ── Cache ──────────────────────────────────────────────────────────────────

  _CacheEntry<HealthScoreData>? _scoreCache;
  _CacheEntry<TodayFeedData>? _feedCache;

  static const Duration _cacheTtl = Duration(minutes: 5);

  // ── Health Score ──────────────────────────────────────────────────────────

  /// Fetches the current health score and 7-day trend.
  ///
  /// Results are cached for 5 minutes. Falls back to stale cache on error.
  @override
  Future<HealthScoreData> getHealthScore() async {
    if (_scoreCache != null && !_scoreCache!.isExpired) {
      return _scoreCache!.value;
    }
    try {
      final response = await _api.get('/api/v1/health-score');
      final data = HealthScoreData.fromJson(
        response.data as Map<String, dynamic>,
      );
      _scoreCache = _CacheEntry(value: data);
      return data;
    } on DioException {
      if (_scoreCache != null) return _scoreCache!.value;
      rethrow;
    }
  }

  // ── Today Feed ─────────────────────────────────────────────────────────────

  /// Fetches all feed data in parallel: insights and streak.
  ///
  /// Cached for 5 minutes. Each constituent call can fail independently;
  /// partial data is returned rather than failing the entire feed.
  @override
  Future<TodayFeedData> getTodayFeed() async {
    if (_feedCache != null && !_feedCache!.isExpired) {
      return _feedCache!.value;
    }

    // Fire all requests in parallel.
    final results = await Future.wait([
      _fetchInsights(),
      _fetchStreak(),
    ], eagerError: false);

    final data = TodayFeedData(
      insights: results[0] as List<InsightCard>,
      streak: results[1] as StreakData?,
    );
    _feedCache = _CacheEntry(value: data);
    return data;
  }

  /// Invalidates the feed cache, forcing the next [getTodayFeed] call to
  /// fetch fresh data from the server.
  @override
  void invalidateFeedCache() {
    _feedCache = null;
    _scoreCache = null;
  }

  // ── Insights ───────────────────────────────────────────────────────────────

  Future<List<InsightCard>> _fetchInsights() async {
    try {
      final response = await _api.get(
        '/api/v1/insights',
        queryParameters: {'limit': 20},
      );
      final list = response.data['insights'] as List<dynamic>? ?? [];
      return list
          .map((e) => InsightCard.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException {
      return [];
    }
  }

  /// Fetches the full detail for a single insight by [id].
  @override
  Future<InsightDetail> getInsightDetail(String id) async {
    final response = await _api.get('/api/v1/insights/$id');
    return InsightDetail.fromJson(response.data as Map<String, dynamic>);
  }

  /// Marks insight [id] as read.
  @override
  Future<void> markInsightRead(String id) async {
    await _api.patch('/api/v1/insights/$id', body: {'action': 'read'});
    _feedCache = null; // Invalidate so the read state refreshes.
  }

  /// Dismisses insight [id].
  @override
  Future<void> dismissInsight(String id) async {
    await _api.patch('/api/v1/insights/$id', body: {'action': 'dismiss'});
    _feedCache = null;
  }

  // ── Streaks ────────────────────────────────────────────────────────────────

  Future<StreakData?> _fetchStreak() async {
    try {
      final response = await _api.get('/api/v1/streaks');
      return StreakData.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }

  // ── Quick Log ──────────────────────────────────────────────────────────────

  /// Submits a quick-log payload to the API.
  ///
  /// The keys and values in [payload] are determined by the caller.
  @override
  Future<void> submitQuickLog(Map<String, dynamic> payload) async {
    await _api.post('/api/v1/quick-log', data: payload);
    invalidateFeedCache();
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
    final offset = recordedAt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hh = offset.inHours.abs().toString().padLeft(2, '0');
    final mm = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final recordedAtStr =
        '${recordedAt.toLocal().toIso8601String().split('.').first}$sign$hh:$mm';

    final resp = await _api.post('/api/v1/ingest', data: {
      'metric_type': metricType,
      'value': value,
      'unit': unit,
      'source': source,
      'recorded_at': recordedAtStr,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (metadata != null) 'metadata': metadata,
    });
    invalidateFeedCache();
    return IngestResult.fromJson(resp.data as Map<String, dynamic>);
  }

  // ── Today Timeline ────────────────────────────────────────────────────────

  @override
  Future<TodayTimeline> getTodayTimeline({
    int limit = 50,
    String? before,
  }) async {
    final resp = await _api.get('/api/v1/today/timeline', queryParameters: {
      'limit': limit,
      if (before != null) 'before': before,
    });
    return TodayTimeline.fromJson(resp.data as Map<String, dynamic>);
  }

  // ── Delete Event ──────────────────────────────────────────────────────────

  @override
  Future<void> deleteEvent(String eventId) async {
    await _api.delete('/api/v1/events/$eventId');
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  /// Fetches the paginated notification history.
  ///
  /// [page] — 1-indexed page number.
  @override
  Future<NotificationPage> getNotifications({int page = 1}) async {
    final response = await _api.get(
      '/api/v1/notifications',
      queryParameters: {'page': page, 'per_page': 30},
    );
    return NotificationPage.fromJson(response.data as Map<String, dynamic>);
  }

  /// Marks notification [id] as read.
  @override
  Future<void> markNotificationRead(String id) async {
    await _api.patch('/api/v1/notifications/$id', body: {'read': true});
  }

  // ── Daily Goals ────────────────────────────────────────────────────────────

  /// Goal types that are inherently daily-relevant regardless of their period.
  static const _dailyGoalTypes = {
    GoalType.stepCount,
    GoalType.waterIntake,
    GoalType.dailyCalorieLimit,
    GoalType.sleepDuration,
  };

  @override
  Future<List<DailyGoal>> getDailyGoals() async {
    try {
      final response = await _api.get('/api/v1/goals');
      final goalList = GoalList.fromJson(response.data as Map<String, dynamic>);
      return goalList.goals
          .where(
            (g) =>
                g.period == GoalPeriod.daily ||
                _dailyGoalTypes.contains(g.type),
          )
          .map(
            (g) => DailyGoal(
              id: g.id,
              label: _goalLabel(g),
              current: g.currentValue,
              target: g.targetValue,
              unit: g.unit,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Returns a short human-readable label for a goal.
  static String _goalLabel(Goal goal) {
    return switch (goal.type) {
      GoalType.stepCount => 'Steps',
      GoalType.waterIntake => 'Water',
      GoalType.dailyCalorieLimit => 'Calories',
      GoalType.sleepDuration => 'Sleep',
      GoalType.weightTarget => 'Weight',
      GoalType.weeklyRunCount => 'Runs',
      GoalType.custom => goal.title.isNotEmpty ? goal.title : 'Goal',
    };
  }

  // ── Today Log Summary ──────────────────────────────────────────────────────

  @override
  Future<TodayLogSummary> getTodayLogSummary() async {
    final tzOffset = DateTime.now().timeZoneOffset.inMinutes;
    final response = await _api.get(
      '/api/v1/quick-log/summary/today',
      queryParameters: {'tz_offset': tzOffset},
    );
    final data = response.data as Map<String, dynamic>;
    final loggedTypes = (data['logged_types'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toSet();
    final rawValues =
        (data['latest_values'] as Map<String, dynamic>?) ?? {};
    return TodayLogSummary(
      loggedTypes: loggedTypes,
      latestValues: rawValues,
    );
  }

  @override
  Future<Set<String>> getUserLoggedTypes() async {
    final response =
        await _api.get('/api/v1/quick-log/my-metric-types');
    final data = response.data as Map<String, dynamic>;
    return (data['metric_types'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toSet();
  }

  // ── Log Submission ─────────────────────────────────────────────────────────

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
    await _api.post('/api/v1/quick-log/sleep', data: {
      'bedtime': bedtime.toUtc().toIso8601String(),
      'wake_time': wakeTime.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'quality_rating': ?qualityRating,
      'interruptions': ?interruptions,
      if (factors.isNotEmpty) 'factors': factors,
      'notes': ?notes,
      'source': 'manual',
      'logged_at': DateTime.now().toUtc().toIso8601String(),
    });
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
    await _api.post('/api/v1/quick-log/run', data: {
      'activity_type': activityType,
      'distance_km': distanceKm,
      'duration_seconds': durationSeconds,
      'avg_pace_seconds_per_km': ?avgPaceSecondsPerKm,
      'effort_level': ?effortLevel,
      'notes': ?notes,
      'source': 'manual',
      'logged_at': DateTime.now().toUtc().toIso8601String(),
    });
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
    await _api.post('/api/v1/quick-log/meal', data: {
      'meal_type': mealType,
      'quick_mode': quickMode,
      'description': ?description,
      'calories_kcal': ?caloriesKcal,
      if (feelChips.isNotEmpty) 'feel_chips': feelChips,
      if (tags.isNotEmpty) 'tags': tags,
      'notes': ?notes,
      'logged_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> logSupplements({
    required List<String> takenIds,
    String? notes,
  }) async {
    await _api.post('/api/v1/quick-log/supplements', data: {
      'taken_supplement_ids': takenIds,
      'notes': ?notes,
      'logged_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> logSymptom({
    required List<String> bodyAreas,
    required String severity,
    String? symptomType,
    String? timing,
    String? notes,
  }) async {
    await _api.post('/api/v1/quick-log/symptom', data: {
      'body_areas': bodyAreas,
      'severity': severity,
      'symptom_type': ?symptomType,
      'timing': ?timing,
      'notes': ?notes,
      'logged_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> logSteps({
    required int steps,
    String mode = 'add',
    String source = 'manual',
  }) async {
    await _api.post('/api/v1/quick-log/steps', data: {
      'steps': steps,
      'mode': mode,
      'source': source,
      'logged_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> logWater({
    required double amountMl,
    String? vesselKey,
  }) async {
    await _api.post('/api/v1/quick-log/water', data: {
      'amount_ml': amountMl,
      'vessel_key': ?vesselKey,
      'logged_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> logWellness({
    double? mood,
    double? energy,
    double? stress,
    String? notes,
  }) async {
    await _api.post('/api/v1/quick-log/wellness', data: {
      'mood': ?mood,
      'energy': ?energy,
      'stress': ?stress,
      'notes': ?notes,
      'logged_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> logWeight({required double valueKg}) async {
    await _api.post('/api/v1/quick-log/weight', data: {
      'value_kg': valueKg,
      'logged_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<Map<String, dynamic>> getLatestLogValues(Set<String> types) async {
    if (types.isEmpty) return const {};
    final typesParam = types.join(',');
    final response = await _api.get(
      '/api/v1/quick-log/latest',
      queryParameters: {'types': typesParam},
    );
    return (response.data as Map<String, dynamic>?) ?? const {};
  }

  // ── Supplements List ───────────────────────────────────────────────────────

  @override
  Future<List<SupplementEntry>> getSupplementsList() async {
    final response = await _api.get('/api/v1/quick-log/user/supplements-list');
    final data = response.data as Map<String, dynamic>;
    final items = (data['supplements'] as List<dynamic>?) ?? [];
    return items.map((item) => SupplementEntry(
      id: item['id'] as String,
      name: item['name'] as String,
      dose: item['dose'] as String?,
      timing: item['timing'] as String?,
    )).toList();
  }

  @override
  Future<List<SupplementEntry>> updateSupplementsList(
      List<SupplementEntry> supplements) async {
    final response = await _api.post(
      '/api/v1/quick-log/user/supplements-list',
      data: {
        'supplements': supplements.map((s) => {
          'name': s.name,
          'dose': ?s.dose,
          'timing': ?s.timing,
        }).toList(),
      },
    );
    final data = response.data as Map<String, dynamic>;
    final items = (data['supplements'] as List<dynamic>?) ?? [];
    return items.map((item) => SupplementEntry(
      id: item['id'] as String,
      name: item['name'] as String,
      dose: item['dose'] as String?,
      timing: item['timing'] as String?,
    )).toList();
  }
}

// ── _CacheEntry ───────────────────────────────────────────────────────────────

class _CacheEntry<T> {
  _CacheEntry({required this.value}) : _createdAt = DateTime.now();

  final T value;
  final DateTime _createdAt;

  bool get isExpired =>
      DateTime.now().difference(_createdAt) > TodayRepository._cacheTtl;
}
