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
/// - [dashboardLayoutProvider]          — mutable dashboard card order/visibility
/// - [tileFilterProvider]               — active category chip filter (null = All)
/// - [dashboardTimeRangeProvider]       — global time range selection
/// - [customDateRangeProvider]          — session-only custom date range
/// - [tileOrderingProvider]             — computed display order of TileIds
/// - [dashboardTilesProvider]           — async full tile list for the dashboard grid
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/data/data/data_repository.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/domain/time_range.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/features/today/domain/today_models.dart';

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

// ── Tile Visualization Builder ────────────────────────────────────────────────

/// Day-of-week abbreviations for bar chart labels (Mon–Sun).
const _kDayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Formats a double for a stats label using compact notation for large numbers.
String _fmtStat(double v) {
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(v == v.truncateToDouble() ? 0 : 1);
}

/// Formats a delta percentage with sign prefix and arrow.
String _fmtDelta(double delta) {
  final sign = delta >= 0 ? '↑' : '↓';
  return '$sign ${delta.abs().toStringAsFixed(1)}%';
}

/// Pre-computed stats derived from a 7-day trend array.
class _TileStats {
  const _TileStats({
    required this.avgLabel,
    required this.deltaLabel,
    required this.avgValue,
    required this.bestValue,
    required this.worstValue,
    required this.changeValue,
  });

  final String avgLabel;
  final String deltaLabel;
  final String avgValue;
  final String bestValue;
  final String worstValue;
  final String changeValue;

  /// Returns null when [trend] is null or empty.
  static _TileStats? fromSummary(List<double>? trend, double? deltaPercent) {
    if (trend == null || trend.isEmpty) return null;
    final avg = trend.reduce((a, b) => a + b) / trend.length;
    final best = trend.reduce((a, b) => a > b ? a : b);
    final worst = trend.reduce((a, b) => a < b ? a : b);
    final delta = deltaPercent;
    return _TileStats(
      avgLabel: 'Avg ${_fmtStat(avg)}',
      deltaLabel: delta != null ? _fmtDelta(delta) : '—',
      avgValue: _fmtStat(avg),
      bestValue: _fmtStat(best),
      worstValue: _fmtStat(worst),
      changeValue: delta != null ? _fmtDelta(delta) : '—',
    );
  }
}

