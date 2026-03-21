# Data Tab — Reusable Visualization System

**Date:** 2026-03-21
**Status:** Draft
**Supersedes:** `2026-03-20-data-tab-redesign-design.md` (extends and overrides Section 4 Tile Inventory and Section 9 Visual Design)
**Scope:** `lib/features/data/presentation/widgets/tile_visualizations.dart`, `tile_grid.dart`, `metric_tile.dart`, `health_bridge.dart`, iOS `HealthKitBridge.swift`, Android `HealthConnectBridge.kt`, `health_sync_service.dart`

---

## 1. Problem Statement

The current tile system has four compounding problems:

1. **Bespoke visualizations per metric.** Each of the 20 `TileId` values has a hand-crafted visualization widget. Adding a new metric requires writing a new widget and wiring it through the entire stack. This does not scale to the 250+ data points available across Apple Health and Google Health Connect.

2. **Label bug.** `MetricTile` renders `tileId.category.displayName` ("Activity") as the card header instead of `tileId.displayName` ("Steps"). The result is three cards all labelled "Activity" and two all labelled "Sleep".

3. **Grid gap bug.** When a wide (2×1) tile follows an odd number of square tiles, the preceding band in `SliverMasonryGrid` leaves one column empty. This violates the design requirement that all cells are always filled.

4. **Data pipeline gaps.** Eight of 20 `TileId` values have no health data source wired end-to-end. Three others (blood pressure, SpO2, body fat) have broken or incomplete sync paths. Sleep stage breakdown data exists in the native bridge response but is never parsed.

---

## 2. Goals

1. **12 reusable visualization types** cover every current and future Apple Health / Google Health Connect metric with no new widget code per metric.
2. **Every metric maps to a viz type + size behavior via config**, not code.
3. **Card anatomy (Option C):** metric name prominent as the label, category as a small colored pill, icon top-right, value as the hero below.
4. **Gap fix (Option A):** wide tiles are deferred until both columns above them are filled — no empty cells ever.
5. **Label fix:** card header shows `tileId.displayName` ("Steps"), not `tileId.category.displayName` ("Activity").
6. **Data pipeline completeness:** all 12 new data types added to the native bridges and sync service.

---

## 3. Card Anatomy — Option C

Every tile, regardless of visualization type or size, follows this header structure:

```
┌──────────────────────────────────┐
│ METRIC NAME     [category pill] 🏃│  ← Row 1: metric name (10px, 700, UPPERCASE)
│              ● Activity           │    category pill (8px, colored), icon top-right
│                                  │
│ 8,432                            │  ← Value (hero text, 20–34px, 800 weight)
│ steps today                      │  ← Sub-label (10px, muted)
│                                  │
│ [visualization fills remaining]  │
│                                  │
│ Avg 7.9k   Best 11.2k   ↑ 12%   │  ← Stats footer (9px) — tall/wide only
└──────────────────────────────────┘
```

**Implementation scope:** This is a full header restructure of `MetricTile`, not a one-line fix. The existing `_CategoryHeader` widget and `_buildTileContent` layout must be replaced with the Option C structure:

1. **Row 1 (top):** `Row` with `Column(crossAxisAlignment: start)` on the left containing `Text(tileId.displayName)` (10px, 700, UPPERCASE letter-spacing) and the category pill below it, plus the metric icon (`Text(tileId.icon)`) on the right.
2. **Category pill:** `Container` with `AppColors.categoryColor(tileId.category)` at 10% opacity background and 100% color text, border-radius 99px, 2px/6px padding. Text: "● {category.displayName}" at 8px, 700 weight.
3. **Value area:** `Text(primaryValue)` at 20–34px depending on tile size (20px square, 28px tall, 34px wide), weight 800, letter-spacing −0.03em.
4. **Sub-label:** `Text(unit)` at 10px, muted color.
5. **Visualization slot:** unchanged — `visualization` widget inserted below sub-label.
6. **Stats footer:** unchanged — only rendered on tall/wide tiles.

The old `_CategoryHeader(categoryName: tileId.category.displayName, ...)` call is removed entirely. `_CategoryHeader` can be deleted if no other widget uses it.

**Category pill color** comes from the existing `AppColors.category*` tokens. Pill background is the category color at 10% opacity; text is the category color at 100%.

---

## 4. Grid Gap Fix — Option A: Bump Wide Tile Down

**Rule:** When `_buildBands()` encounters a wide tile and the current pending list has an odd number of non-wide tiles, it pulls the next non-wide tile from the remaining list to pair with the orphan before emitting the wide band.

