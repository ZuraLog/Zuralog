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

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/material.dart' show Color, DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/data/data/data_repository.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
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
    final layout = await repo.getPersistedLayout();
    if (layout == null) return null;
    // Drop persisted tile-size overrides that are no longer in the tile's
    // allowedSizes (e.g. a tile that was resizable in an older build but is
    // now fixed to a single size). Without this guard a stale override can
    // render a tile at a size the grid algorithm doesn't expect.
    final validSizes = Map<String, TileSize>.from(layout.tileSizes)
      ..removeWhere((name, size) {
        final id = TileId.fromString(name);
        return id == null || !id.allowedSizes.contains(size);
      });
    if (validSizes.length == layout.tileSizes.length) return layout;
    debugPrint('[DashboardLayout] Dropped ${layout.tileSizes.length - validSizes.length} '
        'stale tile-size override(s): '
        '${layout.tileSizes.keys.where((k) => !validSizes.containsKey(k)).join(', ')}');
    return layout.copyWith(tileSizes: validSizes);
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

/// Visible-for-testing wrapper around [_buildTileViz].
@visibleForTesting
TileVisualizationConfig buildTileVizForTest(
  TileId id,
  CategorySummary summary,
  List<DailyGoal> goals,
  TileSize size,
) =>
    _buildTileViz(id, summary, goals, size);

/// Maps a [TileId] to the best [TileVisualizationConfig] subtype given the
/// available [CategorySummary] data and optional [DailyGoal] list.
///
/// Returns an exhaustive config for all 31 [TileId] values.
TileVisualizationConfig _buildTileViz(
  TileId id,
  CategorySummary summary,
  List<DailyGoal> goals,
  TileSize size,
) {
  return switch (id) {
    TileId.steps => switch (size) {
      TileSize.square => BarChartConfig(
          bars: _toBars(summary.trend),
          goalValue: _goalFor(id, goals),
        ),
      _ => BarChartConfig(
          bars: _toBars(summary.trend),
          goalValue: _goalFor(id, goals),
          showAvgLine: true,
        ),
    },

    TileId.activeCalories =>
      BarChartConfig(bars: _toBars(summary.trend), goalValue: _goalFor(id, goals)),

    TileId.workouts => BarChartConfig(bars: _toBars(summary.trend)),

    TileId.sleepDuration =>
      StatCardConfig(value: summary.primaryValue, unit: summary.unit ?? 'hrs'),

    TileId.sleepStages =>
      StatCardConfig(value: summary.primaryValue, unit: summary.unit ?? 'hrs'),

    TileId.restingHeartRate =>
      LineChartConfig(points: _toPoints(summary.trend), positiveIsUp: false),

    TileId.hrv =>
      LineChartConfig(points: _toPoints(summary.trend), positiveIsUp: true),

    TileId.vo2Max => GaugeConfig(
        value: _parseDouble(summary.primaryValue),
        minValue: 0,
        maxValue: 70,
        zones: const [
          GaugeZone(min: 0, max: 25, label: 'Poor', color: Color(0xFFFF5252)),
          GaugeZone(min: 25, max: 35, label: 'Fair', color: Color(0xFFFF9800)),
          GaugeZone(min: 35, max: 45, label: 'Good', color: Color(0xFF4CAF50)),
          GaugeZone(
              min: 45, max: 55, label: 'Excellent', color: Color(0xFF2196F3)),
          GaugeZone(
              min: 55, max: 70, label: 'Superior', color: Color(0xFF9C27B0)),
        ],
      ),

    TileId.weight =>
      LineChartConfig(points: _toPoints(summary.trend), positiveIsUp: false),

    TileId.bodyFat =>
      LineChartConfig(points: _toPoints(summary.trend), positiveIsUp: false),

    TileId.bloodPressure => _buildBloodPressureConfig(summary),

    TileId.spo2 => LineChartConfig(
        points: _toPoints(summary.trend),
        rangeMin: 90,
        rangeMax: 100,
        positiveIsUp: true,
      ),

    TileId.calories => AreaChartConfig(
        points: _toPoints(summary.trend),
        targetLine: null,
        positiveIsUp: false,
      ),

    TileId.water => FillGaugeConfig(
        // Backend stores water in mL; gauge expects litres.
        value: summary.unit == 'mL'
            ? _parseDouble(summary.primaryValue) / 1000.0
            : _parseDouble(summary.primaryValue),
        maxValue: 2.5,
        unit: 'L',
        unitIcon: '💧',
        unitSize: 0.3,
      ),

    TileId.mood => DotRowConfig(
        points: _toDots(summary.trend),
        invertedScale: false,
      ),

    TileId.energy => DotRowConfig(
        points: _toDots(summary.trend),
        invertedScale: false,
      ),

    TileId.stress => DotRowConfig(
        points: _toDots(summary.trend),
        invertedScale: true,
      ),

    TileId.cycle =>
      StatCardConfig(value: summary.primaryValue, unit: summary.unit ?? ''),

    TileId.environment =>
      StatCardConfig(value: summary.primaryValue, unit: summary.unit ?? ''),

    TileId.mobility =>
      StatCardConfig(value: summary.primaryValue, unit: summary.unit ?? ''),

    // ── New tiles (Phase 8 expansion) ─────────────────────────────────────────

    TileId.distance => BarChartConfig(bars: _toBars(summary.trend)),

    TileId.floorsClimbed => BarChartConfig(bars: _toBars(summary.trend)),

    TileId.exerciseMinutes => switch (size) {
      TileSize.square => RingConfig(
          value: _parseDouble(summary.primaryValue),
          maxValue: 30,
          unit: 'min',
        ),
      _ => BarChartConfig(bars: _toBars(summary.trend), goalValue: 30),
    },

    TileId.walkingSpeed =>
      LineChartConfig(points: _toPoints(summary.trend), positiveIsUp: true),

    TileId.runningPace =>
      LineChartConfig(points: _toPoints(summary.trend), positiveIsUp: false),

    TileId.respiratoryRate => StatCardConfig(
        value: summary.primaryValue,
        unit: summary.unit ?? 'breaths/min',
      ),

    TileId.bodyTemperature =>
      LineChartConfig(points: _toPoints(summary.trend), positiveIsUp: false),

    TileId.wristTemperature =>
      LineChartConfig(points: _toPoints(summary.trend), positiveIsUp: false),

    TileId.macros =>
      StatCardConfig(value: summary.primaryValue, unit: summary.unit ?? ''),

    TileId.bloodGlucose => switch (size) {
      TileSize.square => GaugeConfig(
          value: _parseDouble(summary.primaryValue),
          minValue: 2.8,
          maxValue: 11.1,
          zones: const [
            GaugeZone(
                min: 2.8, max: 3.9, label: 'Low', color: Color(0xFFFF5252)),
            GaugeZone(
                min: 3.9, max: 7.8, label: 'Normal', color: Color(0xFF4CAF50)),
            GaugeZone(
                min: 7.8, max: 11.1, label: 'High', color: Color(0xFFFF9800)),
          ],
        ),
      _ => LineChartConfig(points: _toPoints(summary.trend), referenceLine: 7.8),
    },

    TileId.mindfulMinutes => BarChartConfig(bars: _toBars(summary.trend)),
  };
}

