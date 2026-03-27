# Chart Visualization System — Design Spec

**Date:** 2026-03-28
**Status:** Approved
**Branch:** `feat/data-tab-fl-chart`

---

## 1. Overview

A unified chart visualization system for the Zuralog Flutter app. Every chart — regardless of type or size — shares one animation system, one tooltip system, one empty state, and one interaction model. When a new metric is added, it gets all of this for free by writing a single small renderer.

### Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Fullscreen | Option C — hybrid | Hero chart (same type as tile) + line chart history below. Visual continuity + trend answer. |
| Empty state | Option D — adaptive | Ghost chart on small tiles, message + CTA on larger tiles and fullscreen. |
| Architecture | Option B — unified system | One shared layer for animations, tooltips, empty states, interactions. Consistency at scale. |
| Creative extras | All 6 | Sparkline, widget, comparison overlay, mini progress, entrance animations, scrubbing crosshair. |

---

## 2. Display Modes

Every chart can render in any of these modes. The mode controls layout, touch behavior, and what supplementary UI appears around the chart.

| Mode | Enum value | Dimensions | Touch | Used where |
|------|-----------|------------|-------|------------|
| 1x1 square | `square` | ~160x160px | Tap = navigate | Dashboard grid |
| 2x1 wide | `wide` | ~330x160px | Tap = navigate | Dashboard grid |
| 1x2 tall | `tall` | ~160x330px | Tap = navigate | Dashboard grid |
| Fullscreen hero | `full` | Screen width, ~200px height | Tap segments, scrub crosshair | MetricDetailScreen top |
| Sparkline | `sparkline` | Inline, ~60x16px | None (non-interactive, excluded from 44px rule) | List rows, stat cells, Today tab |
| Home widget | `widget` | ~150x150 or ~300x150 | Tap = open app (including empty state) | iOS/Android home screen |
| Comparison | `comparison` | Screen width, ~200px | Scrub crosshair (line/area only) | Trends tab, date range compare |
| Mini progress | `mini` | 24-32px | None (decorative, no GestureDetector, excluded from 44px rule) | Goal badge on any tile |

### ChartMode enum and TileSize mapping

`ChartMode` is a new enum that replaces `TileSize` for chart rendering. The existing `TileSize { square, wide, tall }` enum in `data_models.dart` continues to exist for grid layout purposes (the masonry algorithm depends on it). A mapping extension bridges the two:

```dart
extension TileSizeToChartMode on TileSize {
  ChartMode toChartMode() => switch (this) {
    TileSize.square => ChartMode.square,
    TileSize.wide   => ChartMode.wide,
    TileSize.tall   => ChartMode.tall,
  };
}
```

`tile_visualizations.dart` uses this extension when delegating to `ZChart`. The new modes (`full`, `sparkline`, `widget`, `comparison`, `mini`) are used directly by their respective consumers — they have no `TileSize` equivalent.

### Unsupported mode/type combinations

Not every chart type supports every mode (e.g., rings have no sparkline). When `ZChart` receives an unsupported combination, it renders `SizedBox.shrink()` and fires a `debugPrint` warning in debug mode plus a `assert(false, 'Unsupported: ...')` so it surfaces during development. See the N/A cells in Section 4 for the full matrix.

### What each mode shows

**square (1x1):** Metric name + value in the tile header (handled by MetricTile). The viz area gets a compact chart with no axes, no labels, no grid. Just the shape of the data. Today dot on line/area charts.

**wide (2x1):** Same tile header. The viz area is wider so charts get bottom axis labels (day abbreviations for bars, none for line/area). Legend row for segmented bar. Value text beside ring.

**tall (1x2):** Same tile header. Chart gets more vertical space. Stats summary row below the chart (MIN / AVG / MAX for line/area, weekly bar row for ring, zone legend for gauge).

**full:** Hero-sized chart with full touch interaction. Time range selector (7D/30D/90D/Custom) above. Stats row (Current / Average / vs Last Week) below. Tooltip on touch. Scrubbing crosshair on line and area charts (single-finger horizontal drag). Tap-to-expand on discrete segments (segmented bar, ring, gauge zones). Bar charts use tap-to-show-tooltip on individual bars (not scrubbing — bars are discrete, not continuous). This is the top section of MetricDetailScreen — the line chart history sits below it (see Section 5).

**sparkline:** Tiny inline chart. No axes, no dots, no labels. Just the trend line or mini bars. Fixed height ~16px, width adapts to container. Used inline with text like "72 bpm [sparkline]".

