# Data Tab Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all blocking and degraded gaps identified in the 2026-03-20 Data Tab code review: typed tile visualizations, goal progress, stats population, disconnected-source state, per-category time range, search result preview, and a cluster of polish fixes.

**Architecture:** Changes flow in three layers — (1) domain/provider layer adds typed viz, stats, and goal wiring; (2) presentation layer wires the new data to the widgets that already accept it; (3) screen-level fixes close the edge-case and UX gaps. Tasks 1–3 are sequential (each builds on the previous). Tasks 4–10 are independent and can run in parallel after Task 3 or alongside it.

**Tech Stack:** Flutter, Riverpod, Dart sealed classes, flutter_test

---

## Files modified by this plan

| File | Changes |
|------|---------|
| `lib/features/data/domain/tile_models.dart` | Add stats fields to `TileData` |
| `lib/features/data/domain/data_models.dart` | Add `isNetworkError` to `DashboardData` |
| `lib/features/data/providers/data_providers.dart` | Typed viz builder, stats population, dailyGoals wiring, dashboardProvider error flag, `dashboardHasNetworkErrorProvider` |
| `lib/features/data/presentation/widgets/tile_grid.dart` | Pass stats to `MetricTile` + `TileExpandedView`; fix coach prefill extraction |
| `lib/features/data/presentation/health_dashboard_screen.dart` | Disconnected-source state, per-category range fix, edit-exit guard, color picker default |
| `lib/features/data/presentation/widgets/search_overlay.dart` | Pass viz/stats to embedded `MetricTile` |
| `lib/features/data/presentation/widgets/metric_tile.dart` | Add Semantics wrapper |
| `lib/features/data/presentation/widgets/category_filter_chips.dart` | Expand touch target to 48 dp |
| `lib/features/data/presentation/widgets/health_score_strip.dart` | Add Semantics label |
| `test/features/data/providers/data_providers_test.dart` | New tests for typed viz + stats + goals |
| `test/features/data/domain/tile_models_test.dart` | Stats field tests |

---

## Task 1 — Add stats fields to TileData

**Files:**
- Modify: `lib/features/data/domain/tile_models.dart`
- Test: `test/features/data/domain/tile_models_test.dart`

These fields flow from the provider layer through TileGrid into MetricTile and TileExpandedView. Adding them to TileData keeps the data co-located with the tile and avoids a second provider watch in the grid.

- [ ] **Step 1.1 — Write the failing test**

Open `test/features/data/domain/tile_models_test.dart` and add a new group at the end of `main()`:

```dart
group('TileData stats fields', () {
  test('TileData accepts stats fields and exposes them', () {
    const td = TileData(
      tileId: TileId.steps,
      dataState: TileDataState.loaded,
      avgLabel: 'Avg 8.2k',
      deltaLabel: '↑ 12%',
      avgValue: '8,200',
      bestValue: '12,450',
      worstValue: '3,100',
      changeValue: '+12%',
    );
    expect(td.avgLabel, 'Avg 8.2k');
    expect(td.deltaLabel, '↑ 12%');
    expect(td.avgValue, '8,200');
    expect(td.bestValue, '12,450');
    expect(td.worstValue, '3,100');
    expect(td.changeValue, '+12%');
  });

  test('TileData stats fields default to null', () {
    const td = TileData(
      tileId: TileId.hrv,
      dataState: TileDataState.noSource,
    );
    expect(td.avgLabel, isNull);
    expect(td.deltaLabel, isNull);
    expect(td.avgValue, isNull);
    expect(td.bestValue, isNull);
    expect(td.worstValue, isNull);
    expect(td.changeValue, isNull);
  });
});
```

- [ ] **Step 1.2 — Run to confirm failure**

