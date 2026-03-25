/// Zuralog — Trends Repository.
///
/// Data layer for the Trends tab. Wraps all API calls for:
///   - Trends Home aggregated data      (`GET /api/v1/trends/home`)
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

  // ── Cache Invalidation ────────────────────────────────────────────────────

  /// Invalidates all caches, forcing fresh fetches on next access.
  @override
  void invalidateAll() {
    _homeCache = null;
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