```
Before (broken):          After (fixed):
[A] [B]                   [A] [B]
[C] [   gap   ]           [C] [D]   ← D was after the wide tile; pulled up
[WIDE ━━━━━━━━]           [WIDE ━━━━━━━━]
[D] [E]                   [E] [F]
```

If no subsequent non-wide tile exists to pull up, a transparent spacer cell is inserted instead (the only acceptable use of a placeholder).

**File:** `tile_grid.dart` — `_buildBands()` method.

---

## 5. The 12 Reusable Visualization Types

Each type is a stateless widget with three named constructors or a `size` parameter that switches its internal layout. Every type receives a `TileVisualizationConfig` (data + color + size) and renders appropriately.

### 5.1 LineChart

**Shape:** Single line (or dual line for paired metrics) over a time range. Optional shaded range band between min/max. Optional dashed reference/target line.

**Size behavior:**
- **1×1:** Compact sparkline, no axes, today dot only. 36px height.
- **2×1:** Full 7-day line with today dot, range band, left value panel.
- **1×2:** Tall chart (120px+), x-axis day labels, min/avg/max stats footer.

**Metrics:** Resting HR, HRV, VO2 Max trend, Weight trend, Body Fat trend, SpO2, Blood Pressure (systolic + diastolic as dual lines), Respiratory Rate, Body Temperature, Wrist Temperature, Walking Speed, Running Pace, Cycling Power, Blood Glucose trend.

**Config fields:** `points: List<ChartPoint>`, `referenceLine: double?`, `rangeMin: double?`, `rangeMax: double?`, `positiveIsUp: bool` (for delta coloring).

---

### 5.2 BarChart

**Shape:** Vertical bars, one per time period. Bar opacity fades from today (100%) to oldest (25%). Optional horizontal goal/average dashed line.

**Size behavior:**
- **1×1:** 5 bars, no labels, compact.
- **2×1:** 7 bars, day-of-week labels below, goal line if available, value panel left.
- **1×2:** 7 bars using full height, day labels, stats footer (avg, best, delta).

**Metrics:** Steps, Active Calories, Distance, Floors Climbed, Sleep Duration, Workouts per week, Water intake daily, Mindful Minutes, Headphone Exposure, Nutrition Calories (daily), Exercise Minutes.

**Config fields:** `bars: List<BarPoint>`, `goalValue: double?`, `showAvgLine: bool`.

---

### 5.3 AreaChart

**Shape:** Line chart with gradient fill beneath the line. Supports a dashed target/goal horizontal line.

**Size behavior:** Same as LineChart but with fill. Preferred for metrics with a long-term goal direction (losing weight, building fitness).

**Metrics:** Weight (with target dashed line), Nutrition Calorie intake vs. goal over 30 days, any cumulative trend.

**Config fields:** Same as `LineChart` plus `fillOpacity: double` (default 0.15).

---

### 5.4 Ring

**Shape:** Circular progress arc. Center shows the current value. Optional secondary text (unit, percentage, goal).

**Size behavior:**
- **1×1:** Medium ring (80px) centered, value inside.
- **2×1:** Smaller ring left (90px), stats panel right (current, goal, remaining).
- **1×2:** Large ring (110px) + weekly bar chart below showing trend.

**Metrics:** Steps (% of goal), Active Calories (% of goal), Sleep Duration (% of 8h goal), Water (% of daily goal), Exercise Minutes (% of goal), Stand Hours.

**Config fields:** `value: double`, `maxValue: double`, `unit: String`, `showWeeklyBars: bool`.

---

### 5.5 Gauge

**Shape:** Semicircular arc (180°). A needle or filled arc shows the current value's position on a scale. Below the arc: a fitness-level label or zone name.

**Size behavior:**
- **1×1:** Mini arc (80px wide), value below, single label.
- **2×1:** Wide arc (130px) + value + scale legend (zone labels along the arc base).
- **1×2:** Large arc (140px) + value + zone table below (e.g., Poor / Fair / Good / Excellent / Superior rows with ranges).

**Metrics:** VO2 Max, Body Fat % (with healthy range zones), HRV vs. personal baseline, Stress Level, Recovery Score / Readiness, Mobility %, UV Index, Blood Glucose (with low/normal/high zones).

**Config fields:** `value: double`, `minValue: double`, `maxValue: double`, `zones: List<GaugeZone>` (each zone has `min`, `max`, `label`, `color`).

