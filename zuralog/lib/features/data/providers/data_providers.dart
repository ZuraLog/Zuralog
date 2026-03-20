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
/// - [tileFilterProvider]           — active category chip filter (null = All)
/// - [dashboardTimeRangeProvider]   — global time range selection
/// - [customDateRangeProvider]      — session-only custom date range
/// - [tileOrderingProvider]         — computed display order of TileIds
/// - [dashboardTilesProvider]       — async full tile list for the dashboard grid
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/data/data/data_repository.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/domain/time_range.dart';

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
    return await repo.getDashboard();
  } catch (_) {
    return const DashboardData(categories: [], visibleOrder: []);
  }
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

// ── Dashboard Layout ──────────────────────────────────────────────────────────

/// Mutable dashboard layout (card order + visibility + color overrides).
///
/// Initialized to [DashboardLayout.defaultLayout]. Updated by the drag-and-drop
/// reorder in [HealthDashboardScreen]. Persisted via
/// [DataRepository.saveDashboardLayout] after each mutation.
final dashboardLayoutProvider =
    StateProvider<DashboardLayout>((ref) => DashboardLayout.defaultLayout);

// ── Dashboard Layout Loader ───────────────────────────────────────────────────

/// Async loader that fetches the persisted [DashboardLayout] from the
/// preferences API once on cold-start, then initializes [dashboardLayoutProvider].
///
/// Screens should `ref.listen` this provider or use `addPostFrameCallback` to
/// seed [dashboardLayoutProvider] when data arrives.
final dashboardLayoutLoaderProvider = FutureProvider<DashboardLayout?>((ref) async {
  final repo = ref.watch(dataRepositoryProvider);
  try {
    return await repo.getPersistedLayout();
  } catch (e) {
    debugPrint('[DashboardLayout] Could not restore layout: $e');
    return null;
  }
});

// ── Tile Filter ───────────────────────────────────────────────────────────────

/// Which category chip is active on the dashboard. `null` means "All".
final tileFilterProvider = StateProvider<HealthCategory?>((ref) => null);

// ── Dashboard Time Range ──────────────────────────────────────────────────────

/// Global time range selection for the dashboard grid (default: 7D per spec §3.4).
final dashboardTimeRangeProvider =
    StateProvider<TimeRange>((ref) => TimeRange.sevenDays);

// ── Custom Date Range ─────────────────────────────────────────────────────────

/// Session-only custom date range. Null when time range is not [TimeRange.custom].
final customDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

// ── Tile Ordering ─────────────────────────────────────────────────────────────

/// Computes the ordered list of visible TileIds for the dashboard.
///
/// When [DashboardLayout.tileOrder] is non-empty (user set a custom order),
/// that order is used directly, with unknown IDs filtered out and any new
/// tiles not in the persisted order appended at the end.
///
/// When tileOrder is empty (first launch or old layout), tiles are sorted
/// by data recency: tiles with a non-null [TileData.lastUpdated] sort first
/// (most recent first), tiles with no data sort last.
///
/// This provider is recomputed when [dashboardLayoutProvider] or
/// [dashboardTilesProvider] changes.
///
/// Note: Hidden tiles (per [DashboardLayout.tileVisibility]) are included in
/// this list — filtering hidden tiles is the grid widget's responsibility.
/// Smart ordering is stable within a session (spec §12.3); the sort runs
/// once per [dashboardTilesProvider] resolution, not on every data update.
final tileOrderingProvider = Provider<List<TileId>>((ref) {
  final layout = ref.watch(dashboardLayoutProvider);
  final tilesAsync = ref.watch(dashboardTilesProvider);
  final tiles = tilesAsync.valueOrNull ?? [];

  // Build a map for O(1) lookup of TileData by TileId.
  final tileMap = {for (final t in tiles) t.tileId: t};

  if (layout.tileOrder.isNotEmpty) {
    // User has a custom order — respect it, filter unknown IDs, append new tiles.
    final persisted = layout.tileOrder
        .map(TileId.fromString)
        .whereType<TileId>()
        .toList();
    final persistedSet = persisted.toSet();
    final newTiles = TileId.values.where((id) => !persistedSet.contains(id));
    return [...persisted, ...newTiles];
  }

  // Smart ordering: sort by recency of lastUpdated, nulls last.
  final sorted = List<TileId>.from(TileId.values)
    ..sort((a, b) {
      final aDate = tileMap[a]?.lastUpdated;
      final bDate = tileMap[b]?.lastUpdated;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1; // a has no data → sink
      if (bDate == null) return -1; // b has no data → sink
      return bDate.compareTo(aDate); // most recent first
    });
  return sorted;
});

// ── Dashboard Tiles ───────────────────────────────────────────────────────────

/// Async provider producing the full tile list for the dashboard grid.
///
/// Combines data from multiple sources:
/// - [dashboardProvider] for category-level summaries (primary values, trends)
///
/// On first load or when data is unavailable, produces tiles in [TileDataState.noSource]
/// state. The [dashboardTimeRangeProvider] is watched so a range change triggers re-fetch.
///
/// Never throws — errors resolve to empty/noSource tiles.
final dashboardTilesProvider = FutureProvider<List<TileData>>((ref) async {
  ref.watch(dashboardTimeRangeProvider);
  try {
    final dashAsync = await ref.watch(dashboardProvider.future);
    final categoryMap = {
      for (final s in dashAsync.categories) s.category: s,
    };
    return TileId.values.map((tileId) {
      final summary = categoryMap[tileId.category];
      if (summary == null) {
        return TileData(
          tileId: tileId,
          dataState: TileDataState.noSource,
          lastUpdated: null,
        );
      }
      final viz = ValueData(
        primaryValue: summary.primaryValue,
        secondaryLabel: summary.unit,
      );
      return TileData(
        tileId: tileId,
        dataState: TileDataState.loaded,
        lastUpdated: summary.lastUpdated,
        visualization: viz,
      );
    }).toList();
  } catch (_) {
    return TileId.values
        .map((id) => TileData(
              tileId: id,
              dataState: TileDataState.noSource,
              lastUpdated: null,
            ))
        .toList();
  }
});