/// Maps a [TileId] to the best [TileVisualizationData] subtype given the
/// available [CategorySummary] data and optional [DailyGoal] list.
///
/// Falls back to [ValueData] when insufficient data is available for the
/// ideal subtype (e.g. [StackedBarData] for sleepStages requires per-stage
/// data not present in [CategorySummary]).
TileVisualizationData _buildTileViz(
  TileId id,
  CategorySummary summary,
  List<DailyGoal> goals,
) {
  final trend = summary.trend;
  final primary = summary.primaryValue;
  final unit = summary.unit;
  final delta = summary.deltaPercent;

  TileVisualizationData barOrValue() {
    if (trend != null && trend.isNotEmpty) {
      return BarChartData(
        dailyValues: trend,
        dayLabels: _kDayLabels.take(trend.length).toList(),
        average: trend.reduce((a, b) => a + b) / trend.length,
        delta: delta,
      );
    }
    return ValueData(primaryValue: primary, secondaryLabel: unit);
  }

  TileVisualizationData lineOrValue() {
    if (trend != null && trend.isNotEmpty) {
      return LineChartData(values: trend, delta: delta);
    }
    return ValueData(primaryValue: primary, secondaryLabel: unit);
  }

  TileVisualizationData dotsOrValue() {
    if (trend != null && trend.isNotEmpty) {
      return DotsData(values: trend, todayLabel: primary);
    }
    return ValueData(primaryValue: primary, secondaryLabel: unit);
  }

  switch (id) {
    case TileId.steps:
      final stepsGoal = goals
          .where((g) =>
              g.id.contains('steps') ||
              g.label.toLowerCase().contains('steps'))
          .firstOrNull;
      if (stepsGoal != null && stepsGoal.target > 0) {
        final current =
            double.tryParse(primary.replaceAll(',', '')) ?? 0;
        return RingData(
          value: current.clamp(0, stepsGoal.target),
          max: stepsGoal.target,
          goalLabel: '/ ${_fmtStat(stepsGoal.target)} goal',
        );
      }
      return barOrValue();

    case TileId.activeCalories:
      return barOrValue();

    case TileId.workouts:
      final count =
          int.tryParse(primary.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return CountBadgeData(count: count);

    case TileId.sleepDuration:
      return barOrValue();

    case TileId.sleepStages:
      return ValueData(primaryValue: primary, secondaryLabel: unit);

    case TileId.restingHeartRate:
    case TileId.hrv:
      return lineOrValue();

    case TileId.vo2Max:
      final v = double.tryParse(primary.replaceAll(',', ''));
      if (v != null) {
        return GaugeData(
            percent: (v / 70.0).clamp(0.0, 1.0), label: primary);
      }
      return ValueData(primaryValue: primary, secondaryLabel: unit);

    case TileId.weight:
    case TileId.bodyFat:
      return lineOrValue();

    case TileId.bloodPressure:
      final parts = primary.split('/');
      if (parts.length == 2) {
        return DualValueData(
          topValue: parts[0].trim(),
          bottomValue: parts[1].trim(),
          topLabel: 'SYS',
          bottomLabel: 'DIA',
        );
      }
      return ValueData(primaryValue: primary, secondaryLabel: unit);

    case TileId.spo2:
      return lineOrValue();

    case TileId.calories:
      if (trend != null && trend.isNotEmpty) {
        return AreaChartData(values: trend, delta: delta);
      }
      return ValueData(primaryValue: primary, secondaryLabel: unit);

    case TileId.water:
      final waterGoal = goals
          .where((g) =>
              g.id.contains('water') ||
              g.label.toLowerCase().contains('water'))
          .firstOrNull;
      final current =
          double.tryParse(primary.replaceAll(',', '')) ?? 0;
      if (waterGoal != null && waterGoal.target > 0) {
        return FillGaugeData(
          current: current,
          goal: waterGoal.target,
          unit: unit,
        );
      }
      return ValueData(primaryValue: primary, secondaryLabel: unit);

    case TileId.mood:
    case TileId.energy:
    case TileId.stress:
      return dotsOrValue();

    case TileId.cycle:
      return ValueData(primaryValue: primary, secondaryLabel: unit);

    case TileId.environment:
      return ValueData(primaryValue: primary, secondaryLabel: unit);

    case TileId.mobility:
      final v = double.tryParse(primary.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (v != null) {
        return GaugeData(
            percent: (v / 100.0).clamp(0.0, 1.0), label: primary);
      }
      return ValueData(primaryValue: primary, secondaryLabel: unit);
  }
}

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
/// - [dailyGoalsProvider] for goal-progress visualization (steps ring, water gauge)
///
/// Each tile receives the most appropriate [TileVisualizationData] subtype for its
/// metric type, with pre-computed stats from the 7-day trend data.
///
/// On first load or when data is unavailable, produces tiles in [TileDataState.noSource]
/// state. The [dashboardTimeRangeProvider] is watched so a range change triggers re-fetch.
///
/// Never throws — errors resolve to empty/noSource tiles.
final dashboardTilesProvider = FutureProvider<List<TileData>>((ref) async {
  ref.watch(dashboardTimeRangeProvider);
  try {
    final dashAsync = await ref.watch(dashboardProvider.future);
    // Watch daily goals for goal-progress visualization (steps ring, water gauge).
    final goals = await ref.watch(dailyGoalsProvider.future);
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
      final viz = _buildTileViz(tileId, summary, goals);
      final stats = _TileStats.fromSummary(summary.trend, summary.deltaPercent);
      return TileData(
        tileId: tileId,
        dataState: TileDataState.loaded,
        lastUpdated: summary.lastUpdated,
        visualization: viz,
        avgLabel: stats?.avgLabel,
        deltaLabel: stats?.deltaLabel,
        avgValue: stats?.avgValue,
        bestValue: stats?.bestValue,
        worstValue: stats?.worstValue,
        changeValue: stats?.changeValue,
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