---

### 5.6 SegmentedBar

**Shape:** Single horizontal bar divided into colored segments. Each segment represents a component of the total. Legend below (or right on wide tiles).

**Size behavior:**
- **1×1:** Compact bar (10px height) + 3 colored dot legend.
- **2×1:** Thicker bar (16px) + duration labels above each segment + full legend row.
- **1×2:** Bar + per-segment rows below (icon, label, duration, individual progress bar).

**Metrics:** Sleep Stages (Deep / REM / Light / Awake), Macros (Protein / Carbs / Fat), Heart Rate Zones, Activity intensity breakdown (light / moderate / vigorous).

**Config fields:** `segments: List<Segment>` (each has `label`, `value`, `color`, `icon`), `totalLabel: String`.

---

### 5.7 FillGauge

**Shape:** Vertical container (bottle/tank style) that fills from bottom to top. Fill level = value / maxValue. Optionally overlaid with a numeric value.

**Size behavior:**
- **1×1:** Narrow gauge (26×54px) + value to the right.
- **2×1:** Gauge + value + unit icons (glasses) showing discrete intake count.
- **1×2:** Taller gauge (34×90px) + value + 2×4 icon grid (filled/empty).

**Metrics:** Water intake, any "fill the tank" daily goal.

**Config fields:** `value: double`, `maxValue: double`, `unit: String`, `unitIcon: String?`, `unitSize: double?` (e.g. 0.3L per glass).

---

### 5.8 DotRow

**Shape:** Row of N dots (default 7, one per day). Dot size or opacity encodes the day's value. Today's dot is slightly larger with a glow ring. Qualitative label above or large emoji.

**Size behavior:**
- **1×1:** 7 dots, today label above.
- **2×1:** 7 dots with emoji per dot, weekly note below.
- **1×2:** 7 dots + day labels below + per-day list (emoji, label, date) filling remaining height.

**Metrics:** Mood, Energy, Stress, Sleep quality rating, Workout streak, Period symptoms, any subjective daily log.

**Config fields:** `points: List<DotPoint>` (each has `value: double 0–1`, `label: String?`, `emoji: String?`), `invertedScale: bool` (for Stress — lower is better).

---

### 5.9 CalendarGrid

**Shape:** N×7 dot grid (default 4 rows = 28 days). Each cell is a colored circle. Today is outlined with a glow ring. Phase coloring for cycle metrics.

**Size behavior:**
- **1×1:** Day number + phase label only (no full grid — too small).
- **2×1:** Horizontal 28-dot strip (1 row), today circled with glow.
- **1×2:** Full 4×7 grid with day numbers inside each dot.

**Metrics:** Menstrual Cycle, Workout consistency calendar, Sleep quality calendar, any binary or phase-based daily metric.

**Config fields:** `days: List<CalendarDay>` (each has `dayNumber`, `value: double 0–1`, `phase: String?`, `phaseColor: Color?`), `totalDays: int` (28 for cycle, 30/31 for month).

---

### 5.10 Heatmap

**Shape:** Calendar grid where cell color intensity (opacity or hue shift) encodes the magnitude of the day's value. No numbers inside cells. A legend strip at the bottom shows the color scale.

**Size behavior:**
- **1×1:** Not supported. If a metric using `HeatmapConfig` is user-resized to 1×1 (or its `defaultSize` is square), the tile renders a `StatCardViz` fallback showing the most recent single value. `allowedSizes` for any metric assigned `HeatmapConfig` must exclude `TileSize.square` in `tile_models.dart` to prevent the user from resizing to 1×1 via the edit mode UI. In debug builds, an assertion fires if `HeatmapConfig` is passed with `size == TileSize.square`.
- **2×1:** 5-week × 7-day grid (35 cells), compact cells, color legend right.
- **1×2:** Same grid with slightly larger cells + color legend at bottom.

**Metrics:** Monthly step count density, Sleep quality over 30 days, HRV pattern, Glucose time-in-range calendar, any metric where relative pattern matters more than exact value.

**Config fields:** `cells: List<HeatmapCell>` (each has `date`, `value: double`), `colorLow: Color`, `colorHigh: Color`, `legendLabel: String`.

---

### 5.11 StatCard

**Shape:** Large numeric value + unit + status indicator (colored dot + label). Optional secondary value or trend note. No chart. Used when there isn't enough history to chart or the point-in-time value is what matters.

