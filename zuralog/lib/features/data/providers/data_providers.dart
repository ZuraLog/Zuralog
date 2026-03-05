/// Zuralog — Data Tab Riverpod Providers.
///
/// All state for the Data tab (Health Dashboard, Category Detail,
/// Metric Detail) is managed here.  Screens read from these providers
/// and trigger invalidations via [ref.invalidate].
///
/// Provider inventory:
/// - [dataRepositoryProvider]       — singleton repository
/// - [dashboardProvider]            — async aggregated dashboard data
/// - [categoryDetailProvider]       — async family: detail for one category
/// - [metricDetailProvider]         — async family: deep-dive for one metric
/// - [dashboardLayoutProvider]      — mutable dashboard card order/visibility
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/data/data/data_repository.dart';
import 'package:zuralog/features/data/data/mock_data_repository.dart';
import 'package:zuralog/features/data/domain/data_models.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Singleton [DataRepositoryInterface] wired to the shared [apiClientProvider].
///
/// In debug builds (`kDebugMode`) a [MockDataRepository] is returned so the
/// Data tab renders correctly without a running backend.
final dataRepositoryProvider = Provider<DataRepositoryInterface>((ref) {
  if (kDebugMode) return const MockDataRepository();
  return DataRepository(apiClient: ref.read(apiClientProvider));
});

// ── Dashboard ─────────────────────────────────────────────────────────────────

/// Async provider for the aggregated Health Dashboard data.
///
/// Invalidate with [ref.invalidate(dashboardProvider)] after a pull-to-refresh.
final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final repo = ref.read(dataRepositoryProvider);
  return repo.getDashboard();
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
  final repo = ref.read(dataRepositoryProvider);
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
  final repo = ref.read(dataRepositoryProvider);
  return repo.getMetricDetail(
    metricId: params.metricId,
    timeRange: params.timeRange,
  );
});

// ── Dashboard Layout ──────────────────────────────────────────────────────────

/// Mutable dashboard layout (card order + visibility).
///
/// Initialized to [DashboardLayout.defaultLayout]. Updated by the drag-and-drop
/// reorder in [HealthDashboardScreen]. Persisted via
/// [DataRepository.saveDashboardLayout] after each mutation.
final dashboardLayoutProvider =
    StateProvider<DashboardLayout>((ref) => DashboardLayout.defaultLayout);
