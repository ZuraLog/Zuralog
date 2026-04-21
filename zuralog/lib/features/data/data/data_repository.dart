/// Zuralog — Data Repository.
///
/// Data layer for the Data tab. Wraps all API calls for:
///   - Health dashboard summaries    (`GET /api/v1/analytics/daily-summary`)
///   - Category detail with metrics  (`GET /api/v1/analytics/…` by category)
///   - Single metric deep-dive       (`GET /api/v1/analytics/…` by metric)
///
/// Provides a 5-minute in-memory TTL cache per (category, timeRange) key to
/// avoid redundant requests on navigation back.
library;

import 'package:dio/dio.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/data/domain/data_models.dart';

// ── DataRepositoryInterface ───────────────────────────────────────────────────

/// Abstract contract for all Data-tab data operations.
///
/// Implemented by [DataRepository] (real) and [MockDataRepository] (debug).
abstract interface class DataRepositoryInterface {
  /// Fetches the aggregated dashboard data — all category summaries.
  Future<DashboardData> getDashboard({bool forceRefresh = false});

  /// Fetches all metrics for a [categoryId] over the given [timeRange].
  Future<CategoryDetailData> getCategoryDetail({
    required String categoryId,
    required String timeRange,
  });

  /// Fetches deep-dive data for a single [metricId] over [timeRange].
  Future<MetricDetailData> getMetricDetail({
    required String metricId,
    required String timeRange,
  });

  /// Invalidates all caches, forcing fresh fetches.
  void invalidateAll();
}

// ── DataRepository ────────────────────────────────────────────────────────────

/// Repository for all Data-tab network operations.
///
/// Injected via [dataRepositoryProvider]. All public methods throw
/// [DioException] on network errors unless a cached fallback is available.
class DataRepository implements DataRepositoryInterface {
  /// Creates a [DataRepository] backed by [apiClient].
  DataRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ── Cache ──────────────────────────────────────────────────────────────────

  _CacheEntry<DashboardData>? _dashboardCache;
  final Map<String, _CacheEntry<CategoryDetailData>> _categoryCache = {};
  final Map<String, _CacheEntry<MetricDetailData>> _metricCache = {};

  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Maximum number of entries retained per cache map before the oldest
  /// entry is evicted. Prevents unbounded memory growth on long sessions.
  static const int _kMaxCacheEntries = 20;

  // ── Cache eviction ────────────────────────────────────────────────────────

  void _evictIfNeeded<T>(Map<String, _CacheEntry<T>> cache) {
    if (cache.length >= _kMaxCacheEntries) {
      cache.remove(cache.keys.first);
    }
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────

  /// Fetches the aggregated dashboard data — all category summaries.
  ///
  /// When [forceRefresh] is `true`, the Flutter-side in-memory cache is evicted
  /// and `?force_refresh=true` is forwarded to the server so the server-side
  /// cache is also bypassed. Use this on pull-to-refresh.
  ///
  /// Falls back to stale cache on network error if available.
  @override
  Future<DashboardData> getDashboard({bool forceRefresh = false}) async {
    if (!forceRefresh && _dashboardCache != null && !_dashboardCache!.isExpired) {
      return _dashboardCache!.value;
    }
    if (forceRefresh) _dashboardCache = null; // Evict stale Flutter-side cache entry.
    try {
      final response = await _api.get(
        '/api/v1/analytics/dashboard-summary',
        queryParameters: forceRefresh ? {'force_refresh': 'true'} : null,
      );
      final data = DashboardData.fromJson(
        response.data as Map<String, dynamic>,
      );
      _dashboardCache = _CacheEntry(value: data);
      return data;
    } on DioException {
      if (_dashboardCache != null) return _dashboardCache!.value;
      // Return stub with empty categories so the screen can show a message.
      return const DashboardData(categories: [], visibleOrder: []);
    }
  }

  // ── Category Detail ───────────────────────────────────────────────────────

  /// Fetches all metrics for a [categoryId] over the given [timeRange].
  ///
  /// Cache key: `$categoryId:$timeRange`.
  @override
  Future<CategoryDetailData> getCategoryDetail({
    required String categoryId,
    required String timeRange,
  }) async {
    final key = '$categoryId:$timeRange';
    final cached = _categoryCache[key];
    if (cached != null && !cached.isExpired) return cached.value;

    try {
      final response = await _api.get(
        '/api/v1/analytics/category',
        queryParameters: {
          'category': categoryId,
          'time_range': timeRange,
        },
      );
      final data = CategoryDetailData.fromJson(
        response.data as Map<String, dynamic>,
      );
      _evictIfNeeded(_categoryCache);
      _categoryCache[key] = _CacheEntry(value: data);
      return data;
    } on DioException {
      if (cached != null) return cached.value;
      // Return empty stub.
      return CategoryDetailData(
        category: HealthCategory.fromString(categoryId) ?? HealthCategory.activity,
        metrics: [],
        timeRange: timeRange,
      );
    }
  }

  // ── Metric Detail ─────────────────────────────────────────────────────────

  /// Fetches deep-dive data for a single [metricId] over [timeRange].
  ///
  /// Cache key: `$metricId:$timeRange`.
  @override
  Future<MetricDetailData> getMetricDetail({
    required String metricId,
    required String timeRange,
  }) async {
    final key = '$metricId:$timeRange';
    final cached = _metricCache[key];
    if (cached != null && !cached.isExpired) return cached.value;

    try {
      final response = await _api.get(
        '/api/v1/analytics/metric',
        queryParameters: {
          'metric_id': metricId,
          'time_range': timeRange,
        },
      );
      final data = MetricDetailData.fromJson(
        response.data as Map<String, dynamic>,
      );
      _evictIfNeeded(_metricCache);
      _metricCache[key] = _CacheEntry(value: data);
      return data;
    } on DioException {
      if (cached != null) return cached.value;
      // Return empty stub.
      return MetricDetailData(
        series: MetricSeries(
          metricId: metricId,
          displayName: metricId,
          unit: '',
          dataPoints: [],
        ),
        category: HealthCategory.activity,
      );
    }
  }

  /// Invalidates all caches, forcing fresh fetches.
  @override
  void invalidateAll() {
    _dashboardCache = null;
    _categoryCache.clear();
    _metricCache.clear();
  }
}

// ── _CacheEntry ───────────────────────────────────────────────────────────────

class _CacheEntry<T> {
  _CacheEntry({required this.value}) : _createdAt = DateTime.now();

  final T value;
  final DateTime _createdAt;

  bool get isExpired =>
      DateTime.now().difference(_createdAt) > DataRepository._cacheTtl;
}
