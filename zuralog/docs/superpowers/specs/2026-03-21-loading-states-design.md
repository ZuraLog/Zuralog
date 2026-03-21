# Loading States, Skeleton Screens & Empty States — Design Spec

**Date:** 2026-03-21
**Scope:** `lib/features/data/` — dashboard, metric detail, tile states, health score strip
**Approach selected:** B — Unified Shimmer Sweep

---

## 1. Context & Goals

The data feature currently has eight UX gaps that leave users confused about what is happening:

| # | Location | Current Problem |
|---|----------|----------------|
| 1 | Dashboard initial load | `_CardSkeleton` is a static blank rectangle — no animation, no internal structure |
| 2 | Syncing tile | `SyncingTileContent` pulses but bars don't match the real tile layout |
| 3 | Health Score Strip | `_SkeletonRow` is static — right color tokens but no animation |
| 4 | Metric Detail loading | Bare spinner; AppBar title disappears entirely |
| 5 | Metric Detail error | No retry button or recovery path |
| 6 | Metric Detail empty/single data | Plain text with no icon or CTA to help users self-serve |
| 7 | `noDataForRange` tile | Looks identical to a fully loaded tile — users can't tell the data is stale |
| 8 | Viz widgets with zero data | Chart area silently collapses (`SizedBox.shrink()`) |

**Goals:**
- Every state communicates clearly what is happening and what the user can do next.
- All skeleton animations use a single consistent style (left-to-right shimmer sweep).
- Skeleton shapes approximate the real content layout (header row, value, chart area).
- Error states always include a recovery action.
- Stale data is visually distinguishable from live data.
- Transitions between states cross-fade rather than snap.
- All states have correct accessibility semantics.

---

## 2. Shared Animation Infrastructure

### 2.1 `AppShimmer` widget

**File:** `lib/core/widgets/shimmer.dart`

A `StatefulWidget` with `SingleTickerProviderStateMixin` that wraps its child in a `ShaderMask`. The mask applies an animated `LinearGradient` that sweeps left-to-right over all child shapes simultaneously. All shimmer shapes in one skeleton stay perfectly in sync.

**Spec:**

```
AppShimmer
  - AnimationController: duration 1500ms, repeat (no reverse)
  - CurvedAnimation: Curves.easeInOut
  - ShaderMask blendMode: BlendMode.srcIn
  - Gradient: LinearGradient([shimmerBase, shimmerHighlight, shimmerBase])
    with begin/end alignment swept from Alignment(-2, 0) → Alignment(2, 0)
  - Does NOT apply ExcludeSemantics internally — callers are responsible for
    wrapping the skeleton in their own Semantics/ExcludeSemantics as needed.
    This keeps AppShimmer single-purpose and avoids nested-ExcludeSemantics surprises.
```

**Usage:**
```dart
AppShimmer(
  child: Column(children: [
    ShimmerBox(height: 12, width: 80),
    ShimmerBox(height: 24, widthFraction: 0.6),
  ]),
)
```

### 2.2 `ShimmerBox` widget

**File:** `lib/core/widgets/shimmer.dart` (same file)

A stateless `Container` with solid `Colors.white` fill and configurable `height`, `width`, `widthFraction`, and `borderRadius`. When inside `AppShimmer`, the `ShaderMask` replaces the white fill with the animated gradient. Outside `AppShimmer`, it renders as a plain white box (graceful fallback).

**Constructor params:**
- `height` (optional double — omit when the box is inside `Expanded` and should fill available space; provide when a fixed height is needed)
- `width` (optional double — fixed width)
- `widthFraction` (optional double 0–1 — uses `FractionallySizedBox` when provided)
- `borderRadius` (optional, default `BorderRadius.circular(4)`)
- `isCircle` (optional bool — uses `BoxShape.circle` when true; `height` used as diameter)

When both `height` and `width` are omitted, `ShimmerBox` expands to fill its parent via `SizedBox.expand`. This is the correct pattern when nested inside `Expanded`.

---

## 3. Dashboard `_CardSkeleton` (Gap #1)

**File:** `lib/features/data/presentation/health_dashboard_screen.dart`

### Current
Static `Container(height: 120, color: cardBackground)`.

### New
`_CardSkeleton` becomes a `StatelessWidget` that renders an animated, layout-aware skeleton. Outer shell matches `MetricTile`'s container exactly (same `cardBackground`, `radiusCard`, 12px padding, light-mode shadow).