**Size behavior:**
- **1×1:** Value + unit + status dot + label.
- **2×1:** Value large on left + secondary stats panel right (last reading, 7d avg, trend).
- **1×2:** Value + status + contextual note + 7-day summary list.

**Metrics:** Respiratory Rate, Body Temperature, Wrist Temperature, Basal Energy Burned, any single scalar without meaningful trend data yet.

**Config fields:** `value: String`, `unit: String`, `statusColor: Color?`, `statusLabel: String?`, `secondaryValue: String?`, `trendNote: String?`.

---

### 5.12 DualValue

**Shape:** Two large numbers displayed together, optionally separated by a "/" divider. Each value can have its own trend sparkline below it (on larger sizes).

**Size behavior:**
- **1×1:** Large "120 / 76" + unit + status dot.
- **2×1:** Values left + two mini sparklines right (one per value, e.g. systolic + diastolic over 7 days).
- **1×2:** Both values large + both sparklines stacked vertically using full height.

**Metrics:** Blood Pressure (systolic / diastolic), BMI + Weight, any paired metric.

**Config fields:** `value1: String`, `label1: String`, `value2: String`, `label2: String`, `points1: List<ChartPoint>?`, `points2: List<ChartPoint>?`.

---

## 6. Metric → Visualization Mapping (Complete)

This is the authoritative config table. Any new metric is added here without touching widget code.

### Activity

| Metric | TileId | Default Size | Viz Type | Ring goal? | Notes |
|---|---|---|---|---|---|
| Steps | `steps` | tall (1×2) | `BarChart` + `Ring` overlay | Yes (10k default) | Ring if goal set; bar if not |
| Active Calories | `activeCalories` | square (1×1) | `Ring` | Yes (user goal) | |
| Workouts | `workouts` | square (1×1) | `StatCard` + count list | No | Large count + recent list |
| Distance | `distance` | square (1×1) | `BarChart` | No | New tile |
| Floors Climbed | `floorsClimbed` | square (1×1) | `BarChart` | No | New tile |
| Exercise Minutes | `exerciseMinutes` | square (1×1) | `Ring` | Yes (30 min default) | New tile |
| Walking Speed | `walkingSpeed` | square (1×1) | `LineChart` | No | New tile; Apple Health only |
| Running Pace | `runningPace` | square (1×1) | `LineChart` | No | New tile; from workouts |

### Sleep

| Metric | TileId | Default Size | Viz Type | Notes |
|---|---|---|---|---|
| Sleep Duration | `sleepDuration` | square (1×1) | `BarChart` + `Ring` | Ring if goal set |
| Sleep Stages | `sleepStages` | wide (2×1) | `SegmentedBar` | Requires native stage parsing fix |

### Heart

| Metric | TileId | Default Size | Viz Type | Notes |
|---|---|---|---|---|
| Resting HR | `restingHeartRate` | square (1×1) | `LineChart` | |
| HRV | `hrv` | square (1×1) | `LineChart` + `Gauge` | Gauge shows vs. personal baseline |
| VO2 Max | `vo2Max` | square (1×1) | `Gauge` | Zones: Poor/Fair/Good/Excellent/Superior |
| Respiratory Rate | `respiratoryRate` | square (1×1) | `StatCard` | New tile; collected, not yet surfaced |

### Body

| Metric | TileId | Default Size | Viz Type | Notes |
|---|---|---|---|---|
| Weight | `weight` | wide (2×1) | `AreaChart` | With dashed target line |
| Body Fat % | `bodyFat` | square (1×1) | `Gauge` | Zones: Essential/Fitness/Average/Obese |
| Body Temperature | `bodyTemperature` | square (1×1) | `LineChart` | New tile; Apple Health + Withings |
| Wrist Temperature | `wristTemperature` | square (1×1) | `LineChart` | New tile; Apple Watch Series 8+ only |

### Vitals

| Metric | TileId | Default Size | Viz Type | Notes |
|---|---|---|---|---|
| Blood Pressure | `bloodPressure` | square (1×1) | `DualValue` | Requires sync pipeline fix |
| SpO2 | `spo2` | square (1×1) | `LineChart` | With 95% reference line |
| Blood Glucose | `bloodGlucose` | square (1×1) | `LineChart` + `Gauge` | New tile; CGM-ready |

### Nutrition