**widget:** Same data as square but optimized for home screen widget constraints. Larger text, higher contrast, no fine detail. Designed for low-density rendering.

**comparison:** Two overlaid datasets on the same chart — current period (solid line, full opacity) and previous period (dashed line, 40% opacity). Shared Y axis. Scrubbing crosshair shows both values (line/area only). For bar and segmented bar, tap a bar group to see both values in tooltip. Legend at bottom: "This week" / "Last week".

**mini:** A tiny ring (24-32px) or linear progress bar showing goal completion percentage. No text inside — just the arc. Embeddable as a badge on any tile type. Uses category color for the filled portion, 15% opacity for the track.

---

## 3. Architecture

### Layer 1: Chart Configs (existing, no changes)

`TileVisualizationConfig` sealed class hierarchy in `tile_visualization_config.dart`. Pure data — no rendering logic. Already has: `LineChartConfig`, `BarChartConfig`, `AreaChartConfig`, `RingConfig`, `GaugeConfig`, `FillGaugeConfig`, `SegmentedBarConfig`, `DotRowConfig`, `CalendarGridConfig`, `HeatmapConfig`, `StatCardConfig`, `DualValueConfig`.

### Chart types excluded from ZChart

Five config types are **not** part of the unified chart system because they are not traditional charts that benefit from shared animation/tooltip/scrub behavior:

| Config | Why excluded | Handling |
|--------|-------------|----------|
| `DotRowConfig` | Binary dot grid, not a chart — no axes, no trend | Stays as standalone `DotRowViz` widget |
| `CalendarGridConfig` | Month calendar layout, not a data chart | Stays as standalone `CalendarGridViz` widget |
| `HeatmapConfig` | 2D grid visualization, not plottable on axes | Stays as standalone `HeatmapViz` widget |
| `StatCardConfig` | Text display only, no visual chart at all | Stays as standalone `StatCardViz` widget |
| `DualValueConfig` | Paired text values (e.g. blood pressure), not a chart | Stays as standalone `DualValueViz` widget |

`tile_visualizations.dart` continues to dispatch these 5 types to their existing standalone widgets. Only the 7 chart types route through `ZChart`.

### Layer 2: Chart Renderers (new)

Location: `zuralog/lib/shared/widgets/charts/renderers/`

One file per chart type. Each renderer is a pure function or small stateless widget that takes a config + color + render context and returns the fl_chart widget (or CustomPainter for gauge/fill gauge). No size awareness, no touch handling, no empty states, no animations.

| File | Input | Output |
|------|-------|--------|
| `line_renderer.dart` | `LineChartConfig`, `Color`, `ChartRenderContext` | `LineChart` widget |
| `bar_renderer.dart` | `BarChartConfig`, `Color`, `ChartRenderContext` | `BarChart` widget |
| `area_renderer.dart` | `AreaChartConfig`, `Color`, `ChartRenderContext` | `LineChart` widget (with belowBarData) |
| `ring_renderer.dart` | `RingConfig`, `Color`, `ChartRenderContext` | `PieChart` widget |
| `gauge_renderer.dart` | `GaugeConfig`, `Color`, `ChartRenderContext` | `CustomPaint` widget |
| `fill_gauge_renderer.dart` | `FillGaugeConfig`, `Color`, `ChartRenderContext` | Container-based widget |
| `segmented_bar_renderer.dart` | `SegmentedBarConfig`, `Color`, `ChartRenderContext` | Container/Row-based widget |

**fl_chart internal animation:** All renderers set fl_chart's `duration: Duration.zero` on their chart widgets to disable the library's built-in tween. This prevents double-animation when our entrance controller is running. After the entrance completes (`animationProgress == 1.0`), subsequent data updates (time range changes) use fl_chart's native tween by setting `duration` back to 350ms.

`ChartRenderContext` is a small value object:

```dart
class ChartRenderContext {
  final ChartMode mode;              // so renderers can derive mode-specific hints
  final bool showAxes;               // false for sparkline/square, true for full
  final bool showGrid;               // false for tiles, true for full/comparison
  final bool showDots;               // last-dot for tiles, per-point for full when <=14 pts
  final bool showTooltip;            // false for tiles, true for full/comparison
  final bool isCurved;               // false for tiles, true for full
  final bool preventCurveOverShooting; // always true when isCurved is true
  final double strokeWidth;          // 1.0 sparkline, 1.5 tiles, 2.0 widget, 2.5 full
  final int maxBars;                 // bar chart only: 5 for square, null for others
  final bool isComparisonSecondary;  // true when rendering the "previous period" dataset
  final double comparisonOpacity;    // 0.4 for secondary line, 0.3 for secondary bars
  final double? minY;
  final double? maxY;
  final double animationProgress;    // 0.0 to 1.0, driven by entrance animation
}
```

