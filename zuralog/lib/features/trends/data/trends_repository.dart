/// Zuralog — Trends Repository.
///
/// Data layer for the Trends tab. Wraps all API calls for:
///   - Trends Home aggregated data      (`GET /api/v1/trends/home`)
///   - Available metrics list           (`GET /api/v1/trends/metrics`)
///   - Correlation analysis             (`GET /api/v1/trends/correlations`)
///   - Monthly reports list             (`GET /api/v1/reports`)
///   - Data sources provenance          (`GET /api/v1/data-sources`)
///
/// Provides a 5-minute in-memory TTL cache for read-heavy endpoints.
library;

import 'package:dio/dio.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/trends/domain/trends_models.dart';

// ── TrendsRepositoryInterface ─────────────────────────────────────────────────

/// Abstract contract for the Trends repository.
///
/// Implemented by [TrendsRepository] (production) and
/// [MockTrendsRepository] (debug).
abstract interface class TrendsRepositoryInterface {
  Future<TrendsHomeData> getTrendsHome();
  Future<AvailableMetricList> getAvailableMetrics();
  Future<CorrelationAnalysis> getCorrelationAnalysis({
    required String metricAId,
    required String metricBId,
    required int lagDays,
    required CorrelationTimeRange timeRange,
    DateTime? customStart,
    DateTime? customEnd,
  });
  Future<ReportList> getReports({int page = 1});
  Future<DataSourceList> getDataSources();
  void invalidateAll();
}

// ── TrendsRepository ──────────────────────────────────────────────────────────

/// Repository for all Trends-tab network operations.
///
/// Injected via [trendsRepositoryProvider]. All public methods throw
/// [DioException] on network errors unless a cached fallback is available.
class TrendsRepository implements TrendsRepositoryInterface {
  /// Creates a [TrendsRepository] backed by [apiClient].
  TrendsRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ── Cache ─────────────────────────────────────────────────────────────────

  _CacheEntry<TrendsHomeData>? _homeCache;
  _CacheEntry<AvailableMetricList>? _metricsCache;
  _CacheEntry<ReportList>? _reportsCache;
  _CacheEntry<DataSourceList>? _dataSourcesCache;

  static const Duration _cacheTtl = Duration(minutes: 5);

  // ── Trends Home ───────────────────────────────────────────────────────────

  /// Fetches the aggregated Trends Home screen data.
  ///
  /// Falls back to stale cache on network error if available.
  @override
  Future<TrendsHomeData> getTrendsHome() async {
    if (_homeCache != null && !_homeCache!.isExpired) {
      return _homeCache!.value;
    }
    try {
      final response = await _api.get('/api/v1/trends/home');
      final data =
          TrendsHomeData.fromJson(response.data as Map<String, dynamic>);
      _homeCache = _CacheEntry(value: data);
      return data;
    } on DioException {
      if (_homeCache != null) return _homeCache!.value;
      // Return empty stub so the screen can show the onboarding/empty state.
      return const TrendsHomeData(
        correlationHighlights: [],
        timePeriods: [],
        hasEnoughData: false,
      );
    }
  }

  // ── Available Metrics ─────────────────────────────────────────────────────

  /// Fetches the list of metrics available for correlation analysis.
  @override
  Future<AvailableMetricList> getAvailableMetrics() async {
    if (_metricsCache != null && !_metricsCache!.isExpired) {
      return _metricsCache!.value;
    }
    try {
      final response = await _api.get('/api/v1/trends/metrics');
      final data = AvailableMetricList.fromJson(
          response.data as Map<String, dynamic>);
      _metricsCache = _CacheEntry(value: data);
      return data;
    } on DioException {
      if (_metricsCache != null) return _metricsCache!.value;
      return const AvailableMetricList(metrics: []);
    }
  }

  // ── Correlation Analysis ──────────────────────────────────────────────────

  /// Fetches a correlation analysis between two metrics.
  ///
  /// This call is NOT cached — each unique metric pair/lag/range combination
  /// should fetch fresh data.
  @override
  Future<CorrelationAnalysis> getCorrelationAnalysis({
    required String metricAId,
    required String metricBId,
    required int lagDays,
    required CorrelationTimeRange timeRange,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final params = <String, dynamic>{
      'metric_a': metricAId,
      'metric_b': metricBId,
      'lag_days': lagDays,
      'time_range': timeRange.apiSlug,
    };
    if (customStart != null) {
      params['custom_start'] = customStart.toUtc().toIso8601String();
    }
    if (customEnd != null) {
      params['custom_end'] = customEnd.toUtc().toIso8601String();
    }
    final response = await _api.get(
      '/api/v1/trends/correlations',
      queryParameters: params,
    );
    return CorrelationAnalysis.fromJson(
        response.data as Map<String, dynamic>);
  }

  // ── Reports ───────────────────────────────────────────────────────────────

  /// Fetches the list of generated monthly reports.
  @override
  Future<ReportList> getReports({int page = 1}) async {
    if (page == 1 && _reportsCache != null && !_reportsCache!.isExpired) {
      return _reportsCache!.value;
    }
    try {
      final response = await _api.get(
        '/api/v1/reports',
        queryParameters: {'page': page},
      );
      final data = ReportList.fromJson(response.data as Map<String, dynamic>);
      if (page == 1) _reportsCache = _CacheEntry(value: data);
      return data;
    } on DioException {
      if (page == 1 && _reportsCache != null) return _reportsCache!.value;
      return const ReportList(reports: [], hasMore: false);
    }
  }

  // ── Data Sources ──────────────────────────────────────────────────────────

  /// Fetches the data provenance list (per-integration sync status).
  @override
  Future<DataSourceList> getDataSources() async {
    if (_dataSourcesCache != null && !_dataSourcesCache!.isExpired) {
      return _dataSourcesCache!.value;
    }
    try {
      final response = await _api.get('/api/v1/data-sources');
      final data =
          DataSourceList.fromJson(response.data as Map<String, dynamic>);
      _dataSourcesCache = _CacheEntry(value: data);
      return data;
    } on DioException {
      if (_dataSourcesCache != null) return _dataSourcesCache!.value;
      return const DataSourceList(sources: []);
    }
  }

  // ── Cache Invalidation ────────────────────────────────────────────────────

  /// Invalidates all caches, forcing fresh fetches on next access.
  @override
  void invalidateAll() {
    _homeCache = null;
    _metricsCache = null;
    _reportsCache = null;
    _dataSourcesCache = null;
  }
}

// ── _CacheEntry ───────────────────────────────────────────────────────────────

class _CacheEntry<T> {
  _CacheEntry({required this.value}) : _createdAt = DateTime.now();

  final T value;
  final DateTime _createdAt;

  bool get isExpired =>
      DateTime.now().difference(_createdAt) > TrendsRepository._cacheTtl;
}