| Metric | TileId | Default Size | Viz Type | Notes |
|---|---|---|---|---|
| Calories | `calories` | square (1×1) | `Ring` + `SegmentedBar` | Ring for total; segmented for macros on tall/wide |
| Water | `water` | square (1×1) | `FillGauge` | Requires `dietaryWater` / `HydrationRecord` to be added to bridge |
| Macros | `macros` | square (1×1) | `SegmentedBar` | New tile; Protein/Carbs/Fat |

### Wellness

| Metric | TileId | Default Size | Viz Type | Notes |
|---|---|---|---|---|
| Mood | `mood` | square (1×1) | `DotRow` | Manual log |
| Energy | `energy` | square (1×1) | `DotRow` | Manual log |
| Stress | `stress` | square (1×1) | `DotRow` | `invertedScale: true` |
| Mindful Minutes | `mindfulMinutes` | square (1×1) | `BarChart` | New tile; HKCategoryType(.mindfulSession) |

### Other

| Metric | TileId | Default Size | Viz Type | Notes |
|---|---|---|---|---|
| Cycle | `cycle` | wide (2×1) | `CalendarGrid` | Requires menstrual data types added to bridge. `allowedSizes`: wide, tall. Square is explicitly excluded — at 1×1 the CalendarGrid degrades to a StatCard fallback (day number + phase label only), which is not useful as the primary layout. Default is wide so the 28-dot strip is visible without user resizing. |
| Environment | `environment` | square (1×1) | `Gauge` + `StatCard` | AQI gauge + UV stat; external API |
| Mobility | `mobility` | square (1×1) | `Gauge` | walkingAsymmetryPercentage or sixMinuteWalkTest |

---

## 7. TileVisualizationConfig — Unified Data Model

All 12 viz types share a single sealed class hierarchy replacing the existing 14 `TileVisualizationData` subtypes:

```dart
sealed class TileVisualizationConfig {
  const TileVisualizationConfig();
}

class LineChartConfig extends TileVisualizationConfig {
  final List<ChartPoint> points;
  final double? referenceLine;
  final double? rangeMin;
  final double? rangeMax;
  final bool positiveIsUp;
  final List<ChartPoint>? secondaryPoints; // for DualValue embedded sparklines
  const LineChartConfig({...});
}

class BarChartConfig extends TileVisualizationConfig {
  final List<BarPoint> bars;
  final double? goalValue;
  final bool showAvgLine;
  const BarChartConfig({...});
}

class AreaChartConfig extends TileVisualizationConfig {
  final List<ChartPoint> points;
  final double? targetLine;
  final double fillOpacity;
  final double? delta;        // percentage change for delta badge (e.g. -0.03 = ↓ 3%)
  final bool positiveIsUp;    // controls delta badge color semantics
  const AreaChartConfig({...});
}

class RingConfig extends TileVisualizationConfig {
  final double value;
  final double maxValue;
  final String unit;
  // weeklyBars non-null enables the 7-day bar chart below the ring on 1×2 tiles.
  // showWeeklyBars is NOT a separate flag — null weeklyBars means no bars rendered.
  final List<BarPoint>? weeklyBars;
  const RingConfig({...});
}

class GaugeConfig extends TileVisualizationConfig {
  final double value;
  final double minValue;
  final double maxValue;
  final List<GaugeZone> zones;
  const GaugeConfig({...});
}

class SegmentedBarConfig extends TileVisualizationConfig {
  final List<Segment> segments;
  final String totalLabel;
  const SegmentedBarConfig({...});
}

class FillGaugeConfig extends TileVisualizationConfig {
  final double value;
  final double maxValue;
  final String unit;
  final String? unitIcon;
  final double? unitSize;
  const FillGaugeConfig({...});
}

class DotRowConfig extends TileVisualizationConfig {
  final List<DotPoint> points;
  final bool invertedScale;
  const DotRowConfig({...});
}

class CalendarGridConfig extends TileVisualizationConfig {
  final List<CalendarDay> days;
  final int totalDays;
  const CalendarGridConfig({...});
}

class HeatmapConfig extends TileVisualizationConfig {
  final List<HeatmapCell> cells;
  final Color colorLow;
  final Color colorHigh;
  final String legendLabel;
  const HeatmapConfig({...});
}

class StatCardConfig extends TileVisualizationConfig {
  final String value;
  final String unit;
  final Color? statusColor;
  final String? statusLabel;
  final String? secondaryValue;
  final String? trendNote;
  const StatCardConfig({...});
}

class DualValueConfig extends TileVisualizationConfig {
  final String value1;
  final String label1;
  final String value2;
  final String label2;
  final List<ChartPoint>? points1;
  final List<ChartPoint>? points2;
  const DualValueConfig({...});
}
```

