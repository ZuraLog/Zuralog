/// Zuralog — Data Tab Riverpod Providers.
///
/// All state for the Data tab (Health Dashboard, Category Detail,
/// Metric Detail) is managed here.  Screens read from these providers
/// and trigger invalidations via [ref.invalidate].
///
/// Provider inventory:
/// - [dataRepositoryProvider]           — singleton repository
/// - [dashboardProvider]                — async aggregated dashboard data
/// - [dashboardHasNetworkErrorProvider] — true when last fetch failed (network error)
/// - [categoryDetailProvider]           — async family: detail for one category
/// - [metricDetailProvider]             — async family: deep-dive for one metric
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/data/data/data_repository.dart';
import 'package:zuralog/features/data/domain/data_models.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Singleton [DataRepositoryInterface] wired to the shared [apiClientProvider].
///
/// Always uses the real [DataRepository] backed by the Cloud Brain API.
/// Mock repositories are available for unit tests via provider overrides.
final dataRepositoryProvider = Provider<DataRepositoryInterface>((ref) {
  return DataRepository(apiClient: ref.read(apiClientProvider));
});

// ── Dashboard ─────────────────────────────────────────────────────────────────

/// Async provider for the aggregated Health Dashboard data.
///
/// Never puts the UI into an error state. All failures resolve to an empty
/// [DashboardData] so the dashboard always reaches the [data:] branch and
/// renders the appropriate empty state instead of a connection error.
///
/// Invalidate with [ref.invalidate(dashboardProvider)] after a pull-to-refresh.
final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  try {
    final data = await repo.getDashboard();
    debugPrint('[Dashboard] API returned ${data.categories.length} categories: '
        '${data.categories.map((c) => c.category.name).join(', ')}');
    for (final cat in data.categories) {
      debugPrint('[Dashboard]   ${cat.category.name}: '
          'primaryValue="${cat.primaryValue}", '
          'trend=${cat.trend?.length ?? 0} points, '
          'lastUpdated=${cat.lastUpdated}');
    }
    return data;
  } catch (e, st) {
    debugPrint('[Dashboard] ERROR fetching dashboard: $e');
    debugPrint('[Dashboard] Stack trace: $st');
    return const DashboardData(
      categories: [],
      visibleOrder: [],
      isNetworkError: true,
    );
  }
});

/// True when [dashboardProvider] resolved but the fetch failed (network error).
/// False when the API returned successfully or while loading.
/// Used by [HealthDashboardScreen] to distinguish a disconnected returning user
/// from a first-time user with no connected devices.
final dashboardHasNetworkErrorProvider = Provider<bool>((ref) {
  final dash = ref.watch(dashboardProvider);
  return dash.valueOrNull?.isNetworkError == true;
});

// ── Category Detail ───────────────────────────────────────────────────────────

/// Parameter object for the [categoryDetailProvider] family.
///
/// Keyed by both [categoryId] and [timeRange] so switching time ranges
/// triggers a re-fetch while keeping the previous range in cache.
class CategoryDetailParams {
  /// Creates [CategoryDetailParams].
  const CategoryDetailParams({
    required this.categoryId,
    required this.timeRange,
  });

  /// Category slug (e.g. "activity", "sleep").
  final String categoryId;

  /// Time range key (e.g. "7D", "30D").
  final String timeRange;

  @override
  bool operator ==(Object other) =>
      other is CategoryDetailParams &&
      other.categoryId == categoryId &&
      other.timeRange == timeRange;

  @override
  int get hashCode => Object.hash(categoryId, timeRange);
}

/// Async family provider for a single category's full detail + metrics.
///
/// Keyed by [CategoryDetailParams]. The category detail screen uses:
/// ```dart
/// ref.watch(categoryDetailProvider(CategoryDetailParams(
///   categoryId: 'sleep',
///   timeRange: '7D',
/// )))
/// ```
final categoryDetailProvider =
    FutureProvider.family<CategoryDetailData, CategoryDetailParams>(
        (ref, params) async {
  final repo = ref.watch(dataRepositoryProvider);
  return repo.getCategoryDetail(
    categoryId: params.categoryId,
    timeRange: params.timeRange,
  );
});

// ── Metric Detail ─────────────────────────────────────────────────────────────

/// Parameter object for the [metricDetailProvider] family.
class MetricDetailParams {
  /// Creates [MetricDetailParams].
  const MetricDetailParams({
    required this.metricId,
    required this.timeRange,
  });

  /// Metric slug (e.g. "steps", "heart_rate_resting").
  final String metricId;

  /// Time range key (e.g. "7D", "30D").
  final String timeRange;

  @override
  bool operator ==(Object other) =>
      other is MetricDetailParams &&
      other.metricId == metricId &&
      other.timeRange == timeRange;

  @override
  int get hashCode => Object.hash(metricId, timeRange);
}

/// Async family provider for a single metric's deep-dive data.
///
/// Keyed by [MetricDetailParams].
final metricDetailProvider =
    FutureProvider.family<MetricDetailData, MetricDetailParams>(
        (ref, params) async {
  final repo = ref.watch(dataRepositoryProvider);
  return repo.getMetricDetail(
    metricId: params.metricId,
    timeRange: params.timeRange,
  );
});