The shell builds the appropriate `ChartRenderContext` from the `ChartMode` — renderers never import `ChartMode` directly. This keeps renderers pure and testable.

### Layer 3: ZChart Unified Widget (new)

Location: `zuralog/lib/shared/widgets/charts/z_chart.dart`

The single entry point for all chart rendering:

```dart
ZChart(
  config: lineChartConfig,        // any TileVisualizationConfig (7 chart types only)
  mode: ChartMode.square,         // the display mode enum
  color: categoryColor,           // category accent color
  onTap: () => navigateToDetail(), // optional tap callback
  comparisonConfig: prevWeekConfig, // optional, for comparison mode
  goalValue: 10000,               // optional, for mini progress mode
)
```

`ZChart.build()` does:
1. Check `config.hasChartData` — if false, delegate to `ZChartEmptyState`
2. Check for single data point — render single-value treatment (see Section 6a)
3. Apply entrance animation (if first build or config instance changed)
4. Build `ChartRenderContext` from mode + animation progress
5. Pick the correct renderer based on config type
6. Wrap in the correct shell based on mode (touch handler, stats row, scrub overlay, etc.)

**Error handling:** `ZChart` does not handle error states. The parent widget (MetricTile, MetricDetailScreen, etc.) is responsible for showing error UI when data fetching fails. `ZChart` only receives valid configs or renders the empty state when `hasChartData` is false.

### Layer 3a: ZChartEmptyState (new)

Location: `zuralog/lib/shared/widgets/charts/z_chart_empty_state.dart`

Universal empty state widget. Adaptive based on mode:

- **square / sparkline / mini / widget:** Ghost chart — faint silhouette of what the chart would look like. Uses the same renderer at 6% opacity with dummy data.
- **wide / tall:** Ghost chart + "No data yet" label.
- **full:** Ghost chart + "No data yet" message + "Connect a source" Sage CTA button.
- **comparison:** Ghost chart + "Not enough data to compare" message + "Try a longer date range" Sage CTA button.

**Relationship to existing empty states:** The existing tile-level empty states in `tile_empty_states.dart` (`GhostTileContent`, `SyncingTileContent`, `NoDataForRangeTileContent`) handle full-tile replacement for non-loaded data states (no source connected, syncing, stale data). These are **not** replaced by `ZChartEmptyState`. They remain as-is because they replace the entire tile, not just the chart area. `ZChartEmptyState` only replaces the chart area inside a loaded tile that happens to have no data points. `OnboardingEmptyState` also remains unchanged — it replaces the entire grid.

### Layer 3b: Chart Interaction Overlays (new)

Location: `zuralog/lib/shared/widgets/charts/interactions/`

| File | Purpose |
|------|---------|
| `scrub_overlay.dart` | Vertical crosshair that follows finger drag on line and area charts. Bar charts use tap-to-tooltip instead (bars are discrete). Used on `full` mode hero charts and `comparison` mode for line/area. |
| `segment_tap_handler.dart` | Tap-to-expand interaction for ring sections, segmented bar segments, gauge zones. Shows detail popup. In comparison side-by-side mode, segment tapping is disabled (touch targets too small at half width). |
| `chart_tooltip.dart` | Refactored from existing `ZChartTooltip`. Uses Surface Raised (`#272729`) background, XS radius. Handles screen-edge overflow. |

### Layer 3c: Entrance Animations (new)

Location: `zuralog/lib/shared/widgets/charts/animations/`

| File | Purpose |
|------|---------|
| `chart_entrance_controller.dart` | Shared animation controller mixin. 350ms `Curves.easeOut` (matching brand bible "major transitions"). Duration.zero when reduced motion. |
| `bar_entrance.dart` | Bars grow from 0 to final height |
| `line_entrance.dart` | Line draws left to right (clip mask reveal) |
| `ring_entrance.dart` | Ring fills clockwise from 0 to value |
| `gauge_entrance.dart` | Needle sweeps from min to current value |
| `fill_gauge_entrance.dart` | Fill level rises from 0 to value |
| `segmented_bar_entrance.dart` | Bar extends from left edge to full width |