**Supporting models:**

```dart
class ChartPoint { final DateTime date; final double value; }
class BarPoint    { final String label; final double value; final bool isToday; }
class GaugeZone   { final double min; final double max; final String label; final Color color; }
class Segment     { final String label; final double value; final Color color; final String? icon; }
class DotPoint    { final double value; final String? label; final String? emoji; }
class CalendarDay { final int dayNumber; final double value; final String? phase; final Color? phaseColor; }
class HeatmapCell { final DateTime date; final double value; }
```

---

## 8. `buildTileVisualization()` — Updated Factory

The existing `buildTileVisualization({required TileVisualizationData data, required Color categoryColor})` is replaced by:

```dart
Widget buildTileVisualization({
  required TileVisualizationConfig config,
  required Color categoryColor,
  required TileSize size,
})
```

The function switches on `config` type and `size` to return the correct variant:

```dart
return switch (config) {
  LineChartConfig()    => LineChartViz(config: config, color: categoryColor, size: size),
  BarChartConfig()     => BarChartViz(config: config, color: categoryColor, size: size),
  AreaChartConfig()    => AreaChartViz(config: config, color: categoryColor, size: size),
  RingConfig()         => RingViz(config: config, color: categoryColor, size: size),
  GaugeConfig()        => GaugeViz(config: config, color: categoryColor, size: size),
  SegmentedBarConfig() => SegmentedBarViz(config: config, color: categoryColor, size: size),
  FillGaugeConfig()    => FillGaugeViz(config: config, color: categoryColor, size: size),
  DotRowConfig()       => DotRowViz(config: config, color: categoryColor, size: size),
  CalendarGridConfig() => CalendarGridViz(config: config, color: categoryColor, size: size),
  HeatmapConfig()      => HeatmapViz(config: config, color: categoryColor, size: size),
  StatCardConfig()     => StatCardViz(config: config, color: categoryColor, size: size),
  DualValueConfig()    => DualValueViz(config: config, color: categoryColor, size: size),
};
```

---

## 9. Data Pipeline Fixes

### 9.1 Blood Pressure Sync Bug (Critical)

**Problem:** `health_sync_service.dart` fetches `getBloodPressure()` but never includes it in the POST payload. iOS native background sync has no `blood_pressure` case.

**Fix:** Add two flat keys to the `daily_metrics` map — `blood_pressure_systolic: bp['systolic']` and `blood_pressure_diastolic: bp['diastolic']` — matching the flat-key pattern used by every other metric in the payload (e.g., `resting_heart_rate: rhr`). Do NOT use a nested map `blood_pressure: {systolic: ..., diastolic: ...}` as the Cloud Brain `/health/ingest` endpoint parses all `daily_metrics` keys as flat scalars. Add `case "blood_pressure"` to the iOS `notifyOfChange()` switch in `HealthKitBridge.swift`, reading both `bloodPressureSystolic` and `bloodPressureDiastolic` via separate `HKStatisticsQuery` calls and posting both flat keys.

### 9.2 Sleep Stage Parsing (Missing)

**Problem:** `getSleep()` returns raw `List<Map>` from both platforms with `value` encoding the stage (iOS: `HKCategoryValueSleepAnalysis` int; Android: `StageType` string), but `_buildTileViz` in `data_providers.dart` aggregates sleep into a total duration only — the per-stage breakdown is discarded.

**Fix:** Parse the `value` field in `HealthBridge.getSleep()` on both platforms to add a `stage` key (`deep`, `rem`, `light`, `awake`, `inBed`) before returning. The dashboard builder then groups by stage to produce a `SegmentedBarConfig`.

### 9.3 Water / Hydration (Missing entirely)

**Apple Health:** Add `HKQuantityType(.dietaryWater)` to `readTypes` in `HealthKitBridge.swift`. Add `getWater(DateTime date) → double?` method (liters) to `HealthBridge` and `HealthRepository`.

**Android:** Add `HydrationRecord` to `REQUIRED_PERMISSIONS` in `HealthConnectBridge.kt`. Implement `readWater(date)`.

**Sync:** Add `water_liters` to the daily metrics payload in `HealthSyncService`.

### 9.4 Walking Metrics — Mobility (Missing)

**Apple Health:** Add `walkingAsymmetryPercentage`, `walkingSpeed`, `walkingDoubleSupportPercentage`, `sixMinuteWalkTestDistance` to `readTypes`. Add `getWalkingMetrics()` → `Map<String, double?>`.