**Internal layout:**
```
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(  // header row
      children: [
        ShimmerBox(isCircle: true, height: 8),   // category dot
        SizedBox(width: 6),
        ShimmerBox(height: 8, width: 64),         // metric name
        Spacer(),
        ShimmerBox(height: 14, width: 14),        // emoji icon slot
      ]
    ),
    SizedBox(height: 8),
    ShimmerBox(height: 28, width: 56),            // primary value
    SizedBox(height: 4),
    ShimmerBox(height: 8, width: 36),             // unit label
    SizedBox(height: 8),
    Expanded(child: ShimmerBox(borderRadius: BorderRadius.circular(8))),  // chart area — no height needed (Expanded fills)
  ]
)
```

Wrapped with `AppShimmer`. Height remains `120` (driven by `SizedBox` wrapper or `AspectRatio(1:1)`).

**Accessibility:** `Semantics(label: 'Loading dashboard metrics', excludeSemantics: true)` wrapping the card.

### Cross-fade fix
The `_buildLoadingSlivers()` branch currently exists outside the `AnimatedSwitcher`. The loading check (`tilesAsync.isLoading`) is at the END of the `if/else if/else` chain in `build()`, after the `allNoSource` and `allNoSource + hasNetworkError` guards. Only that final pair needs replacing — the onboarding and network-error branches remain unchanged.

Replace only the final `else if (tilesAsync.isLoading) / else` pair with a single `AnimatedSwitcher`:

```dart
// BEFORE (lines ~435–458):
else if (tilesAsync.isLoading)
  _buildLoadingSlivers()
else
  SliverToBoxAdapter(
    child: AnimatedSwitcher(...)
  ),

// AFTER:
else
  SliverToBoxAdapter(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: tilesAsync.isLoading
          ? _DashboardSkeletonBox(key: const ValueKey('loading'))
          : _TileGridBox(key: ValueKey(activeFilter), ...),
    ),
  ),
```

`_DashboardSkeletonBox` is a new `StatelessWidget` that renders 6 `_CardSkeleton` widgets in a `Column` with the same padding that `_buildLoadingSlivers` applied. It is a box widget (not a sliver) so it can live inside the `AnimatedSwitcher`. The `allNoSource` and `allNoSource + hasNetworkError` sliver branches above this are unaffected.

---

## 4. `SyncingTileContent` (Gap #2)

**File:** `lib/features/data/presentation/widgets/tile_empty_states.dart`

### Current
`StatefulWidget` with `AnimationController` doing a fade pulse over 3 uniform bars + "Syncing..." label.

### New
Replace with an `AppShimmer`-based layout skeleton that matches `MetricTile`'s loaded layout. `SyncingTileContent` becomes a `StatelessWidget` (no own `AnimationController` — `AppShimmer` provides animation).

**Internal layout:**
```
AppShimmer(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(  // header row
        children: [
          ShimmerBox(isCircle: true, height: 8),
          SizedBox(width: 6),
          ShimmerBox(height: 8, width: 80),
          Spacer(),
          ShimmerBox(height: 14, width: 14),
        ]
      ),
      SizedBox(height: 8),
      ShimmerBox(height: 28, width: 60),     // value
      SizedBox(height: 4),
      ShimmerBox(height: 8, width: 40),      // unit
      SizedBox(height: 8),
      Expanded(child: ShimmerBox(borderRadius: BorderRadius.circular(8))),  // chart — Expanded fills
    ]
  )
)
```

Remove "Syncing..." text label — the shimmer animation communicates "loading" clearly enough without it. Remove the `_ShimmerBar` private widget (replaced by `ShimmerBox`).

**Semantics:** Parent `MetricTile` already sets `Semantics(label: '${tileId.displayName}: syncing')` — no additional label needed inside `SyncingTileContent`.

---

## 5. `_SkeletonRow` in `HealthScoreStrip` (Gap #3)

**File:** `lib/features/data/presentation/widgets/health_score_strip.dart`

### Current
Static flat shapes using `shimmerBase` fill color. No animation.

### New
Wrap existing `_SkeletonRow` content in `AppShimmer`. Update child `Container` fill colors from `shimmerBase` to `Colors.white` (required for `ShaderMask` to apply the sweep correctly).

**Accessibility:** `HealthScoreStrip` already sets `Semantics(label: 'Health score. Loading.')` in its `scoreAsync.when` — no change needed.

---