Each entrance animation wraps the renderer output and drives a `double` from 0.0 to 1.0. This value is passed to the renderer via `ChartRenderContext.animationProgress`. The renderer scales its output accordingly (e.g., multiply all bar heights by progress, clip line drawing to `progress * width`).

---

## 4. Chart Type Reference

How each of the 7 chart types behaves across all modes.

### Line Chart

| Mode | Behavior |
|------|----------|
| square | Sparkline with last-point dot. No axes. |
| wide | Same as square but wider. |
| tall | Chart + stats row (MIN / AVG / MAX). |
| full | Curved line (`isCurved: true`, `preventCurveOverShooting: true`), gradient fill below (category color at 15% to 0%), axis labels, grid lines, scrubbing crosshair, tooltip on touch. |
| sparkline | Tiny trend line, ~16px tall, no dots. |
| widget | Like square but larger text, higher contrast, 2px stroke. |
| comparison | Two lines overlaid — solid (current) + dashed (previous at 40% opacity). Shared axes. Scrub shows both values. Uses `dashArray` on fl_chart `LineChartBarData`. |
| mini | N/A. |

### Bar Chart

| Mode | Behavior |
|------|----------|
| square | Last 5 bars, no labels. Today bar highlighted. |
| wide | All bars with day labels. Goal line if configured. |
| tall | All bars with labels. Average line if configured. |
| full | All bars, labels, goal line, average line. Tap a bar to see value in tooltip (not scrubbing). Each bar exposed as semantics node for screen readers. |
| sparkline | Tiny bars, ~16px tall, no labels. |
| widget | Like square with larger bars, 2px stroke. |
| comparison | Two bar groups side by side per time period — current (full opacity) + previous (30% opacity). Tap a group to see both values. |
| mini | N/A. |

### Area Chart

| Mode | Behavior |
|------|----------|
| square | Filled area with gradient (15% to 0%). Last-point dot. Delta badge if configured. |
| wide | Same as square, wider. |
| tall | Chart + target line + delta badge. |
| full | Curved, gradient fill (15% to 0%), axis labels, grid, scrubbing crosshair, tooltip. Target line. |
| sparkline | Tiny filled area, ~16px tall. |
| widget | Like square, 2px stroke. |
| comparison | Two overlaid areas — current (full opacity, 15% gradient fill) + previous (dashed line at 40% opacity, 8% gradient fill). |
| mini | N/A. |

### Ring / Donut

| Mode | Behavior |
|------|----------|
| square | Donut with percentage text centered. |
| wide | Donut + value text + "remaining" text beside. |
| tall | Donut + weekly bar row below. |
| full | Large donut. Tap a section to see its label/value. Each section is a semantics node. Animated fill on entrance. |
| sparkline | N/A — rings are not linear. |
| widget | Like square. |
| comparison | Side-by-side layout: two rings at half width. No segment tapping (too small). Labels "This week" / "Last week". |
| mini | Tiny ring (24-32px) showing goal completion. No text inside. |

### Gauge (semicircular arc)

| Mode | Behavior |
|------|----------|
| square | Arc with value number below. |
| wide | Larger arc + value + zone label. |
| tall | Arc + value + zone label + zone legend list. |
| full | Large arc. Tap a zone to see its range. Each zone is a semantics node. Needle sweep entrance animation. |
| sparkline | N/A. |
| widget | Like square. |
| comparison | Side-by-side layout: two gauges at half width. No zone tapping (too small). Labels "This week" / "Last week". |
| mini | N/A. |

### Fill Gauge (vertical tank)

| Mode | Behavior |
|------|----------|
| square | Tank + value text beside. |
| wide | Tank + value + unit icons (e.g. water drops). |
| tall | Larger tank + value + unit icons. |
| full | Large tank. Animated fill rise on entrance. |
| sparkline | N/A. |
| widget | Like square. |
| comparison | Side-by-side layout: two tanks at half width. Labels "This week" / "Last week". |
| mini | Tiny linear progress bar showing fill percentage. |

### Segmented Bar (horizontal stacked)