**Android:** `FloorsClimbedRecord` already collected. No direct walking asymmetry equivalent in Health Connect; omit on Android.

**UI:** `TileId.mobility` maps to a `GaugeConfig` built from `walkingAsymmetryPercentage` (lower = better) or `sixMinuteWalkTestDistance`.

### 9.5 Cycle / Menstrual (Missing)

**Apple Health:** Add `HKCategoryType(.menstrualFlow)`, `HKCategoryType(.intermenstrualBleeding)`, `HKCategoryType(.ovulationTestResult)`, `HKCategoryType(.basalBodyTemperature)` to `readTypes`. Add `getCycleData(DateTime startDate, DateTime endDate) → List<Map>`.

**Android:** Add `MenstruationFlowRecord`, `OvulationTestRecord` to permissions. Implement `readCycleData()`.

**UI:** `TileId.cycle` maps to a `CalendarGridConfig` with phase coloring.

### 9.6 Respiratory Rate (Already collected, not surfaced)

**Status:** Collected and synced. No `TileId` exists.

**Fix:** Add `TileId.respiratoryRate`. Map to `StatCardConfig` (point-in-time value + "Normal" status) or `LineChartConfig` if 7-day trend available.

### 9.7 Nutrition Macros (Calories only, macros dropped)

**Apple Health:** `HKQuantityType(.dietaryProtein)`, `(.dietaryCarbohydrates)`, `(.dietaryFatTotal)`, `(.dietaryFiber)` to `readTypes`. Extend `getNutritionCalories()` → `getNutrition()` returning a map with `calories`, `protein`, `carbs`, `fat`, `fiber`.

**Android:** `NutritionRecord` already imported. Parse protein/carbs/fat/fiber fields instead of calories-only.

**UI:** `TileId.calories` at 1×1 shows `Ring`. At 1×2 or 2×1, appends a `SegmentedBarConfig` for macros below.

### 9.8 Wrist Temperature (Apple Watch Series 8+ only)

**Apple Health:** Add `HKQuantityType(.appleSleepingWristTemperature)` to `readTypes` in `HealthKitBridge.swift`. This type records overnight wrist temperature deviation from baseline (degrees Celsius, relative). Add `getWristTemperature() → double?` to `HealthBridge` and `HealthRepository`.

**Android:** No equivalent in Google Health Connect. On Android, `TileId.wristTemperature` always returns `null` from the bridge, and the tile displays in `noSource` ghost state.

**Sync:** Add `wrist_temperature_deviation` (flat scalar, °C) to the daily metrics payload.

**UI:** `TileId.wristTemperature` → `LineChartConfig` (7-day overnight deviation trend). `allowedSizes`: square only (trend is compact).

### 9.10 Mindful Minutes (Not requested)

**Apple Health:** Add `HKCategoryType(.mindfulSession)` to `readTypes`. Add `getMindfulMinutes(DateTime date) → double?`.

**Android:** `MindfulnessSessionRecord` available in Health Connect. Add to permissions.

**UI:** New `TileId.mindfulMinutes` → `BarChartConfig`.

---

## 10. New TileId Values

Adding 9 new tile IDs to the enum (existing 20 remain unchanged):

```dart
enum TileId {
  // existing 20 ...
  distance,          // Activity
  floorsClimbed,     // Activity
  exerciseMinutes,   // Activity
  respiratoryRate,   // Heart
  bodyTemperature,   // Body  (uses HKQuantityType(.bodyTemperature) on iOS)
  wristTemperature,  // Body  (uses HKQuantityType(.appleSleepingWristTemperature) on iOS; Apple Watch Series 8+ only; no Android equivalent — tile is ghost state on Android)
  macros,            // Nutrition
  bloodGlucose,      // Vitals
  mindfulMinutes,    // Wellness
}
```

The `cycle`, `mobility`, `water`, `environment` tiles are already in the enum — they just need their data pipelines wired (Section 9).

---

## 11. Files Changed

### Modified