TileVisualizationConfig _buildBloodPressureConfig(CategorySummary summary) {
  final parts = summary.primaryValue.split('/');
  if (parts.length == 2) {
    return DualValueConfig(
      value1: parts[0].trim(),
      label1: 'SYS',
      value2: parts[1].trim(),
      label2: 'DIA',
    );
  }
  return StatCardConfig(value: summary.primaryValue, unit: summary.unit ?? 'mmHg');
}

double _parseDouble(String? s) =>
    double.tryParse(s?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '') ?? 0;

double? _goalFor(TileId id, List<DailyGoal> goals) {
  try {
    return goals
        .firstWhere((g) =>
            g.id.contains(id.name) || g.label.toLowerCase().contains(id.name))
        .target;
  } catch (_) {
    return null;
  }
}

List<BarPoint> _toBars(List<double>? trend) {
  if (trend == null || trend.isEmpty) return [];
  return List.generate(
    trend.length,
    (i) => BarPoint(
      label: _kDayLabels[i % _kDayLabels.length],
      value: trend[i],
      isToday: i == trend.length - 1,
    ),
  );
}

List<ChartPoint> _toPoints(List<double>? trend) {
  if (trend == null || trend.isEmpty) return [];
  final now = DateTime.now();
  return List.generate(
    trend.length,
    (i) => ChartPoint(
      date: now.subtract(Duration(days: trend.length - 1 - i)),
      value: trend[i],
    ),
  );
}