## 6. `MetricDetailScreen` — Loading (Gap #4)

**File:** `lib/features/data/presentation/metric_detail_screen.dart`

### Current
- AppBar `loading:` → `SizedBox.shrink()` — title disappears
- Body `loading:` → `Center(CircularProgressIndicator)`

### New

**AppBar title during load:**
Format `widget.metricId` as a human-readable placeholder immediately:
```dart
// Helper added as a top-level function or extension:
String _formatMetricId(String id) =>
    id.split('_').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

// AppBar title:
detailAsync.when(
  data: (d) => Text(d.series.displayName, style: AppTextStyles.displaySmall),
  loading: () => Text(_formatMetricId(widget.metricId), style: AppTextStyles.displaySmall),
  error: (_, __) => Text(_formatMetricId(widget.metricId), style: AppTextStyles.displaySmall),
)
```

**Body skeleton — `_MetricDetailSkeleton` widget (new):**

> **Import note:** `TimeRange` in `metric_detail_screen.dart` refers to the shared widget enum at `package:zuralog/shared/widgets/time_range_selector.dart` (values: `days7`, `days30`, `days90`, `custom`). This is NOT the dashboard `TimeRange` at `lib/features/data/domain/time_range.dart`. Do not confuse them.

```
AppShimmer(
  child: ListView(padding: ..., children: [
    // Time range selector row — widths are approximate; the real chips are
    // text-width-driven. These shimmer chips just communicate "row of pills".
    Row(children: [
      for each of 4 ranges:
        ShimmerBox(height: 28, width: 52, borderRadius: AppDimens.radiusChip),
        SizedBox(width: 8),
    ]),
    SizedBox(height: AppDimens.spaceMd),
    // Stats row card
    Container(height: 88, borderRadius: 20, child: ShimmerBox(fill)),
    SizedBox(height: AppDimens.spaceMd),
    // Chart card
    Container(height: 220, borderRadius: 20, child: ShimmerBox(fill)),
    SizedBox(height: AppDimens.spaceMd),
    // Source attribution
    Row(children: [ShimmerBox(isCircle, 14), SizedBox(6), ShimmerBox(h:12, w:120)]),
  ])
)
```

**Cross-fade loading → data:**
Wrap `detailAsync.when` body result in `AnimatedSwitcher(duration: 300ms)`, keyed by `detailAsync.isLoading`:
```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: detailAsync.when(
    loading: () => _MetricDetailSkeleton(key: const ValueKey('loading')),
    error: (e, _) => _ErrorBody(key: const ValueKey('error'), onRetry: _retry),
    data: (detail) => _MetricDetailBody(key: const ValueKey('data'), ...),
  ),
)
```

**Semantics:** `_MetricDetailSkeleton` wrapped in `Semantics(label: 'Loading ${_formatMetricId(widget.metricId)} data')`.

---

## 7. `MetricDetailScreen` — Error (Gap #5)

**File:** `lib/features/data/presentation/metric_detail_screen.dart`

### Current
`Center(Column([Icon, Text('Could not load metric')]))` — no recovery path.

### New `_ErrorBody` widget:
```
Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.cloud_off_rounded, size: 48, color: textTertiary),
      SizedBox(height: AppDimens.spaceSm),
      Text('Could not load metric', style: bodyLarge.copyWith(color: textSecondary)),
      SizedBox(height: AppDimens.spaceSm),
      Text('Check your connection and try again',
           style: bodySmall.copyWith(color: textTertiary),
           textAlign: TextAlign.center),
      SizedBox(height: AppDimens.spaceMd),
      OutlinedButton.icon(
        icon: Icon(Icons.refresh_rounded, size: 18),
        label: Text('Try Again'),
        onPressed: onRetry,
      ),
    ],
  )
)
```

`onRetry` calls `ref.invalidate(metricDetailProvider(params))` — `params` is already in scope.

**Semantics:** `Semantics(liveRegion: true)` on the error container so screen readers announce the error.

---

## 8. `MetricDetailScreen` — Empty & Single Data (Gap #6)

**File:** `lib/features/data/presentation/metric_detail_screen.dart`

### Current
Plain centered text. No icon, no CTA.