| Mode | Behavior |
|------|----------|
| square | Total label + bar + top-3 segment legend. |
| wide | Total label + bar + full legend with values. |
| tall | Total label + bar + full legend with values per row. |
| full | Large bar. Tap a segment to see its label + value + percentage. Each segment is a semantics node. |
| sparkline | Tiny stacked bar, ~16px tall, no labels. |
| widget | Like square. |
| comparison | Two stacked bars vertically — top "This week", bottom "Last week". Tap either bar's segment to see value. |
| mini | N/A. |

---

## 5. Fullscreen Detail Screen Layout

When a user taps any tile, they navigate to MetricDetailScreen. The current layout will be reordered to match this spec. Navigation follows platform conventions (swipe-back on iOS, predictive back on Android) since it is a pushed route.

**New layout (top to bottom):**

1. **App bar** — metric display name + back button. Source attribution as subtitle ("from Apple Health").
2. **Time range selector** — 7D / 30D / 90D / Custom pills
3. **Hero chart** — `ZChart(config: ..., mode: ChartMode.full, ...)` — the same chart type as the tile, rendered large with full interactivity. Scrubbing crosshair on line/area, tap-to-tooltip on bars, tap-to-expand on segments.
4. **AI insight card** — if available. Uses feature card treatment (Original.PNG or category-colored variant, 7% opacity, screen blend) per brand bible.
5. **Stats row** — Current (colored) / Average / vs Last Week
6. **"HISTORY" section label**
7. **Line chart history** — always a `ZChart(config: lineChartConfig, mode: ChartMode.full, ...)` showing the raw time series. Uses fl_chart's built-in `FlTransformationConfig(scaleAxis: FlScaleAxis.horizontal, minScale: 1, maxScale: 5)` for pinch-to-zoom and drag-to-pan (not `InteractiveViewer` — which would blur chrome). Scrubbing crosshair also available here since `FlTransformationConfig` does not conflict with `GestureDetector` (single-finger drag = scrub, two-finger pinch = zoom).
8. **Raw data table** — progressive disclosure: shows first 5 rows, "Show all" expands to 30 max.
9. **Ask Coach button** — sticky at bottom of scroll view, always visible.

**Collapse rule:** When the hero chart is already a line chart or area chart, items 6-7 are hidden — the hero itself serves as the interactive time-series view with both scrubbing and zoom/pan.

**Migration note:** The current `MetricDetailScreen` has a different order (stats row before chart, no HISTORY section, source attribution as its own row). Step 3 of the migration (Section 14) must reorder the layout to match this spec.

---

## 6. Empty States

### Adaptive behavior by mode

| Mode | Empty treatment |
|------|----------------|
| square | Ghost chart at 6% opacity. No text. |
| wide | Ghost chart at 6% opacity + "No data yet" label centered. |
| tall | Ghost chart at 6% opacity + "No data yet" label centered. |
| full | Ghost chart at 6% opacity + "No data yet" message + "Connect a source" Sage CTA button. |
| sparkline | Flat horizontal line at 6% opacity. |
| widget | Ghost chart + "Open Zuralog" label. Tap still opens the app. |
| comparison | Ghost chart + "Not enough data to compare" message + "Try a longer range" Sage CTA button. |
| mini | Empty ring track at 15% opacity. |

### 6a. Single data point behavior

When `config` has exactly 1 data point:

| Chart type | Treatment |
|------------|-----------|
| Line / Area | Single centered dot at the data value. No line, no area fill. No scrubbing. |
| Bar | Single bar, centered. No labels. |
| Ring / Gauge / Fill gauge / Segmented bar | Renders normally — these don't depend on point count. |

In fullscreen (Section 5), if there is only 1 data point, the HISTORY section is hidden and a message below the hero chart says "Only one data point — check back after a few days."

### Ghost chart generation

The ghost chart uses the same renderer as the real chart but with:
- Dummy data that creates a plausible-looking shape (not flat, not chaotic)
- 6% opacity applied to the entire output (distinct from grid lines at 4% — see Section 15)
- No dots, no tooltips, no interaction
- `animationProgress` fixed at 1.0 (no entrance animation on ghosts)
- No grid lines rendered on ghost charts
- The ghost data is deterministic per chart type — all empty line charts show the same ghost shape, all empty bar charts show the same ghost bars. Seeded by chart type, not by metric ID.

### 6b. Data density handling

| Data points | Treatment |
|-------------|-----------|
| 0 | Ghost empty state (above) |
| 1 | Single value treatment (6a) |
| 2-14 | Show individual dots on line/area in full mode |
| 15-60 | Normal rendering, no dots |
| 61+ | Downsample to 60 points for sparkline/tile modes. Full mode shows all but uses thinner line (1.5px). |