List<DotPoint> _toDots(List<double>? trend) {
  if (trend == null || trend.isEmpty) return [];
  return trend.map((v) => DotPoint(value: v)).toList();
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
/// - [dashboardProvider] for category-level summaries (health score, fallback data)
/// - Per-category detail fetches for per-metric series data (one fetch per category)
/// - [dailyGoalsProvider] for goal-progress visualization (steps ring, water gauge)
///
/// Each tile receives its own [MetricSeries] data from the category detail
/// endpoint, so tiles within the same category show different values.
/// Falls back to the category-level [CategorySummary] when no per-metric
/// series is available (e.g. workouts, blood pressure).
///
/// On first load or when data is unavailable, produces tiles in [TileDataState.noSource]
/// state. The [dashboardTimeRangeProvider] is watched so a range change triggers re-fetch.
///
/// Never throws — errors resolve to empty/noSource tiles.
final dashboardTilesProvider = FutureProvider<List<TileData>>((ref) async {
  final timeRange = ref.watch(dashboardTimeRangeProvider);
  try {
    final dashAsync = await ref.watch(dashboardProvider.future);
    // Watch daily goals for goal-progress visualization (steps ring, water gauge).
    final goals = await ref.watch(dailyGoalsProvider.future);
    final repo = ref.read(dataRepositoryProvider);
    final layout = ref.read(dashboardLayoutProvider);

    // Category detail only supports 7D/30D/90D — map 'today' to '7D'.
    final detailTimeRange = timeRange == TimeRange.today ? '7D' : timeRange.apiKey;

    // Fetch all 10 category details in parallel for per-metric data.
    final detailResults = await Future.wait(
      HealthCategory.values.map((cat) => repo.getCategoryDetail(
            categoryId: cat.name,
            timeRange: detailTimeRange,
          )),
    );

    // Build metricSlug → MetricSeries lookup from all category detail responses.
    // Later entries overwrite earlier ones if metric IDs collide.
    final metricSeriesMap = <String, MetricSeries>{};
    for (final detail in detailResults) {
      for (final series in detail.metrics) {
        metricSeriesMap[series.metricId] = series;
      }
    }

    // Category-level summaries as fallback for tiles without per-metric data.
    final categoryMap = {
      for (final s in dashAsync.categories) s.category: s,
    };

    debugPrint('[DashboardTiles] Building tiles. '
        'metricSeriesMap keys: ${metricSeriesMap.keys.join(', ')}');

    final tiles = TileId.values.map((tileId) {
      final series = metricSeriesMap[tileId.metricSlug];
      final catSummary = categoryMap[tileId.category];

      if (series == null && catSummary == null) {
        return TileData(
          tileId: tileId,
          dataState: TileDataState.noSource,
          lastUpdated: null,
        );
      }

      // Use per-metric series data if available, otherwise fall back to category summary.
      final summary = series != null
          ? _summaryFromSeries(series, tileId.category)
          : catSummary!;

      // Resolve effective tile size from layout overrides, falling back to default.
      final effectiveSize =
          layout.tileSizes[tileId.name] ?? tileId.defaultSize;
      final vizConfig = _buildTileViz(tileId, summary, goals, effectiveSize);
      final stats = _TileStats.fromSummary(summary.trend, summary.deltaPercent);
      return TileData(
        tileId: tileId,
        dataState: TileDataState.loaded,
        lastUpdated: summary.lastUpdated,
        primaryValue: summary.primaryValue,
        unit: summary.unit,
        vizConfig: vizConfig,
        avgLabel: stats?.avgLabel,
        deltaLabel: stats?.deltaLabel,
        avgValue: stats?.avgValue,
        bestValue: stats?.bestValue,
        worstValue: stats?.worstValue,
        changeValue: stats?.changeValue,
      );
    }).toList();

    final loaded = tiles.where((t) => t.dataState == TileDataState.loaded).length;
    final noSource = tiles.where((t) => t.dataState == TileDataState.noSource).length;
    debugPrint('[DashboardTiles] Result: $loaded loaded, $noSource noSource '
        '(total ${tiles.length})');

    return tiles;
  } catch (e, st) {
    debugPrint('[DashboardTiles] ERROR building tiles: $e');
    debugPrint('[DashboardTiles] Stack trace: $st');
    return TileId.values
        .map((id) => TileData(
              tileId: id,
              dataState: TileDataState.noSource,
              lastUpdated: null,
            ))
        .toList();
  }
});

/// Converts a [MetricSeries] into a [CategorySummary] for use with [_buildTileViz].
///
/// Maps [MetricSeries.currentValue] → [CategorySummary.primaryValue],
/// [MetricSeries.dataPoints] → [CategorySummary.trend], etc.
CategorySummary _summaryFromSeries(MetricSeries series, HealthCategory category) {
  final values = series.dataPoints.map((p) => p.value).toList();
  return CategorySummary(
    category: category,
    primaryValue: series.currentValue ??
        (values.isNotEmpty ? _fmtStat(values.last) : '—'),
    unit: series.unit.isNotEmpty ? series.unit : null,
    deltaPercent: series.deltaPercent,
    trend: values.isNotEmpty ? values : null,
    lastUpdated: series.dataPoints.isNotEmpty
        ? series.dataPoints.last.timestamp
        : null,
  );
}