| File | Change |
|---|---|
| `metric_tile.dart` | Line 177: `tileId.category.displayName` → `tileId.displayName` |
| `tile_grid.dart` | `_buildBands()`: pull-up logic for odd-count bands before wide tiles |
| `tile_visualizations.dart` | Replace 14 existing subtypes with 12 `TileVisualizationConfig` sealed classes + updated factory |
| `tile_expanded_view.dart` | Update `buildTileVisualization()` call site to new signature `(config:, categoryColor:, size:)`; confirm `size` passed is the tile's effective expanded size (tall or wide, never square) |
| `data_providers.dart` | Update `_buildTileViz()` to produce `TileVisualizationConfig` objects; add new tile IDs |
| `tile_models.dart` | Add 9 new `TileId` values; update all four exhaustive `switch` getters — `displayName`, `category`, `defaultSize`, `allowedSizes` — for all 9 new values. These switches have no `default` case and will produce a Dart compile error if any new `TileId` is omitted. Update `cycle`'s `allowedSizes` from `[square]` to `[wide, tall]`. Update `allowedSizes` for any metric using `HeatmapConfig` to exclude `TileSize.square`. |
| `health_bridge.dart` | Add `getWater()`, `getWalkingMetrics()`, `getCycleData()`, `getMindfulMinutes()`, extend `getNutrition()` |
| `health_sync_service.dart` | Add blood pressure, water, mindful minutes to sync payload |
| `HealthKitBridge.swift` | Add 12 new `readTypes`; add `blood_pressure` observer case; new read methods |
| `HealthConnectBridge.kt` | Add `HydrationRecord`, `MenstruationFlowRecord`, `MindfulnessSessionRecord` to permissions + read methods |

### New Files

| File | Purpose |
|---|---|
| `lib/features/data/presentation/widgets/viz/line_chart_viz.dart` | `LineChartViz` — all 3 sizes |
| `lib/features/data/presentation/widgets/viz/bar_chart_viz.dart` | `BarChartViz` — all 3 sizes |
| `lib/features/data/presentation/widgets/viz/area_chart_viz.dart` | `AreaChartViz` — all 3 sizes |
| `lib/features/data/presentation/widgets/viz/ring_viz.dart` | `RingViz` — all 3 sizes |
| `lib/features/data/presentation/widgets/viz/gauge_viz.dart` | `GaugeViz` — all 3 sizes |
| `lib/features/data/presentation/widgets/viz/segmented_bar_viz.dart` | `SegmentedBarViz` — all 3 sizes |
| `lib/features/data/presentation/widgets/viz/fill_gauge_viz.dart` | `FillGaugeViz` — all 3 sizes |
| `lib/features/data/presentation/widgets/viz/dot_row_viz.dart` | `DotRowViz` — all 3 sizes |
| `lib/features/data/presentation/widgets/viz/calendar_grid_viz.dart` | `CalendarGridViz` — all 3 sizes |
| `lib/features/data/presentation/widgets/viz/heatmap_viz.dart` | `HeatmapViz` — 2×1 and 1×2 only |
| `lib/features/data/presentation/widgets/viz/stat_card_viz.dart` | `StatCardViz` — all 3 sizes |
| `lib/features/data/presentation/widgets/viz/dual_value_viz.dart` | `DualValueViz` — all 3 sizes |

Each file contains a single widget class with a `size` parameter that switches internal layout.

---

## 12. Out of Scope

- Scatter / correlation charts — belongs in Trends tab, not individual tiles
- Radar / spider charts — multi-metric, belongs in Trends or Progress tab
- Nutrition micronutrients (vitamins, minerals) — supported by the viz system (SegmentedBar) but no API endpoint surfaces them yet; add when backend supports it
- Garmin, WHOOP, Polar wearable integrations — OAuth not yet complete; tiles will show ghost state until connected
- Real-time / live streaming heart rate — tile shows latest reading; live stream is a workout feature
- CGM continuous glucose integration — `TileId.bloodGlucose` is added but `BloodGlucoseRecord` on Android and `bloodGlucose` on iOS require medical device entitlements; shipped as ghost tile until entitlement approved

---

## 13. Migration from Existing Visualization System

The existing `TileVisualizationData` sealed class and its 14 subtypes (`BarChartData`, `RingData`, `LineChartData`, etc.) in `tile_visualizations.dart` are **replaced** by `TileVisualizationConfig` and the 12 new config types.

Existing viz widgets (`BarChartViz`, `RingViz`, `LineChartViz`, etc.) are **replaced** by the new per-file widgets in `viz/`. The old `buildTileVisualization()` factory is replaced by the new signature.

The `_buildTileViz()` function in `data_providers.dart` is rewritten to produce `TileVisualizationConfig` objects. All other call sites that reference `TileVisualizationData` subtypes are updated in the same pass.

This is a complete replacement, not an additive change — no compatibility shim is needed since the old and new systems are internal to the same feature.