### 6c. Edge case: negative values and zero range

**Negative values:** Bar charts support negative values — bars grow downward from the zero line. The Y axis auto-scales to include zero when negative values are present. Gauges and fill gauges clamp to their configured min/max — values outside the range pin to the edge.

**All values equal (including all zeros):** The Y axis defaults to `[value - 1.0, value + 1.0]` (or `[0, 1.0]` when value is 0) to avoid a flat line at the edge.

---

## 7. Entrance Animations

Each chart type has a signature entrance that plays once on first appear:

| Chart type | Animation |
|------------|-----------|
| Line | Left-to-right reveal (clip mask slides from left edge to right) |
| Bar | Bars grow upward from zero height |
| Area | Same as line — left-to-right reveal |
| Ring | Arc fills clockwise from 12 o'clock |
| Gauge | Needle sweeps from min position to current value |
| Fill gauge | Fill level rises from bottom |
| Segmented bar | Bar extends from left edge to full width |

**Timing:** 350ms, `Curves.easeOut` (matching brand bible "major transitions"). `Duration.zero` when `MediaQuery.of(context).disableAnimations` is true.

**fl_chart internal animation:** During entrance, renderers set fl_chart's `duration: Duration.zero` to prevent the library's built-in tween from fighting with our entrance controller. After entrance completes (`animationProgress == 1.0`), subsequent data updates use fl_chart's native tween at 350ms for smooth transitions (e.g., time range change).

**When it plays:**
- First build (widget appears on screen)
- Config instance changes (identity check, not deep equality) — replays the animation. Callers must provide a new config object when data updates (e.g., time range switch creates a new config).
- Does NOT replay on scroll-in/scroll-out (no intersection observer triggering)

**Staggering on dashboard:** When the dashboard first loads, tiles animate in with 60ms stagger between each tile (matching brand bible: "each card delays 60ms after the previous one").

---

## 8. Scrubbing Crosshair

Available on `full` and `comparison` modes for **line and area charts only**. Bar charts use tap-to-tooltip instead (bars are discrete, a continuous crosshair would land between bars with no value to show). Segmented bars, rings, gauges, and fill gauges use segment/zone tap interaction (Section 3b).

**Behavior:**
1. User touches the chart area and begins single-finger horizontal drag
2. A vertical line (1px, Sage at 40% opacity, dashed) follows the finger's X position
3. The crosshair **snaps to the nearest data point** by spot index — fl_chart's `showingTooltipIndicators` works with discrete spot indices, not continuous X positions. The vertical line can follow the finger freely, but the dot and tooltip snap to real data points.
4. A dot (radius 4, category color) appears on the data line at the snapped point
5. A tooltip (using `ZChartTooltip`) appears above the dot showing:
   - Date label (e.g., "Mon, Mar 24")
   - Value + unit (e.g., "8,432 steps")
   - In comparison mode: both current and previous values
6. On finger lift, the crosshair and tooltip fade out (150ms)

**Gesture coexistence with zoom/pan:** On the history line chart (Section 5, item 7), fl_chart's `FlTransformationConfig` handles zoom/pan natively. Single-finger horizontal drag = scrub. Two-finger pinch = zoom. These do not conflict because `FlTransformationConfig` only activates on multi-touch.

**Haptics:** Light impact (`HapticFeedback.lightImpact()`) on first touch and when snapping to each new data point.

**Accessibility:** When VoiceOver/TalkBack is active, scrubbing is replaced by exposing each data point as a swipeable semantics node. Left/right flick navigates between points. Each node announces date + value.

**Implementation:** Evaluate fl_chart's built-in `LineTouchData` with custom `getTouchedSpotIndicator` and `touchTooltipData` first — this may provide most scrubbing behavior for free. Fall back to manual `GestureDetector` overlay only if the built-in approach doesn't support the crosshair line or snap-to-point behavior needed.

---

## 9. Comparison Overlay Mode

Used in the Trends tab and when comparing date ranges. The comparison dataset is provided by the caller — the chart system does not fetch data. That responsibility belongs to the Trends tab provider, which is outside this spec's scope.

