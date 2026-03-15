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
  Future<void> submitQuickLog(Map<String, dynamic> payload);

  /// Fetches the paginated notification history.
  Future<NotificationPage> getNotifications({int page = 1});

  /// Marks notification [id] as read.
  Future<void> markNotificationRead(String id);
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
      final list = response.data['items'] as List<dynamic>? ?? [];
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
    await _api.patch('/api/v1/insights/$id', body: {'status': 'read'});
    _feedCache = null; // Invalidate so the read state refreshes.
  }

  /// Dismisses insight [id].
  @override
  Future<void> dismissInsight(String id) async {
    await _api.patch('/api/v1/insights/$id', body: {'status': 'dismissed'});
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

  /// Submits a quick-log payload.
  ///
  /// [payload] — a map with keys `mood`, `energy`, `stress`,
  /// `water_glasses`, `notes`, `symptoms`.
  @override
  Future<void> submitQuickLog(Map<String, dynamic> payload) async {
    await _api.post('/api/v1/quick-log', data: payload);
    invalidateFeedCache();
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
}

// ── _CacheEntry ───────────────────────────────────────────────────────────────

class _CacheEntry<T> {
  _CacheEntry({required this.value}) : _createdAt = DateTime.now();

  final T value;
  final DateTime _createdAt;

  bool get isExpired =>
      DateTime.now().difference(_createdAt) > TodayRepository._cacheTtl;
}