### New — 0 data points:
```
Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.show_chart_rounded, size: 48, color: textTertiary.withOpacity(0.5)),
      SizedBox(height: AppDimens.spaceSm),
      Text('No data for this period', style: bodyLarge.copyWith(color: textSecondary)),
      SizedBox(height: AppDimens.spaceXs),
      Text('Try a different time range to see your data.',
           style: bodySmall.copyWith(color: textTertiary),
           textAlign: TextAlign.center),
      SizedBox(height: AppDimens.spaceMd),
      OutlinedButton(
        onPressed: () => widget.onRangeChanged(TimeRange.days30),
        child: Text('Try 30 days'),
      ),
    ],
  )
)
```

### New — 1 data point:
```
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(Icons.radio_button_checked_rounded, size: 36, color: textTertiary.withOpacity(0.5)),
    SizedBox(height: AppDimens.spaceXs),
    Text('Only one data point available', style: bodyLarge.copyWith(color: textSecondary)),
    SizedBox(height: AppDimens.spaceXxs),
    Text('Expand the time range to see trends.',
         style: bodySmall.copyWith(color: textTertiary)),
    SizedBox(height: AppDimens.spaceMd),
    OutlinedButton(
      onPressed: () => widget.onRangeChanged(TimeRange.days30),
      child: Text('Try 30 days'),
    ),
  ],
)
```

These replace the inline `if (spots.isEmpty)` and `if (spots.length == 1)` blocks in `_MetricDetailBodyState.build`. Inside a `State`, `widget.onRangeChanged(...)` is the correct access pattern — `widget.` prefix required; do not call `onRangeChanged(...)` directly. `TimeRange.days30` refers to the shared widget enum (see import note in Section 6).

---

## 9. `NoDataForRangeTileContent` — Staleness Treatment (Gap #7)

**File:** `lib/features/data/presentation/widgets/tile_empty_states.dart`

### Current
Value displayed with `textPrimary` color; "Last: Xd ago" in `textTertiary`. Visually identical to loaded state.

### New
Communicate staleness through color and iconography without removing the data:

**Value text:** Use `textSecondary` at `0.65` opacity — still readable but clearly not "live."

**"Last:" row:** Replace plain `Text` with an `ExcludeSemantics`-wrapped `Row`:
```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(Icons.history_rounded, size: 11, color: AppColors.statusConnecting),
    SizedBox(width: 3),
    Text(
      'Last: $relTime',
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.statusConnecting,  // amber — "stale" signal
      ),
    ),
  ],
)
```

`AppColors.statusConnecting = Color(0xFFFF9F0A)` (amber). This matches the existing "connecting/stale" semantic in the design system.

**Updated Semantics** on the tile (in `MetricTile`):
```dart
TileDataState.noDataForRange =>
    '${tileId.displayName}: last known value ${primaryValue ?? '—'}, data may be outdated',
```

> **Test note:** The existing semantic label for `noDataForRange` in `MetricTile` reads `'${tileId.displayName}: no data for selected range'` (line 113). Any tests asserting this string will fail after this change. Update `metric_tile_test.dart` (or equivalent) to expect the new string.

---

## 10. Viz Empty Placeholder (Gap #8)

**Files:**
- `lib/features/data/domain/tile_visualization_config.dart` (add `hasChartData` getter)
- `lib/features/data/presentation/widgets/tile_visualizations.dart` (check before dispatch)

### Step 1: `hasChartData` on `TileVisualizationConfig`
Add a getter to the sealed class (default `true`) and override in chart-type subclasses:

```dart
// In TileVisualizationConfig sealed class:
bool get hasChartData => true;

// In LineChartConfig, BarChartConfig, AreaChartConfig,
//    CalendarGridConfig, HeatmapConfig, DotRowConfig:
@override
bool get hasChartData => points.isNotEmpty;
```

Non-chart configs (`RingConfig`, `GaugeConfig`, `FillGaugeConfig`, `SegmentedBarConfig`, `StatCardConfig`) keep the default `true` since they don't have a list of chart points that could be empty.

**`DualValueConfig` special case:** `DualValueConfig` has optional `List<ChartPoint>? points1` and `points2` fields used for mini sparklines. However, the viz widget renders the paired values (value1/value2) regardless of whether points are provided — it never silently collapses. So `DualValueConfig` also keeps `hasChartData = true`. The chart points being null/empty just means no sparkline is drawn, which is already handled inside `DualValueViz` without returning `SizedBox.shrink()`.

### Step 2: Placeholder in `buildTileVisualization`

```dart
Widget buildTileVisualization({...}) {
  if (!config.hasChartData) return const _VizEmptyPlaceholder();
  return switch (config) { ... };
}
```