**Visual treatment for time-series charts (line, area, bar, segmented bar):**
- Current period: solid line/bars, full category color
- Previous period: dashed line (using fl_chart `dashArray`) at 40% opacity / bars at 30% opacity
- Shared Y axis scaled to fit both datasets
- Legend row at bottom: filled dot "This week" / hollow dot "Last week" (or the actual date ranges)
- Legend row has semantic labels for screen readers: "This week: [summary]" / "Last week: [summary]"

**Visual treatment for non-time-series charts (ring, gauge, fill gauge):**
- Side-by-side layout: the `comparison_chart_shell` renders two `ZChart` instances internally, each at half width in `ChartMode.full`. Left is labeled "This week", right is labeled "Last week".
- Segment-tap interaction is disabled in side-by-side mode (touch targets at half width would be below 44px minimum). Users see the visual comparison but tap the whole chart to navigate to the full detail view if they want segment details.

**Data requirement:** Two `TileVisualizationConfig` instances of the same type. The `ZChart` widget receives the primary config and a `comparisonConfig`.

---

## 10. Mini Progress Indicator

A tiny goal-completion badge that can be embedded on any tile. Purely decorative — no `GestureDetector`, no `Semantics` tap action. Excluded from 44px touch target requirement.

**Ring variant (default):** 24-32px circle. Category color for filled arc, 15% opacity for track. No text inside. Starts from 12 o'clock, fills clockwise.

**Linear variant:** 4px tall progress bar, full width of its container. Same color treatment. Rounded caps.

**Usage:** Shown as an overlay badge on the tile when the metric has a configured goal. Positioned top-right of the tile, offset by 8px.

**Semantics:** Wrapped in `Semantics(label: '78% of goal')` for screen readers but with no tap action.

**API:**
```dart
ZMiniProgress(
  value: 6240,
  goal: 10000,
  color: categoryColor,
  variant: MiniProgressVariant.ring, // or .linear
  size: 28,
)
```

---

## 11. Sparkline Mode

An inline chart with zero chrome — no axes, no labels, no dots, no grid. Just the shape of the data. Non-interactive — no `GestureDetector`, excluded from 44px touch target requirement.

**Dimensions:** Height fixed at 16px. Width adapts to container (typically 40-80px). For 61+ data points, downsample to 30 points (roughly one per 2px at 60px width).

**Supported chart types:**
- Line -> thin trend line (1px stroke)
- Bar -> tiny bars (2px wide, 1px gap)
- Area -> filled micro-area
- Segmented bar -> tiny horizontal stacked bar

Ring, gauge, and fill gauge don't have sparkline representations. `ZChart` renders `SizedBox.shrink()` and fires a debug warning for unsupported combinations.

**Usage example:**
```dart
Row(
  children: [
    Text('72 bpm'),
    SizedBox(width: 8),
    SizedBox(
      width: 60,
      height: 16,
      child: ZChart(
        config: heartRateConfig,
        mode: ChartMode.sparkline,
        color: AppColors.categoryHeart,
      ),
    ),
  ],
)
```

---

## 12. Home Screen Widget Mode

Optimized for iOS WidgetKit and Android App Widgets. Same data as the dashboard tiles but designed for:
- Lower pixel density
- Larger minimum text sizes (accessibility)
- Higher contrast (works on various wallpapers)
- Two widget sizes: small (~150x150) and medium (~300x150)

**Differences from tile mode:**
- Text is 20% larger minimum
- Line stroke width is 2px (vs 1.5px on tiles)
- No fine detail (no reference lines, no dashed lines)
- Background: semi-transparent dark surface (to work on any wallpaper)

This mode is designed now but implemented when the widget feature ships. The `ChartMode.widget` enum value and `ChartRenderContext` support exist from day one so the visual language is established early. `widget_chart_shell.dart` is a stub that renders the square mode as a fallback until the widget feature is built.

---

## 13. File Structure

```
zuralog/lib/shared/widgets/charts/
  z_chart.dart                          # Unified entry point widget
  z_chart_empty_state.dart              # Universal empty state
  chart_mode.dart                       # ChartMode enum + TileSize mapping
  chart_render_context.dart             # Render context value object
  renderers/
    line_renderer.dart
    bar_renderer.dart
    area_renderer.dart
    ring_renderer.dart
    gauge_renderer.dart
    fill_gauge_renderer.dart
    segmented_bar_renderer.dart
  interactions/
    scrub_overlay.dart
    segment_tap_handler.dart
    chart_tooltip.dart                  # Refactored from ZChartTooltip
  animations/
    chart_entrance_controller.dart      # Shared mixin
    bar_entrance.dart
    line_entrance.dart
    ring_entrance.dart
    gauge_entrance.dart
    fill_gauge_entrance.dart
    segmented_bar_entrance.dart
  modes/
    tile_chart_shell.dart               # Shell for square/wide/tall
    fullscreen_chart_shell.dart         # Shell for full mode
    sparkline_shell.dart                # Shell for sparkline mode
    widget_chart_shell.dart             # Stub — delegates to square until widget feature ships
    comparison_chart_shell.dart         # Shell for comparison mode
    mini_progress.dart                  # ZMiniProgress widget
```