```
flutter test test/features/data/domain/tile_models_test.dart
```
Expected: compilation error (fields don't exist yet).

- [ ] **Step 1.3 — Add stats fields to TileData**

In `lib/features/data/domain/tile_models.dart`, replace the `TileData` class:

```dart
/// Full tile data: identity, state, last-updated timestamp, visualization,
/// and optional pre-computed stats for footer/expanded-view display.
class TileData {
  const TileData({
    required this.tileId,
    required this.dataState,
    this.lastUpdated,
    this.visualization,
    this.avgLabel,
    this.deltaLabel,
    this.avgValue,
    this.bestValue,
    this.worstValue,
    this.changeValue,
  });

  final TileId tileId;
  final TileDataState dataState;

  /// ISO-8601 timestamp of last successful data sync. Null if never synced.
  final String? lastUpdated;

  /// Visualization payload — null unless [dataState] == [TileDataState.loaded].
  final TileVisualizationData? visualization;

  // ── Stats footer (MetricTile, tall/wide only) ──────────────────────────────

  /// Formatted average label (e.g. "Avg 8.2k"). Null if no trend data.
  final String? avgLabel;

  /// Formatted delta label (e.g. "↑ 12%"). Null if no delta available.
  final String? deltaLabel;

  // ── Stats row (TileExpandedView) ───────────────────────────────────────────

  /// Formatted average value string. Null if no trend data.
  final String? avgValue;

  /// Formatted best (max) value string. Null if no trend data.
  final String? bestValue;

  /// Formatted worst (min) value string. Null if no trend data.
  final String? worstValue;

  /// Formatted change value string (e.g. "+12%"). Null if no delta.
  final String? changeValue;
}
```

- [ ] **Step 1.4 — Run tests to confirm pass**

```
flutter test test/features/data/domain/tile_models_test.dart
```
Expected: all tests pass.

- [ ] **Step 1.5 — Commit**

```bash
git add lib/features/data/domain/tile_models.dart test/features/data/domain/tile_models_test.dart
git commit -m "feat(data): add stats fields to TileData for footer and expanded-view"
```

---

## Task 2 — Typed viz builder + dailyGoals wiring + stats population

**Files:**
- Modify: `lib/features/data/providers/data_providers.dart`
- Modify: `lib/features/data/domain/data_models.dart`
- Test: `test/features/data/providers/data_providers_test.dart`

This is the core fix. The provider needs to:
1. Build the correct `TileVisualizationData` subtype for each tile from `CategorySummary`
2. Pre-compute `avgLabel`, `deltaLabel`, and expanded stats from the trend array
3. Wire `dailyGoalsProvider` to populate goal indicators on water/steps tiles
4. Add `isNetworkError` to `DashboardData` so the screen can distinguish a new user from a disconnected one

### Sub-task 2a — Add `isNetworkError` to DashboardData

- [ ] **Step 2a.1 — Add field to DashboardData**

In `lib/features/data/domain/data_models.dart`, update `DashboardData`:

```dart
class DashboardData {
  const DashboardData({
    required this.categories,
    required this.visibleOrder,
    this.isNetworkError = false,
  });

  final List<CategorySummary> categories;
  final List<String> visibleOrder;

  /// True when the last fetch failed due to a network/server error.
  /// False when the API returned successfully (even with 0 categories).
  final bool isNetworkError;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final rawCats = json['categories'] as List<dynamic>? ?? [];
    final rawOrder = json['visible_order'] as List<dynamic>? ?? [];
    return DashboardData(
      categories: rawCats
          .map((e) => CategorySummary.fromJson(e as Map<String, dynamic>))
          .whereType<CategorySummary>()
          .toList(),
      visibleOrder: rawOrder.map((e) => e as String).toList(),
    );
  }
}
```

Update the `dashboardProvider` catch block to set `isNetworkError: true`:

```dart
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
```

Add a derived provider below `dashboardProvider` in `data_providers.dart`:

```dart
/// True when [dashboardProvider] resolved but the fetch failed (network error).
/// False when the API returned successfully or while loading.
/// Used by [HealthDashboardScreen] to distinguish a disconnected returning user
/// from a first-time user with no connected devices.
final dashboardHasNetworkErrorProvider = Provider<bool>((ref) {
  final dash = ref.watch(dashboardProvider);
  return dash.valueOrNull?.isNetworkError == true;
});
```

### Sub-task 2b — Typed viz builder function

- [ ] **Step 2b.0 — Update `_containerWithDashboard` to override `dailyGoalsProvider`**

`dashboardTilesProvider` (after step 2b.4) will `await ref.watch(dailyGoalsProvider.future)`. The existing test helper must override that provider or every test that calls it will hit the real API and fail.

In `test/features/data/providers/data_providers_test.dart`, **replace** the existing `_containerWithDashboard` function (around line 45):

```dart
// Add at top of file, alongside existing imports:
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/features/today/domain/today_models.dart';

/// Creates a [ProviderContainer] with [dashboardProvider] overridden to return
/// [data] without hitting the network, and [dailyGoalsProvider] overridden to
/// return [goals] (default empty) so tests never hit the real API.
ProviderContainer _containerWithDashboard(
  DashboardData data, {
  List<DailyGoal> goals = const [],
}) {
  return ProviderContainer(
    overrides: [
      dashboardProvider.overrideWith((ref) async => data),
      dailyGoalsProvider.overrideWith((ref) async => goals),
    ],
  );
}
```

- [ ] **Step 2b.1 — Write failing tests for typed viz**

Add a new group to `test/features/data/providers/data_providers_test.dart`:

```dart
group('dashboardTilesProvider — typed visualizations', () {
  test('steps tile builds BarChartData when trend is available', () async {
    final data = DashboardData(
      categories: [
        CategorySummary(
          category: HealthCategory.activity,
          primaryValue: '8,432',
          unit: 'steps',
          deltaPercent: 12.0,
          trend: [7000, 8000, 9000, 6000, 8432, 7500, 8200],
          lastUpdated: '2026-03-19T12:00:00Z',
        ),
      ],
      visibleOrder: ['activity'],
    );
    final container = _containerWithDashboard(data);
    addTearDown(container.dispose);

    final tiles = await container.read(dashboardTilesProvider.future);
    final stepsTile = tiles.firstWhere((t) => t.tileId == TileId.steps);

    expect(stepsTile.dataState, TileDataState.loaded);
    expect(stepsTile.visualization, isA<BarChartData>());
    final viz = stepsTile.visualization as BarChartData;
    expect(viz.dailyValues, [7000, 8000, 9000, 6000, 8432, 7500, 8200]);
    expect(viz.delta, 12.0);
  });

  test('steps tile builds ValueData when trend is absent', () async {
    final data = DashboardData(
      categories: [
        CategorySummary(
          category: HealthCategory.activity,
          primaryValue: '8,432',
          unit: 'steps',
          lastUpdated: '2026-03-19T12:00:00Z',
        ),
      ],
      visibleOrder: ['activity'],
    );
    final container = _containerWithDashboard(data);
    addTearDown(container.dispose);

    final tiles = await container.read(dashboardTilesProvider.future);
    final stepsTile = tiles.firstWhere((t) => t.tileId == TileId.steps);
    expect(stepsTile.visualization, isA<ValueData>());
  });

  test('mood tile builds DotsData when trend is available', () async {
    final data = DashboardData(
      categories: [
        CategorySummary(
          category: HealthCategory.wellness,
          primaryValue: '7',
          unit: '',
          trend: [6, 7, 5, 8, 7, 6, 7],
          lastUpdated: '2026-03-19T12:00:00Z',
        ),
      ],
      visibleOrder: ['wellness'],
    );
    final container = _containerWithDashboard(data);
    addTearDown(container.dispose);

    final tiles = await container.read(dashboardTilesProvider.future);
    final moodTile = tiles.firstWhere((t) => t.tileId == TileId.mood);
    expect(moodTile.visualization, isA<DotsData>());
    final viz = moodTile.visualization as DotsData;
    expect(viz.values.length, 7);
  });

  test('restingHeartRate tile builds LineChartData when trend is available',
      () async {
    final data = DashboardData(
      categories: [
        CategorySummary(
          category: HealthCategory.heart,
          primaryValue: '62',
          unit: 'bpm',
          trend: [64, 63, 62, 65, 61, 62, 62],
          lastUpdated: '2026-03-19T12:00:00Z',
        ),
      ],
      visibleOrder: ['heart'],
    );
    final container = _containerWithDashboard(data);
    addTearDown(container.dispose);

    final tiles = await container.read(dashboardTilesProvider.future);
    final hrTile =
        tiles.firstWhere((t) => t.tileId == TileId.restingHeartRate);
    expect(hrTile.visualization, isA<LineChartData>());
  });

  test('bloodPressure tile builds DualValueData for "120/80" format', () async {
    final data = DashboardData(
      categories: [
        CategorySummary(
          category: HealthCategory.vitals,
          primaryValue: '120/80',
          unit: 'mmHg',
          lastUpdated: '2026-03-19T12:00:00Z',
        ),
      ],
      visibleOrder: ['vitals'],
    );
    final container = _containerWithDashboard(data);
    addTearDown(container.dispose);

    final tiles = await container.read(dashboardTilesProvider.future);
    final bpTile =
        tiles.firstWhere((t) => t.tileId == TileId.bloodPressure);
    expect(bpTile.visualization, isA<DualValueData>());
    final viz = bpTile.visualization as DualValueData;
    expect(viz.topValue, '120');
    expect(viz.bottomValue, '80');
  });
});

group('dashboardTilesProvider — stats population', () {
  test('avgLabel and deltaLabel populated from trend + deltaPercent', () async {
    final data = DashboardData(
      categories: [
        CategorySummary(
          category: HealthCategory.activity,
          primaryValue: '8,432',
          unit: 'steps',
          deltaPercent: 12.3,
          trend: [7000, 8000, 9000, 6000, 8432, 7500, 8200],
          lastUpdated: '2026-03-19T12:00:00Z',
        ),
      ],
      visibleOrder: ['activity'],
    );
    final container = _containerWithDashboard(data);
    addTearDown(container.dispose);

    final tiles = await container.read(dashboardTilesProvider.future);
    final stepsTile = tiles.firstWhere((t) => t.tileId == TileId.steps);

    expect(stepsTile.avgLabel, isNotNull);
    expect(stepsTile.deltaLabel, isNotNull);
    expect(stepsTile.avgValue, isNotNull);
    expect(stepsTile.bestValue, isNotNull);
    expect(stepsTile.worstValue, isNotNull);
    expect(stepsTile.changeValue, isNotNull);
    // delta should include the sign
    expect(stepsTile.deltaLabel, contains('12'));
    expect(stepsTile.changeValue, contains('12'));
  });

  test('stats are null when trend is absent', () async {
    final data = DashboardData(
      categories: [
        CategorySummary(
          category: HealthCategory.activity,
          primaryValue: '8,432',
          unit: 'steps',
        ),
      ],
      visibleOrder: ['activity'],
    );
    final container = _containerWithDashboard(data);
    addTearDown(container.dispose);

    final tiles = await container.read(dashboardTilesProvider.future);
    final stepsTile = tiles.firstWhere((t) => t.tileId == TileId.steps);

    expect(stepsTile.avgLabel, isNull);
    expect(stepsTile.avgValue, isNull);
  });
});
```

- [ ] **Step 2b.2 — Run to confirm failure**

```
flutter test test/features/data/providers/data_providers_test.dart
```
Expected: failures on the new groups (visualization types are still `ValueData`).

- [ ] **Step 2b.3 — Implement typed viz builder in data_providers.dart**

Add the following top-level helpers **before** the `dashboardTilesProvider` declaration in `data_providers.dart`. Also update the import list to include `today_providers.dart` and `today_models.dart`:

```dart
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
```

Add the helper functions (place them between `customDateRangeProvider` and `tileOrderingProvider`):

```dart
// ── Tile Visualization Builder ────────────────────────────────────────────────

/// Day-of-week abbreviations (Mon first, Sun last) for bar chart labels.
const _kDayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Formats a double for a stats label, using compact notation for large numbers.
String _fmtStat(double v) {
  if (v >= 1000) {
    return '${(v / 1000).toStringAsFixed(1)}k';
  }
  return v.toStringAsFixed(v == v.truncateToDouble() ? 0 : 1);
}

/// Formats a delta percentage with a sign prefix and arrow.
String _fmtDelta(double delta) {
  final sign = delta >= 0 ? '↑' : '↓';
  return '$sign ${delta.abs().toStringAsFixed(1)}%';
}

/// Pre-computed stats derived from a 7-day [trend] array.
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

  // Helper: build BarChartData when trend is available.
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

  // Helper: build LineChartData when trend is available.
  TileVisualizationData lineOrValue() {
    if (trend != null && trend.isNotEmpty) {
      return LineChartData(values: trend, delta: delta);
    }
    return ValueData(primaryValue: primary, secondaryLabel: unit);
  }

  // Helper: build DotsData when trend is available (mood/energy/stress).
  TileVisualizationData dotsOrValue() {
    if (trend != null && trend.isNotEmpty) {
      return DotsData(values: trend, todayLabel: primary);
    }
    return ValueData(primaryValue: primary, secondaryLabel: unit);
  }

  switch (id) {
    // ── Activity ──────────────────────────────────────────────────────────────
    case TileId.steps:
      // Use RingData if the user has a steps goal configured.
      final stepsGoal = goals
          .where((g) => g.id.contains('steps') || g.label.toLowerCase().contains('steps'))
          .firstOrNull;
      if (stepsGoal != null && stepsGoal.target > 0) {
        final current = double.tryParse(primary.replaceAll(',', '')) ?? 0;
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
      // CountBadgeData: parse the int count from primaryValue.
      final count = int.tryParse(primary.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return CountBadgeData(count: count);

    // ── Sleep ─────────────────────────────────────────────────────────────────
    case TileId.sleepDuration:
      return barOrValue();

    case TileId.sleepStages:
      // StackedBarData requires per-stage breakdowns not available in
      // CategorySummary — fall back to ValueData until the API provides it.
      return ValueData(primaryValue: primary, secondaryLabel: unit);

    // ── Heart ─────────────────────────────────────────────────────────────────
    case TileId.restingHeartRate:
    case TileId.hrv:
      return lineOrValue();

    case TileId.vo2Max:
      // GaugeData: VO₂ max typically ranges 20–70 ml/kg/min.
      final v = double.tryParse(primary.replaceAll(',', ''));
      if (v != null) {
        return GaugeData(percent: (v / 70.0).clamp(0.0, 1.0), label: primary);
      }
      return ValueData(primaryValue: primary, secondaryLabel: unit);

    // ── Body ──────────────────────────────────────────────────────────────────
    case TileId.weight:
    case TileId.bodyFat:
      return lineOrValue();

    // ── Vitals ────────────────────────────────────────────────────────────────
    case TileId.bloodPressure:
      // DualValueData: parse "120/80" format.
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

    // ── Nutrition ─────────────────────────────────────────────────────────────
    case TileId.calories:
      if (trend != null && trend.isNotEmpty) {
        return AreaChartData(values: trend, delta: delta);
      }
      return ValueData(primaryValue: primary, secondaryLabel: unit);

    case TileId.water:
      // FillGaugeData: current vs goal from dailyGoalsProvider.
      final waterGoal = goals
          .where((g) => g.id.contains('water') || g.label.toLowerCase().contains('water'))
          .firstOrNull;
      final current = double.tryParse(primary.replaceAll(',', '')) ?? 0;
      if (waterGoal != null && waterGoal.target > 0) {
        return FillGaugeData(
          current: current,
          goal: waterGoal.target,
          unit: unit,
        );
      }
      return ValueData(primaryValue: primary, secondaryLabel: unit);

    // ── Wellness ──────────────────────────────────────────────────────────────
    case TileId.mood:
    case TileId.energy:
    case TileId.stress:
      return dotsOrValue();

    // ── Cycle ─────────────────────────────────────────────────────────────────
    case TileId.cycle:
      // CalendarDotsData requires cycle-phase data not in CategorySummary.
      return ValueData(primaryValue: primary, secondaryLabel: unit);

    // ── Environment ───────────────────────────────────────────────────────────
    case TileId.environment:
      // EnvironmentData requires AQI + UV values not in CategorySummary.
      return ValueData(primaryValue: primary, secondaryLabel: unit);

    // ── Mobility ──────────────────────────────────────────────────────────────
    case TileId.mobility:
      final v = double.tryParse(primary.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (v != null) {
        return GaugeData(percent: (v / 100.0).clamp(0.0, 1.0), label: primary);
      }
      return ValueData(primaryValue: primary, secondaryLabel: unit);
  }
}
```

- [ ] **Step 2b.4 — Update dashboardTilesProvider to use the builder + populate stats + wire goals**

Replace the entire `dashboardTilesProvider` declaration:

```dart
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
```

- [ ] **Step 2b.5 — Run all data provider tests**

```
flutter test test/features/data/providers/data_providers_test.dart
```
Expected: all tests pass including the new typed viz + stats groups.

- [ ] **Step 2b.6 — Commit**

```bash
git add lib/features/data/domain/data_models.dart \
        lib/features/data/providers/data_providers.dart \
        test/features/data/providers/data_providers_test.dart
git commit -m "feat(data): typed tile viz builder, stats population, dailyGoals wiring, network error flag"
```

---

## Task 3 — Wire stats to MetricTile and TileExpandedView in TileGrid

**Files:**
- Modify: `lib/features/data/presentation/widgets/tile_grid.dart`
- Test: `test/shared/widgets/metric_grid/metric_tile_test.dart`

MetricTile already accepts `avgLabel`/`deltaLabel`; TileExpandedView already accepts `avgValue`/`bestValue`/`worstValue`/`changeValue`. TileGrid just needs to extract them from `TileData` and pass them through.

Also fixes the `coachPrefillProvider` extraction to handle non-ValueData tiles (so it doesn't send "—" to the coach once typed viz is live).

- [ ] **Step 3.1 — Write failing test for stats footer visibility**

The existing metric tile test file is at `test/shared/widgets/metric_grid/metric_tile_test.dart` — there is no `test/features/data/presentation/widgets/metric_tile_test.dart`. Add a new group to the existing file:

```dart
group('MetricTile stats footer', () {
  testWidgets('stats footer visible on tall tile when avgLabel + deltaLabel provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MetricTile(
            tileId: TileId.steps,
            dataState: TileDataState.loaded,
            size: TileSize.tall,
            primaryValue: '8,432',
            unit: 'steps',
            avgLabel: 'Avg 8.2k',
            deltaLabel: '↑ 12%',
          ),
        ),
      ),
    );
    expect(find.text('Avg 8.2k'), findsOneWidget);
    expect(find.text('↑ 12%'), findsOneWidget);
  });
});
```

- [ ] **Step 3.2 — Run to confirm failure (stats footer never shows)**

```
flutter test test/shared/widgets/metric_grid/metric_tile_test.dart
```
Expected: test fails because avgLabel is not passed from TileGrid yet (but MetricTile itself should show it when passed directly in the test — check if the test actually fails here; if it passes, the MetricTile widget already renders it).

- [ ] **Step 3.3 — Update _buildTileContent in tile_grid.dart to pass stats**

In `lib/features/data/presentation/widgets/tile_grid.dart`, update `_buildTileContent`:

Replace the section that builds `TileExpandedView` (lines ~104–127):

```dart
if (isExpanded && tileData != null && tileData.dataState == TileDataState.loaded) {
  final viz = tileData.visualization;
  // Extract primaryValue from the visualization for the coach prefill.
  // Handles ValueData, RingData, CountBadgeData, and other subtypes.
  final primaryValue = switch (viz) {
    ValueData(:final primaryValue) => primaryValue,
    RingData(:final value) => value.toStringAsFixed(0),
    CountBadgeData(:final count) => count.toString(),
    DualValueData(:final topValue, :final bottomValue) =>
      '$topValue/$bottomValue',
    GaugeData(:final label) => label ?? '—',
    _ => '—',
  };
  final effectiveColor = colorOverride != null
      ? Color(colorOverride)
      : categoryColor(id.category);

  return TileExpandedView(
    key: ValueKey('expanded_${id.name}'),
    tileId: id,
    size: size,
    visualization: viz != null
        ? buildTileVisualization(
            data: viz,
            categoryColor: effectiveColor,
          )
        : null,
    primaryValue: primaryValue,
    unit: viz is ValueData ? viz.secondaryLabel : null,
    colorOverride: colorOverride,
    avgValue: tileData.avgValue,
    bestValue: tileData.bestValue,
    worstValue: tileData.worstValue,
    changeValue: tileData.changeValue,
    onViewDetails: () => onViewDetails(id),
    onAskCoach: () => onAskCoach(id, primaryValue),
  );
}
```

Replace the `MetricTile(...)` build (lines ~137–152):

```dart
return MetricTile(
  key: ValueKey('tile_${id.name}'),
  tileId: id,
  dataState: tileData?.dataState ?? TileDataState.noSource,
  size: size,
  visualization: viz != null
      ? buildTileVisualization(
          data: viz,
          categoryColor: effectiveColor,
        )
      : null,
  primaryValue: primaryValue,
  unit: unit,
  avgLabel: tileData?.avgLabel,
  deltaLabel: tileData?.deltaLabel,
  lastUpdated: tileData?.lastUpdated,
  colorOverride: colorOverride,
);
```

Also update the `primaryValue` extraction for non-expanded tiles (lines ~130–132) to use the same switch logic:

```dart
final viz = tileData?.visualization;
final primaryValue = viz == null
    ? null
    : switch (viz) {
        ValueData(:final primaryValue) => primaryValue,
        RingData(:final value) => value.toStringAsFixed(0),
        CountBadgeData(:final count) => count.toString(),
        DualValueData(:final topValue, :final bottomValue) =>
          '$topValue/$bottomValue',
        GaugeData(:final label) => label ?? null,
        _ => null,
      };
final unit = viz is ValueData ? viz.secondaryLabel : null;
```

- [ ] **Step 3.4 — Run all widget tests**

```
flutter test test/features/data/presentation/widgets/
```
Expected: all tests pass.

- [ ] **Step 3.5 — Commit**

```bash
git add lib/features/data/presentation/widgets/tile_grid.dart \
        test/shared/widgets/metric_grid/metric_tile_test.dart
git commit -m "fix(data): wire stats fields and typed viz to MetricTile/TileExpandedView; fix coach prefill extraction"
```

---

## Task 4 — Disconnected source state (returning user vs first-time user)

**Files:**
- Modify: `lib/features/data/presentation/health_dashboard_screen.dart`
- Test: `test/features/data/presentation/health_dashboard_screen_test.dart`

The screen currently shows `OnboardingEmptyState` ("Connect a Device") for any user whose tiles are all `noSource` — including a returning user whose device went offline mid-session. This task distinguishes those cases.

- [ ] **Step 4.1 — Write failing test**

Add to `test/features/data/presentation/health_dashboard_screen_test.dart`:

```dart
testWidgets('shows network error banner instead of onboarding when fetch fails for returning user', (tester) async {
  // Simulate: user has previously connected, but this fetch failed.
  // dashboardProvider returns isNetworkError: true.
  // dashboardTilesProvider returns all noSource tiles.
  // The screen should NOT show "Connect a Device"; it should show a network error message.
  // (Implementation detail: the exact widget/text depends on the chosen design)
  // For this test, we just verify OnboardingEmptyState is NOT shown.
  final container = ProviderContainer(
    overrides: [
      dashboardProvider.overrideWith(
        (_) async => const DashboardData(
          categories: [],
          visibleOrder: [],
          isNetworkError: true,
        ),
      ),
      dailyGoalsProvider.overrideWith((_) async => const <DailyGoal>[]),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: HealthDashboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Should NOT show the onboarding "Connect a Device" button.
  expect(find.text('Connect a Device'), findsNothing);
  // Should show a network/source error indicator.
  expect(find.textContaining('unavailable'), findsWidgets);
});
```

- [ ] **Step 4.1b — Add missing imports to the test file**

At the top of `test/features/data/presentation/health_dashboard_screen_test.dart`, add:

```dart
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
```

- [ ] **Step 4.2 — Run to confirm failure**

```
flutter test test/features/data/presentation/health_dashboard_screen_test.dart --name "shows network error banner"
```
Expected: fails (OnboardingEmptyState is still shown).

- [ ] **Step 4.3 — Update HealthDashboardScreen to use dashboardHasNetworkErrorProvider**

In `lib/features/data/presentation/health_dashboard_screen.dart`, inside `build()`:

After `final scoreAsync = ref.watch(healthScoreProvider);` add:
```dart
final hasNetworkError = ref.watch(dashboardHasNetworkErrorProvider);
```

Replace the `allNoSource` section in the sliver list:

```dart
// ── Onboarding empty state, network error, or Tile Grid ──────────────
if (allNoSource && hasNetworkError)
  SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Data source unavailable',
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceXs),
          const Text(
            'Pull down to retry when your connection is restored.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  )
else if (allNoSource)
  SliverToBoxAdapter(
    child: OnboardingEmptyState(
      onConnectDevice: () =>
          context.push(RouteNames.settingsIntegrationsPath),
      onLogManually: () => context.go('/today'),
    ),
  )
else if (tilesAsync.isLoading)
  _buildLoadingSlivers()
else
  SliverToBoxAdapter(
    // ... existing TileGridBox ...
  ),
```

- [ ] **Step 4.4 — Run tests**

```
flutter test test/features/data/presentation/health_dashboard_screen_test.dart
```
Expected: all tests pass including the new one.

- [ ] **Step 4.5 — Commit**

```bash
git add lib/features/data/presentation/health_dashboard_screen.dart \
        test/features/data/presentation/health_dashboard_screen_test.dart
git commit -m "fix(data): distinguish disconnected-source from onboarding — show 'Data source unavailable' instead of 'Connect a Device'"
```

---

## Task 5 — Per-category time range selector triggers re-fetch

**Files:**
- Modify: `lib/features/data/presentation/health_dashboard_screen.dart`

The `_categoryTimeRange` state variable is written by `_CategoryTimeRangeSelector` but never propagated to `dashboardTimeRangeProvider`, so changing the per-category range has no effect on data. Fix: when the per-category range changes, write it to `dashboardTimeRangeProvider`. When the category filter is cleared, restore the original global range.

**Known limitation:** If the user changes the global range (via `GlobalTimeRangeSelector`) while a category filter is active, the snapshot will be stale. The restore-on-clear will then silently revert the user's explicit global range change. This is an acceptable UX edge case for the current iteration — a future improvement would be to invalidate the snapshot when the global range changes while a filter is active.

- [ ] **Step 5.1 — Add `_globalTimeRange` snapshot field**

In `_HealthDashboardScreenState`, add a field to remember the global range before a category override:

```dart
/// Snapshot of the global time range when a category filter is activated.
/// Restored when the category filter is cleared.
TimeRange? _globalTimeRangeSnapshot;
```

- [ ] **Step 5.2 — Update the `onSelected` callback in CategoryFilterChips**

In `build()`, replace the `onSelected` callback for `CategoryFilterChips`:

```dart
onSelected: (cat) {
  ref.read(tileFilterProvider.notifier).state = cat;
  setState(() {
    _expandedTileId = null;
    if (cat != null) {
      // Snapshot the global range so we can restore it when filter is cleared.
      _globalTimeRangeSnapshot = ref.read(dashboardTimeRangeProvider);
      _categoryTimeRange = _globalTimeRangeSnapshot;
    } else {
      // Restore global range when filter is cleared.
      if (_globalTimeRangeSnapshot != null) {
        ref.read(dashboardTimeRangeProvider.notifier).state =
            _globalTimeRangeSnapshot!;
      }
      _globalTimeRangeSnapshot = null;
      _categoryTimeRange = null;
    }
  });
},
```

- [ ] **Step 5.3 — Update the `_CategoryTimeRangeSelector` `onChanged` callback**

In `build()`, replace the inline `onChanged` for `_CategoryTimeRangeSelector`:

```dart
onChanged: (range) {
  setState(() => _categoryTimeRange = range);
  // Write to dashboardTimeRangeProvider so tiles re-fetch with the new range.
  ref.read(dashboardTimeRangeProvider.notifier).state = range;
},
```

- [ ] **Step 5.4 — Run widget tests**

```
flutter test test/features/data/presentation/health_dashboard_screen_test.dart
```
Expected: all tests pass (no regression).

- [ ] **Step 5.5 — Commit**

```bash
git add lib/features/data/presentation/health_dashboard_screen.dart
git commit -m "fix(data): per-category time range selector now writes to dashboardTimeRangeProvider to trigger re-fetch"
```

---

## Task 6 — Fix search result tile preview

**Files:**
- Modify: `lib/features/data/presentation/widgets/search_overlay.dart`

The `_SearchResultTile` builds a `MetricTile` with no visualization, primaryValue, or unit — it always shows "—". Fix: pass the tile's actual viz/value/unit from `TileData`.

- [ ] **Step 6.1 — Update `_SearchResultTile` to pass viz data**

In `lib/features/data/presentation/widgets/search_overlay.dart`, find the `_SearchResultTile` class.

Update the `MetricTile` construction inside the `if (tile.dataState == TileDataState.loaded)` branch:

```dart
if (tile.dataState == TileDataState.loaded)
  Expanded(
    child: Builder(builder: (context) {
      final viz = tile.visualization;
      final effectiveColor = categoryColor(tile.tileId.category);
      return MetricTile(
        tileId: tile.tileId,
        dataState: tile.dataState,
        size: TileSize.square,
        visualization: viz != null
            ? buildTileVisualization(
                data: viz,
                categoryColor: effectiveColor,
              )
            : null,
        primaryValue: viz is ValueData ? viz.primaryValue : null,
        unit: viz is ValueData ? viz.secondaryLabel : null,
      );
    }),
  )
```

Add the missing imports to `search_overlay.dart` if not already present:
```dart
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_visualizations.dart';
```

- [ ] **Step 6.2 — Run widget tests**

```
flutter test test/features/data/presentation/widgets/
```
Expected: all tests pass.

- [ ] **Step 6.3 — Commit**

```bash
git add lib/features/data/presentation/widgets/search_overlay.dart
git commit -m "fix(data): search result tile now passes viz/value/unit to MetricTile for accurate preview"
```

---

## Task 7 — Polish fixes (color picker default, edit-exit invalidate guard, touch targets)

**Files:**
- Modify: `lib/features/data/presentation/health_dashboard_screen.dart`
- Modify: `lib/features/data/presentation/widgets/category_filter_chips.dart`

Three small polish fixes bundled into one commit:

### 7a — Fix color picker `defaultColor`

In `health_dashboard_screen.dart`, the `_onColorPick` method passes `const Color(0xFF007AFF)` as `defaultColor` for every tile. The reset chip should instead show the category's semantic color.

Replace in `_onColorPick`:
```dart
// Before:
currentColor: currentColor ?? const Color(0xFF007AFF),
defaultColor: const Color(0xFF007AFF),

// After:
currentColor: currentColor ?? categoryColor(tileId.category),
defaultColor: categoryColor(tileId.category),
```

Add the import at the top if not already there:
```dart
import 'package:zuralog/features/data/domain/category_color.dart';
```

### 7b — Guard `_exitEditMode` invalidate

In `health_dashboard_screen.dart`, track whether a reorder actually occurred:

Add a field to `_HealthDashboardScreenState`:
```dart
bool _reorderedDuringEdit = false;
```

In `_onReorder`:
```dart
void _onReorder(int oldIndex, int newIndex) {
  _reorderedDuringEdit = true; // mark that order changed
  // ... rest of existing implementation ...
}
```

In `_enterEditMode`, reset the flag:
```dart
void _enterEditMode() {
  ref.read(hapticServiceProvider).medium();
  setState(() {
    _isEditMode = true;
    _expandedTileId = null;
    _reorderedDuringEdit = false;
  });
}
```

In `_exitEditMode`, only invalidate when order changed:
```dart
void _exitEditMode() {
  ref.read(hapticServiceProvider).medium();
  final didReorder = _reorderedDuringEdit;
  setState(() {
    _isEditMode = false;
    _reorderedDuringEdit = false;
  });
  // Only re-apply smart ordering when the tile order actually changed.
  if (didReorder) ref.invalidate(dashboardTilesProvider);
}
```

### 7c — Expand chip touch targets to 48 dp

In `lib/features/data/presentation/widgets/category_filter_chips.dart`, find all `GestureDetector` wrappers with `height: 32` chips. Wrap each `GestureDetector` with a `SizedBox` of height 48 and vertically-center the visible chip:

```dart
// Before:
GestureDetector(
  onTap: ...,
  child: Container(height: 32, ...),
)

// After:
GestureDetector(
  onTap: ...,
  child: SizedBox(
    height: 48,
    child: Center(
      child: Container(height: 32, ...),
    ),
  ),
)
```

In `lib/features/data/presentation/widgets/global_time_range_selector.dart`, find the `_RangeChip` widget's `build()` method (line ~149). The chip is a `GestureDetector` wrapping an `AnimatedContainer` with `height: 32`. Apply the same SizedBox wrapping:

```dart
// In _RangeChip.build(), replace:
return GestureDetector(
  onTap: onTap,
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    // ...
  ),
);

// With:
return GestureDetector(
  onTap: onTap,
  child: SizedBox(
    height: 48,
    child: Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        // ... (keep all existing decoration/child unchanged)
      ),
    ),
  ),
);
```

- [ ] **Step 7.1 — Make the changes (7a, 7b, 7c)**

- [ ] **Step 7.2 — Run tests**

```
flutter test test/features/data/
```
Expected: all tests pass.

- [ ] **Step 7.3 — Commit**

```bash
git add lib/features/data/presentation/health_dashboard_screen.dart \
        lib/features/data/presentation/widgets/category_filter_chips.dart \
        lib/features/data/presentation/widgets/global_time_range_selector.dart
git commit -m "fix(data): color picker uses category color; edit-exit guards invalidate; chip touch targets expanded to 48dp"
```

---

## Task 8 — Accessibility: Semantics on MetricTile, HealthScoreStrip, chips

**Files:**
- Modify: `lib/features/data/presentation/widgets/metric_tile.dart`
- Modify: `lib/features/data/presentation/widgets/health_score_strip.dart`
- Modify: `lib/features/data/presentation/widgets/category_filter_chips.dart`

Add `Semantics` wrappers at key interaction points so screen readers can navigate the dashboard.

### 8a — MetricTile

In `metric_tile.dart`, wrap the outermost returned widget in a `Semantics` node. Place the `Semantics` at the top of the `build()` method:

```dart
@override
Widget build(BuildContext context) {
  final label = switch (dataState) {
    TileDataState.loaded =>
      '${tileId.displayName}: ${primaryValue ?? '—'}${unit != null ? ' $unit' : ''}',
    TileDataState.noSource =>
      '${tileId.displayName}: not connected',
    TileDataState.syncing =>
      '${tileId.displayName}: syncing',
    TileDataState.noDataForRange =>
      '${tileId.displayName}: no data for selected range',
    TileDataState.hidden =>
      '${tileId.displayName}: hidden',
  };

  return Semantics(
    label: label,
    button: false,
    child: _buildContent(context),
  );
}
```

Rename the existing `build()` body to `_buildContent(BuildContext context)`.

### 8b — HealthScoreStrip

In `health_score_strip.dart`, wrap the `GestureDetector` (or outermost widget) with a `Semantics` node:

```dart
return Semantics(
  label: 'Health score: ${score.toString()}. ${delta != null ? 'Change: $delta' : ''}. Tap to view breakdown.',
  button: true,
  child: GestureDetector(
    // ... existing ...
  ),
);
```

(Use the actual variable names from the file — the exact pattern is to add a `Semantics` wrapper with a descriptive label around the `GestureDetector` at line ~38.)

### 8c — CategoryFilterChips

In `category_filter_chips.dart`, add a `Semantics` label to each chip's `GestureDetector`:

```dart
Semantics(
  label: '${category.displayName} filter${isSelected ? ', selected' : ''}',
  button: true,
  selected: isSelected,
  child: GestureDetector(
    onTap: () => onSelected(isSelected ? null : category),
    child: SizedBox(height: 48, child: Center(child: Container(...))),
  ),
)
```

- [ ] **Step 8.1 — Make the Semantics changes**

- [ ] **Step 8.2 — Run full data test suite**

```
flutter test test/features/data/
```
Expected: all tests pass.

- [ ] **Step 8.3 — Commit**

```bash
git add lib/features/data/presentation/widgets/metric_tile.dart \
        lib/features/data/presentation/widgets/health_score_strip.dart \
        lib/features/data/presentation/widgets/category_filter_chips.dart
git commit -m "fix(data): add Semantics labels to MetricTile, HealthScoreStrip, and CategoryFilterChips for screen reader support"
```

---

## Task 9 — Final verification

- [ ] **Step 9.1 — Run the full data feature test suite**

```
flutter test test/features/data/ --reporter expanded
```
Expected: all tests pass, 0 failures.

- [ ] **Step 9.2 — Run the full test suite for regression**

```
flutter test
```
Expected: all tests pass.

- [ ] **Step 9.3 — Verify no analysis errors**

```
flutter analyze lib/features/data/
```
Expected: No issues found.

- [ ] **Step 9.4 — Final commit (if any fixups needed)**

```bash
git add -A
git commit -m "fix(data): final analysis fixups from audit"
```

---

## Summary of gaps closed by this plan

| Gap | Task | Severity |
|-----|------|----------|
| `dashboardTilesProvider` produces only `ValueData` — 13 typed viz types dead | 2 | Blocking |
| `dailyGoalsProvider` never wired to tiles | 2 | Blocking |
| `MetricTile.avgLabel`/`deltaLabel` never passed — stats footer hidden | 1+3 | Blocking |
| `TileExpandedView` stats row always "—" | 1+3 | Blocking |
| Coach prefill sends "—" for non-ValueData tiles | 3 | Degraded |
| Disconnected source triggers onboarding screen | 4 | Degraded |
| Per-category time range selector is a visual no-op | 5 | Degraded |
| Search result tile shows no data | 6 | Degraded |
| Color picker default hardcoded to iOS blue | 7 | Polish |
| Edit-exit unconditionally triggers network re-fetch | 7 | Polish |
| Chip touch targets 32 px (below 48 dp minimum) | 7 | Polish |
| No Semantics on MetricTile / strips / chips | 8 | Degraded/Polish |
