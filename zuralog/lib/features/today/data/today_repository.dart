/// Zuralog — Today Repository.
///
/// Data layer for the Today tab. Wraps all API calls for:
///   - Health score + 7-day trend  (`GET /api/v1/health-score`)
///   - AI insights list             (`GET /api/v1/insights`)
///   - Single insight detail        (`GET /api/v1/insights/:id`)
///   - Mark insight read/dismissed  (`PATCH /api/v1/insights/:id`)
///   - Current streak               (`GET /api/v1/streaks`)
///   - Unified ingest               (`POST /api/v1/ingest`)
///   - Notifications history        (`GET /api/v1/notifications`)
///   - Mark notification read       (`PATCH /api/v1/notifications/:id`)
///
/// All responses are deserialized into strongly-typed domain models.
/// Includes a 5-minute in-memory TTL cache for the feed data to avoid
/// redundant requests on rapid tab switches.
library;

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/supplement_conflict.dart';
import 'package:zuralog/features/today/domain/supplement_scan_result.dart';
import 'package:zuralog/features/today/domain/supplement_today_entry.dart';
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

  /// Submits a session of related metrics via POST /api/v1/ingest/session.
  Future<SessionIngestResult> submitSession({
    required String sessionType,
    required String source,
    required DateTime recordedAt,
    DateTime? endedAt,
    String? notes,
    required List<SessionMetricPayload> metrics,
    Map<String, dynamic>? metadata,
  });

  /// Submits a batch of events via POST /api/v1/ingest/bulk.
  Future<BulkIngestResult> bulkIngest({
    required String source,
    required List<BulkEventPayload> events,
  });

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

  /// Fetches today's supplement_taken log entries from the server.
  ///
  /// Returns supplement_id + log_id pairs for all supplements already logged
  /// today (UTC day). Returns empty list on any failure.
  Future<List<SupplementTodayLogEntry>> getSupplementsTodayLog();

  /// Deletes a supplement_taken log entry by its server log ID.
  Future<void> deleteSupplementLogEntry(String logEntryId);

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
    String? aiSummary,
    String? transcript,
  });

  /// Sends a free-text [transcript] to the AI parser and returns structured
  /// wellness values extracted from the text.
  Future<WellnessParseResult> parseWellnessTranscript(String transcript);

  /// Submit a body weight log entry.
  ///
  /// [valueKg] is always in kilograms.
  /// [timeOfDay] must be one of `'morning'`, `'afternoon'`, or `'evening'`.
  /// [bodyFatPct] is the body fat percentage (1.0–80.0) or null.
  Future<void> logWeight({
    required double valueKg,
    required String timeOfDay,
    double? bodyFatPct,
  });

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

  /// Fetch up to [days] of daily-averaged weight readings, oldest first.
  ///
  /// Returns a list of exactly [days] entries: index 0 = oldest, index [days-1] = today.
  /// Null means no weigh-in was recorded that day.
  Future<List<double?>> getWeightHistory({int days = 7});

  /// Sends a supplement label image or barcode to the AI scan endpoint and
  /// returns the parsed supplement information.
  ///
  /// At least one of [imageBase64] or [barcode] must be non-null.
  Future<SupplementScanResult> scanSupplementLabel({
    String? imageBase64,
    String? barcode,
  });

  /// Checks whether [name] conflicts with any supplement in [existingNames].
  ///
  /// Pass [excludeId] when editing an existing supplement so that item's own
  /// name is not treated as a conflict.
  Future<SupplementConflict> checkSupplementConflicts({
    required String name,
    required List<String> existingNames,
    String? excludeId,
  });
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

    debugPrint('[TodayRepo] submitIngest → POST /api/v1/ingest '
        'metric_type=$metricType value=$value unit=$unit '
        'recorded_at=$recordedAtStr');
    final resp = await _api.post('/api/v1/ingest', data: {
      'metric_type': metricType,
      'value': value,
      'unit': unit,
      'source': source,
      'recorded_at': recordedAtStr,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (metadata != null) 'metadata': metadata,
    });
    debugPrint('[TodayRepo] submitIngest ← HTTP ${resp.statusCode} '
        'body=${resp.data}');
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

  // ── Session Ingest ─────────────────────────────────────────────────────────

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
    final resp = await _api.post('/api/v1/ingest/session', data: {
      'activity_type': sessionType,
      'source': source,
      'started_at': _isoWithOffset(recordedAt),
      if (endedAt != null) 'ended_at': _isoWithOffset(endedAt),
      if (notes != null) 'notes': notes,
      'metrics': metrics.map((m) => m.toJson()).toList(),
      if (metadata != null) 'session_metadata': metadata,
    });
    invalidateFeedCache();
    return SessionIngestResult.fromJson(resp.data as Map<String, dynamic>);
  }

  static String _isoWithOffset(DateTime dt) {
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hh = offset.inHours.abs().toString().padLeft(2, '0');
    final mm = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '${dt.toLocal().toIso8601String().split('.').first}$sign$hh:$mm';
  }

  // ── Bulk Ingest ───────────────────────────────────────────────────────────

  @override
  Future<BulkIngestResult> bulkIngest({
    required String source,
    required List<BulkEventPayload> events,
  }) async {
    final resp = await _api.post('/api/v1/ingest/bulk', data: {
      'source': source,
      'events': events.map((e) => e.toJson()).toList(),
    });
    invalidateFeedCache();
    return BulkIngestResult.fromJson(resp.data as Map<String, dynamic>);
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
      GoalType.dailyProteinMin => 'Protein',
      GoalType.dailyCarbsMax => 'Carbs',
      GoalType.dailyFatMax => 'Fat',
      GoalType.dailyFiberMin => 'Fiber',
      GoalType.dailySodiumMax => 'Sodium',
      GoalType.dailySugarMax => 'Sugar',
      GoalType.custom => goal.title.isNotEmpty ? goal.title : 'Goal',
    };
  }

  // ── Today Log Summary ──────────────────────────────────────────────────────

  @override
  Future<TodayLogSummary> getTodayLogSummary() async {
    debugPrint('[TodayRepo] getTodayLogSummary → GET /api/v1/today/summary');
    final response = await _api.get('/api/v1/today/summary');
    final data = response.data as Map<String, dynamic>;
    final metrics = (data['metrics'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final loggedTypes = metrics.map((m) {
      final serverKey = m['metric_type'] as String;
      return _metricTypeToUiType[serverKey] ?? serverKey;
    }).toSet();
    final latestValues = <String, dynamic>{
      for (final m in metrics)
        (_metricTypeToUiType[m['metric_type'] as String] ??
            m['metric_type'] as String): m['value'],
    };
    debugPrint('[TodayRepo] getTodayLogSummary ← '
        'loggedTypes=$loggedTypes');
    debugPrint('[TodayRepo] getTodayLogSummary latestValues='
        '${latestValues.map((k, v) => MapEntry(k, '${v.runtimeType}($v)'))}');
    return TodayLogSummary(
      loggedTypes: loggedTypes,
      latestValues: latestValues,
    );
  }

  @override
  Future<Set<String>> getUserLoggedTypes() async {
    final summary = await getTodayLogSummary();
    return summary.loggedTypes;
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
    await submitSession(
      sessionType: 'sleep',
      source: 'manual',
      recordedAt: bedtime,
      endedAt: wakeTime,
      notes: notes,
      metadata: {
        if ((interruptions ?? 0) > 0) 'interruptions': interruptions,
        if (factors.isNotEmpty) 'factors': factors,
      },
      metrics: [
        SessionMetricPayload(
          metricType: 'sleep_duration',
          value: durationMinutes.toDouble(),
          unit: 'min',
        ),
        if (qualityRating != null)
          SessionMetricPayload(
            metricType: 'sleep_quality',
            value: qualityRating.toDouble(),
            unit: 'score',
          ),
      ],
    );
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
    await submitSession(
      sessionType: activityType,
      source: 'manual',
      recordedAt: DateTime.now().subtract(Duration(seconds: durationSeconds)),
      metrics: [
        SessionMetricPayload(
            metricType: 'distance',
            value: distanceKm * 1000,
            unit: 'm'),
        SessionMetricPayload(
            metricType: 'exercise_minutes',
            value: (durationSeconds / 60).roundToDouble(),
            unit: 'min'),
        if (avgPaceSecondsPerKm != null &&
            avgPaceSecondsPerKm >= 60 &&
            avgPaceSecondsPerKm <= 1800)
          SessionMetricPayload(
              metricType: 'running_pace',
              value: avgPaceSecondsPerKm.toDouble(),
              unit: 's/km'),
      ],
    );
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
    if (caloriesKcal != null) {
      await submitIngest(
        metricType: 'calories',
        value: caloriesKcal.toDouble(),
        unit: 'kcal',
        source: 'manual',
        recordedAt: DateTime.now(),
        metadata: {
          'meal_type': mealType,
          if (description != null) 'description': description,
          if (feelChips.isNotEmpty) 'feel_chips': feelChips,
          if (tags.isNotEmpty) 'tags': tags,
          if (notes != null) 'notes': notes,
        },
      );
    }
  }

  @override
  Future<void> logSupplements({
    required List<String> takenIds,
    String? notes,
  }) async {
    // Log each supplement as an individual event
    for (final id in takenIds) {
      await submitIngest(
        metricType: 'supplement_taken',
        value: 1.0,
        unit: 'dose',
        source: 'manual',
        recordedAt: DateTime.now(),
        metadata: {'supplement_id': id, if (notes != null) 'notes': notes},
      );
    }
  }

  @override
  Future<void> logSymptom({
    required List<String> bodyAreas,
    required String severity,
    String? symptomType,
    String? timing,
    String? notes,
  }) async {
    await submitIngest(
      metricType: 'symptom',
      value: _severityToValue(severity),
      unit: 'severity',
      source: 'manual',
      recordedAt: DateTime.now(),
      metadata: {
        'body_areas': bodyAreas,
        'severity': severity,
        if (symptomType != null) 'symptom_type': symptomType,
        if (timing != null) 'timing': timing,
        if (notes != null) 'notes': notes,
      },
    );
  }

  @override
  Future<void> logSteps({
    required int steps,
    String mode = 'add',
    String source = 'manual',
  }) async {
    await submitIngest(
      metricType: 'steps',
      value: steps.toDouble(),
      unit: 'steps',
      source: source,
      recordedAt: DateTime.now(),
    );
  }

  @override
  Future<void> logWater({
    required double amountMl,
    String? vesselKey,
  }) async {
    await submitIngest(
      metricType: 'water_ml',
      value: amountMl,
      unit: 'mL',
      source: 'manual',
      recordedAt: DateTime.now(),
      metadata: vesselKey != null ? {'vessel_key': vesselKey} : null,
    );
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
    final now = DateTime.now();
    final sharedMeta = <String, dynamic>{
      if (aiSummary != null) 'ai_summary': aiSummary,
      if (notes != null) 'notes': notes,
      if (transcript != null) 'transcript': transcript,
    };
    final meta = sharedMeta.isEmpty ? null : Map<String, dynamic>.unmodifiable(sharedMeta);
    await Future.wait([
      if (mood != null)
        submitIngest(metricType: 'mood', value: mood, unit: '/10', source: 'manual', recordedAt: now, metadata: meta),
      if (energy != null)
        submitIngest(metricType: 'energy', value: energy, unit: '/10', source: 'manual', recordedAt: now, metadata: meta),
      if (stress != null)
        submitIngest(metricType: 'stress', value: stress, unit: '/10', source: 'manual', recordedAt: now, metadata: meta),
    ]);
  }

  @override
  Future<WellnessParseResult> parseWellnessTranscript(
      String transcript) async {
    final resp = await _api.post(
      '/api/v1/wellness/parse',
      data: {'transcript': transcript},
    );
    return WellnessParseResult.fromJson(resp.data as Map<String, dynamic>);
  }

  @override
  Future<void> logWeight({
    required double valueKg,
    required String timeOfDay,
    double? bodyFatPct,
  }) async {
    assert(
      ['morning', 'afternoon', 'evening'].contains(timeOfDay),
      'timeOfDay must be morning, afternoon, or evening — got: $timeOfDay',
    );
    debugPrint('[TodayRepo] logWeight → valueKg=$valueKg '
        'timeOfDay=$timeOfDay bodyFatPct=$bodyFatPct');
    await submitIngest(
      metricType: 'weight_kg',
      value: valueKg,
      unit: 'kg',
      source: 'manual',
      recordedAt: DateTime.now(),
      metadata: {
        'time_of_day': timeOfDay,
        if (bodyFatPct != null) 'body_fat_pct': bodyFatPct,
      },
    );
    debugPrint('[TodayRepo] logWeight ✅ done');
  }

  // Normalises server metric_type keys to UI tile type keys.
  // The API uses descriptive names (weight_kg, sleep_duration, distance, …)
  // while the UI uses short names (weight, sleep, run, …).
  // Keys absent here pass through unchanged (mood, energy, stress, steps, symptom, …).
  static const _metricTypeToUiType = {
    'weight_kg': 'weight',
    'sleep_duration': 'sleep',
    'distance': 'run',
    'calories': 'meal',
    'supplement_taken': 'supplement',
    'water_ml': 'water',
  };

  // Reverse of _metricTypeToUiType -- converts UI tile keys back to
  // the server-side metric_type strings needed by the /metrics/latest endpoint.
  static const _uiTypeToMetricType = {
    'weight': 'weight_kg',
    'sleep': 'sleep_duration',
    'run': 'distance',
    'meal': 'calories',
    'supplement': 'supplement_taken',
    'water': 'water_ml',
  };

  @override
  Future<List<double?>> getWeightHistory({int days = 7}) async {
    debugPrint('[TodayRepo] getWeightHistory days=$days');
    try {
      final response = await _api.get(
        '/api/v1/metrics/weight/history',
        queryParameters: {'days': days},
      );
      final data = response.data as Map<String, dynamic>;
      final rawList = (data['history'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

      final byDate = <String, double>{
        for (final m in rawList)
          (m['date'] as String): (m['value_kg'] as num).toDouble(),
      };

      final today = DateTime.now();
      final result = <double?>[];
      for (var i = days - 1; i >= 0; i--) {
        final d = DateTime(today.year, today.month, today.day)
            .subtract(Duration(days: i));
        final iso =
            '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
        result.add(byDate[iso]);
      }

      debugPrint('[TodayRepo] getWeightHistory ← ${result.length} entries');
      return result;
    } catch (e, st) {
      debugPrint('[TodayRepo] getWeightHistory failed: $e\n$st');
      return List<double?>.filled(days, null);
    }
  }

  @override
  Future<Map<String, dynamic>> getLatestLogValues(Set<String> types) async {
    debugPrint('[TodayRepo] getLatestLogValues requested types=$types');
    if (types.isEmpty) return const {};

    // Convert UI type keys to server metric_type keys.
    final serverTypes = types
        .map((t) => _uiTypeToMetricType[t] ?? t)
        .toList();

    try {
      final response = await _api.get(
        '/api/v1/metrics/latest',
        queryParameters: {'types': serverTypes.join(',')},
      );
      final data = response.data as Map<String, dynamic>;
      final metrics = (data['metrics'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      final result = <String, dynamic>{};
      for (final m in metrics) {
        final serverKey = m['metric_type'] as String;
        final uiKey = _metricTypeToUiType[serverKey] ?? serverKey;
        result[uiKey] = {
          'value': m['value'] as num,
          'unit': m['unit'] as String,
          'date': m['date'] as String,
        };
      }

      debugPrint('[TodayRepo] getLatestLogValues result=$result');
      return result;
    } catch (e, st) {
      debugPrint('[TodayRepo] getLatestLogValues failed: $e\n$st');
      return const {};
    }
  }

  // ── Supplements List ───────────────────────────────────────────────────────

  @override
  Future<List<SupplementEntry>> getSupplementsList() async {
    final response = await _api.get('/api/v1/supplements');
    final list = response.data['supplements'] as List<dynamic>? ?? [];
    return list
        .map((e) => SupplementEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<SupplementEntry>> updateSupplementsList(
      List<SupplementEntry> supplements) async {
    final response = await _api.post('/api/v1/supplements', data: {
      'supplements': supplements.map((s) => s.toJson()..remove('id')).toList(),
    });
    final list = response.data['supplements'] as List<dynamic>? ?? [];
    return list
        .map((e) => SupplementEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<SupplementTodayLogEntry>> getSupplementsTodayLog() async {
    final response = await _api.get('/api/v1/supplements/today-log');
    return parseTodayLogResponse(
        response.data as Map<String, dynamic>? ?? {});
  }

  @override
  Future<void> deleteSupplementLogEntry(String logEntryId) async {
    await _api.delete('/api/v1/supplements/log/$logEntryId');
  }

  // ── Supplement Label Scan ──────────────────────────────────────────────────

  @override
  Future<SupplementScanResult> scanSupplementLabel({
    String? imageBase64,
    String? barcode,
  }) async {
    assert(imageBase64 != null || barcode != null,
        'Either imageBase64 or barcode must be provided');
    final response = await _api.post(
      '/api/v1/supplements/scan-label',
      data: {
        if (imageBase64 != null) 'image_base64': imageBase64,
        if (barcode != null) 'barcode': barcode,
      },
    );
    return SupplementScanResult.fromJson(
      response.data as Map<String, dynamic>? ?? {},
    );
  }

  @override
  Future<SupplementConflict> checkSupplementConflicts({
    required String name,
    required List<String> existingNames,
    String? excludeId,
  }) async {
    final response = await _api.post(
      '/api/v1/supplements/check-conflicts',
      data: {
        'name': name,
        'existing_names': existingNames,
        if (excludeId != null) 'exclude_id': excludeId,
      },
    );
    return SupplementConflict.fromJson(response.data as Map<String, dynamic>);
  }

  static double _severityToValue(String severity) {
    switch (severity) {
      case 'mild':
        return 1.0;
      case 'moderate':
        return 2.0;
      case 'bad':
        return 2.5;
      case 'severe':
        return 3.0;
      default:
        return 1.0;
    }
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