---

## 14. Migration Path

The existing viz widgets in `features/data/presentation/widgets/viz/` will be replaced incrementally:

1. Build the new `charts/` system alongside the old `viz/` files
2. Update `tile_visualizations.dart` dispatcher: route the 7 chart config types through `ZChart` using `tileSize.toChartMode()`. Continue routing `DotRowConfig`, `CalendarGridConfig`, `HeatmapConfig`, `StatCardConfig`, and `DualValueConfig` to their existing standalone viz widgets.
3. Update `MetricDetailScreen` to use `ZChart(mode: ChartMode.full)` for the hero chart. Reorder the screen layout to match Section 5 (hero chart before stats row, AI insight above stats, add HISTORY section with collapse rule, move source to app bar subtitle, make raw table progressive disclosure, sticky Ask Coach). Use `FlTransformationConfig` instead of `InteractiveViewer` for zoom/pan.
4. Delete old viz files (line, bar, area, ring, gauge, fill gauge, segmented bar) once all consumers are migrated. Keep dot_row, calendar_grid, heatmap, stat_card, dual_value as-is.
5. Update component showcase to demonstrate all modes (square, wide, tall, full, sparkline, comparison, mini, empty) for each chart type.
6. Migrate existing tooltip from Surface (`#1E1E20`) to Surface Raised (`#272729`) per brand bible.

The old viz files are already on fl_chart (from the earlier migration in this branch), so the renderers can reuse most of that code — they just extract the fl_chart building logic out of the size-switching wrapper.

---

## 15. Design Tokens for Charts

All charts use these brand bible tokens:

| Token | Value | Usage |
|-------|-------|-------|
| Grid lines | `AppColors.warmWhite` at 4% opacity | Horizontal grid on full/comparison (lower than ghost 6% for visual distinction) |
| Axis labels | `AppColorsOf(context).textSecondary`, `AppTextStyles.labelSmall` | Left Y-axis, bottom X-axis |
| Data color | Category color passed as `color` param | Lines, bars, fills, arcs |
| Touch highlight | `AppColors.primary` (Sage #CFE1B9) | Scrub crosshair, selected segment |
| Gradient fill | Category color at 15% to 0% opacity | Area below line/area charts (full and tiles) |
| Tooltip | `ZChartTooltip` (Surface Raised `#272729` bg, XS radius 8px) | Touch feedback |
| Animation | 350ms, `Curves.easeOut` | All entrance animations (brand bible "major transitions") |
| Reduced motion | `Duration.zero` when `disableAnimations` | Instant render |
| Stagger | 60ms between tiles | Dashboard entrance cascade |
| Stroke: sparkline | 1.0px | Sparkline mode |
| Stroke: tile | 1.5px | Square, wide, tall modes |
| Stroke: widget | 2.0px | Home screen widget mode |
| Stroke: full | 2.5px | Fullscreen hero and history |

---

## 16. Accessibility

- Every `ZChart` instance wrapped in `Semantics` with descriptive label (chart type + data summary)
- Ghost empty states are `ExcludeSemantics` (decorative)
- Scrubbing crosshair announces value changes via `SemanticsService.announce`
- When VoiceOver/TalkBack is active, scrubbing is replaced by per-point swipeable semantics nodes (left/right flick navigates data points, each announces date + value)
- All interactive areas meet 44px minimum touch target. Mini progress and sparkline are non-interactive and excluded from this rule.
- Entrance animations respect `MediaQuery.disableAnimations`
- Comparison mode legend uses distinct styling (solid vs dashed) not just color, plus semantic labels on each series ("This week: [value]" / "Last week: [value]")
- In full mode, all segmented chart types (bar, ring, gauge zones, segmented bar) expose each segment/bar as a semantics node with label and value for screen reader navigation
- `ZMiniProgress` has `Semantics(label: 'X% of goal')` but no tap action