### `_VizEmptyPlaceholder` widget:
```dart
class _VizEmptyPlaceholder extends StatelessWidget {
  const _VizEmptyPlaceholder();
  @override
  Widget build(BuildContext context) {
    // Use AppColorsOf(context) — not AppColors directly — so the color adapts
    // to light/dark theme correctly, matching the theming pattern used everywhere else.
    final colors = AppColorsOf(context);
    return Center(
      child: Icon(
        Icons.show_chart_rounded,
        size: 20,
        color: colors.textTertiary.withValues(alpha: 0.35),
      ),
    );
  }
}
```

Subtle, non-intrusive. Prevents silent chart-area collapse while not overwhelming the tile.

### Step 3: Remove redundant guards
In each updated viz widget, remove the `if (config.points.isEmpty) return SizedBox.shrink()` guard — it becomes unreachable.

---

## 11. Non-goals (Out of Scope)

The following were considered and deliberately excluded to keep scope focused:

- **Optimistic UI / showing cached data during refresh** — depends on data layer architecture; out of scope for this pass.
- **All-tiles-hidden edge case** — already handled: `MetricTile` returns `SizedBox.shrink()` for `hidden` state. The grid just shows nothing. This is correct UX (user chose to hide everything).
- **"Connect" button micro-animation on tap** — deferred; the button already gets Material ink splash.
- **Sync pulse stopping when sync completes** — already works correctly via state machine: `syncing → loaded` triggers a widget rebuild, `SyncingTileContent` is disposed.

---

## 12. File Change Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `lib/core/widgets/shimmer.dart` | **New** | `AppShimmer` + `ShimmerBox` shared widgets |
| `lib/features/data/presentation/health_dashboard_screen.dart` | Edit | Upgrade `_CardSkeleton`; add `_DashboardSkeletonBox`; fix cross-fade |
| `lib/features/data/presentation/widgets/health_score_strip.dart` | Edit | Animate `_SkeletonRow` with `AppShimmer` |
| `lib/features/data/presentation/widgets/tile_empty_states.dart` | Edit | Rewrite `SyncingTileContent` with `AppShimmer`; staleness in `NoDataForRangeTileContent` |
| `lib/features/data/presentation/metric_detail_screen.dart` | Edit | Skeleton load state; formatted AppBar title; error retry; empty/single-point CTAs |
| `lib/features/data/domain/tile_visualization_config.dart` | Edit | Add `hasChartData` getter |
| `lib/features/data/presentation/widgets/tile_visualizations.dart` | Edit | Add `_VizEmptyPlaceholder` + check in `buildTileVisualization` |
| `lib/features/data/presentation/widgets/viz/line_chart_viz.dart` | Edit | Remove redundant empty guard |
| `lib/features/data/presentation/widgets/viz/bar_chart_viz.dart` | Edit | Remove redundant empty guard |
| `lib/features/data/presentation/widgets/viz/area_chart_viz.dart` | Edit | Remove redundant empty guard |
| `lib/features/data/presentation/widgets/viz/calendar_grid_viz.dart` | Edit | Remove redundant empty guard |
| `lib/features/data/presentation/widgets/viz/heatmap_viz.dart` | Edit | Remove redundant empty guard |
| `lib/features/data/presentation/widgets/viz/dot_row_viz.dart` | Edit | Remove redundant empty guard |

**No `pubspec.yaml` changes.** No new packages required.

> **Test impact:** Any widget tests asserting the `noDataForRange` semantic label on `MetricTile` must be updated from `'${displayName}: no data for selected range'` to `'${displayName}: last known value …, data may be outdated'`.

---

## 13. Accessibility Summary

| Location | Semantic label |
|----------|---------------|
| `_CardSkeleton` | "Loading dashboard metrics" |
| `_DashboardSkeletonBox` | (contains 6 × above) |
| `SyncingTileContent` | Handled by parent `MetricTile`: "${displayName}: syncing" |
| `_SkeletonRow` | Handled by parent `HealthScoreStrip`: "Health score. Loading." |
| `_MetricDetailSkeleton` | "Loading ${formattedMetricId} data" |
| `_ErrorBody` | `liveRegion: true` on container — screen reader announces on appearance |
| `NoDataForRangeTileContent` | "${displayName}: last known value ${value}, data may be outdated" |
| `_MetricDetailBody` 0-data / 1-data states | Inherit surrounding screen semantics; no additional label needed |
