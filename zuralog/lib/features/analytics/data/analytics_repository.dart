/// Zuralog Edge Agent — Analytics Repository.
///
/// Client-side repository that fetches aggregated health analytics from
/// the Cloud Brain backend. Provides daily summaries, weekly trends,
/// and AI-generated dashboard insights.
///
/// Includes a lightweight in-memory cache for daily summaries (15-minute
/// TTL) to reduce redundant network requests while keeping data fresh.
/// On network failure the repository falls back to stale cached data
/// when available.
///
/// Injected via Riverpod (`analyticsRepositoryProvider`).
library;

import 'package:dio/dio.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/analytics/domain/daily_summary.dart';
import 'package:zuralog/features/analytics/domain/weekly_trends.dart';
import 'package:zuralog/features/analytics/domain/dashboard_insight.dart';

/// Placeholder user ID used until authentication is fully wired.
const String _mockUserId = 'mock-user';

/// Repository for fetching analytics data from the Cloud Brain.
///
/// All public methods throw [DioException] on network errors unless a
/// cached fallback is available. Responses are deserialized into
/// strongly-typed domain models.
class AnalyticsRepository {
  /// Creates an [AnalyticsRepository] backed by the given [ApiClient].
  ///
  /// The API client is injected to allow swapping with a mock in tests.
  AnalyticsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// The API client used for all HTTP communication.
  final ApiClient _apiClient;

  /// In-memory cache of daily summaries keyed by date string (`YYYY-MM-DD`).
  final Map<String, _CacheEntry<DailySummary>> _dailySummaryCache = {};

  /// Time-to-live for cached daily summaries.
  static const Duration _cacheTtl = Duration(minutes: 15);

  /// Fetches the daily summary for the given [date].
  ///
  /// Sends a GET request to `/analytics/daily-summary` with query parameters
  /// `user_id` and `date_str`. Results are cached in memory for 15 minutes.
  ///
  /// On network failure, returns the most recent cached value for [date]
  /// if one exists (even if expired). Throws [DioException] if no cached
  /// fallback is available.
  ///
  /// [date] — the calendar day to fetch.
  ///
  /// Returns a [DailySummary] with the day's aggregated metrics.
  Future<DailySummary> getDailySummary(DateTime date) async {
    final dateStr = _formatDate(date);

    // Check cache first.
    final cached = _dailySummaryCache[dateStr];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    try {
      final response = await _apiClient.get(
        '/api/v1/analytics/daily-summary',
        queryParameters: {'user_id': _mockUserId, 'date_str': dateStr},
      );

      final summary = DailySummary.fromJson(
        response.data as Map<String, dynamic>,
      );

      // Update cache.
      _dailySummaryCache[dateStr] = _CacheEntry(value: summary);

      return summary;
    } on DioException {
      // Fallback to stale cache if available.
      if (cached != null) {
        return cached.value;
      }
      rethrow;
    }
  }

  /// Fetches weekly trend data for the current user.
  ///
  /// Sends a GET request to `/analytics/weekly-trends` with query parameter
  /// `user_id`. The backend returns the most recent 7-day window.
  ///
  /// Returns a [WeeklyTrends] containing parallel lists of daily metrics.
  ///
  /// Throws [DioException] on network failure.
  Future<WeeklyTrends> getWeeklyTrends() async {
    final response = await _apiClient.get(
      '/api/v1/analytics/weekly-trends',
      queryParameters: {'user_id': _mockUserId},
    );

    return WeeklyTrends.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fetches the AI-generated dashboard insight for the current user.
  ///
  /// Sends a GET request to `/analytics/dashboard-insight` with query
  /// parameter `user_id`.
  ///
  /// Returns a [DashboardInsight] with the natural-language summary and
  /// optional structured metadata.
  ///
  /// Throws [DioException] on network failure.
  Future<DashboardInsight> getDashboardInsight() async {
    final response = await _apiClient.get(
      '/api/v1/analytics/dashboard-insight',
      queryParameters: {'user_id': _mockUserId},
    );

    return DashboardInsight.fromJson(response.data as Map<String, dynamic>);
  }

  /// Formats a [DateTime] as an ISO-8601 date string (`YYYY-MM-DD`).
  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

/// Internal cache entry with a creation timestamp for TTL expiry.
class _CacheEntry<T> {
  /// Creates a cache entry holding [value] with the current time as creation.
  _CacheEntry({required this.value}) : createdAt = DateTime.now();

  /// The cached value.
  final T value;

  /// When this entry was created.
  final DateTime createdAt;

  /// Whether this entry has exceeded the cache TTL.
  bool get isExpired =>
      DateTime.now().difference(createdAt) > AnalyticsRepository._cacheTtl;
}
