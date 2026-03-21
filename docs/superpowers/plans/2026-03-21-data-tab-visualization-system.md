# Data Tab — Reusable Visualization System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bespoke per-metric visualization system with 12 reusable chart widgets, fix the grid gap and label bugs, redesign card anatomy, add 11 new TileIds, and wire all missing health data pipelines.

**Architecture:** New `TileVisualizationConfig` sealed class hierarchy (in `tile_visualization_config.dart`) replaces the 14 old `TileVisualizationData` subtypes. Twelve stateless viz widgets in `widgets/viz/` each accept a config + color + size parameter and switch their internal layout. The existing `_buildTileViz()` in `data_providers.dart` is rewritten to produce configs. Native bridges (iOS Swift, Android Kotlin) are extended independently and can be done in parallel with Flutter work.

**Tech Stack:** Flutter/Dart (Riverpod, flutter_staggered_grid_view), Swift HealthKit, Kotlin Health Connect, platform channels (`com.zuralog/health`).

---

## File Map

### New files
| Path | Purpose |
|---|---|
| `lib/features/data/domain/tile_visualization_config.dart` | Sealed class hierarchy (12 config types + 7 supporting models) |
| `lib/features/data/presentation/widgets/viz/bar_chart_viz.dart` | `BarChartViz` — 3 sizes |
| `lib/features/data/presentation/widgets/viz/line_chart_viz.dart` | `LineChartViz` — 3 sizes |
| `lib/features/data/presentation/widgets/viz/area_chart_viz.dart` | `AreaChartViz` — 3 sizes |
| `lib/features/data/presentation/widgets/viz/ring_viz.dart` | `RingViz` — 3 sizes |
| `lib/features/data/presentation/widgets/viz/gauge_viz.dart` | `GaugeViz` — 3 sizes |
| `lib/features/data/presentation/widgets/viz/segmented_bar_viz.dart` | `SegmentedBarViz` — 3 sizes |
| `lib/features/data/presentation/widgets/viz/fill_gauge_viz.dart` | `FillGaugeViz` — 3 sizes |
| `lib/features/data/presentation/widgets/viz/dot_row_viz.dart` | `DotRowViz` — 3 sizes |
| `lib/features/data/presentation/widgets/viz/calendar_grid_viz.dart` | `CalendarGridViz` — 3 sizes |
| `lib/features/data/presentation/widgets/viz/heatmap_viz.dart` | `HeatmapViz` — wide + tall only |
| `lib/features/data/presentation/widgets/viz/stat_card_viz.dart` | `StatCardViz` — 3 sizes |
| `lib/features/data/presentation/widgets/viz/dual_value_viz.dart` | `DualValueViz` — 3 sizes |
| `test/features/data/domain/tile_visualization_config_test.dart` | Config model unit tests |
| `test/features/data/presentation/widgets/viz/bar_chart_viz_test.dart` | BarChartViz widget tests |
| *(same pattern for other 11 viz widgets)* | |

### Modified files
| Path | Change summary |
|---|---|
| `lib/features/data/domain/tile_models.dart` | Add 11 new TileId values; update `displayName`, `category`, `defaultSize`, `allowedSizes`; update `cycle` allowedSizes |
| `lib/features/data/presentation/widgets/tile_grid.dart` | `_buildBands()` pull-up algorithm for gap fix |
| `lib/features/data/presentation/widgets/metric_tile.dart` | Replace `_CategoryHeader` + `_buildTileContent` with Option C anatomy |
| `lib/features/data/presentation/widgets/tile_visualizations.dart` | Replace factory + delete old viz widgets (keep file, gut contents) |
| `lib/features/data/presentation/widgets/tile_expanded_view.dart` | Update `buildTileVisualization()` call to new signature |
| `lib/features/data/providers/data_providers.dart` | Rewrite `_buildTileViz()` to produce `TileVisualizationConfig` |
| `lib/core/health/health_bridge.dart` | Add 8 new methods |
| `lib/features/health/data/health_sync_service.dart` | Add new payload keys |
| `ios/Runner/HealthKitBridge.swift` | Add 15 new readTypes + read methods + blood_pressure observer |
| `android/app/src/main/kotlin/com/zuralog/zuralog/HealthConnectBridge.kt` | Add 5 new record types + read methods |
| `test/features/data/domain/tile_models_test.dart` | Update count assertions; add new TileId cases |
| `test/features/data/presentation/widgets/metric_tile_test.dart` | Add anatomy tests |
| `test/features/data/providers/data_providers_test.dart` | Add new TileId cases |

---

## Task 1: Extend TileId Enum (tile_models.dart)

**Files:**
- Modify: `lib/features/data/domain/tile_models.dart:18-51` (enum) and `:318-451` (TileConfig extension)
- Test: `test/features/data/domain/tile_models_test.dart`

- [ ] **Step 1: Update the failing test count assertion**

Open `test/features/data/domain/tile_models_test.dart`. Change:
```dart
test('has exactly 20 values', () {
  expect(TileId.values.length, 20);
});
```
to:
```dart
test('has exactly 31 values', () {
  expect(TileId.values.length, 31);
});
```
Also add a test that verifies all 11 new slugs round-trip:
```dart
test('new TileId slugs round-trip via fromString', () {
  const newIds = [
    'distance', 'floorsClimbed', 'exerciseMinutes', 'walkingSpeed',
    'runningPace', 'respiratoryRate', 'bodyTemperature', 'wristTemperature',
    'macros', 'bloodGlucose', 'mindfulMinutes',
  ];
  for (final slug in newIds) {
    expect(TileId.fromString(slug), isNotNull, reason: 'slug "$slug" should be valid');
  }
});
```

- [ ] **Step 2: Run test to confirm it fails**

```
flutter test test/features/data/domain/tile_models_test.dart
```
Expected: FAIL — count assertion 20 ≠ 31 and new slug assertions.

- [ ] **Step 3: Add 11 new enum values to tile_models.dart**

In `tile_models.dart`, after `mobility;` (line 38), change the closing `;` to `,` and append:
```dart
  // ── New tiles (Phase 8 expansion) ─────────────────────────────────────────
  distance,
  floorsClimbed,
  exerciseMinutes,
  walkingSpeed,
  runningPace,
  respiratoryRate,
  bodyTemperature,
  wristTemperature,
  macros,
  bloodGlucose,
  mindfulMinutes;
```

- [ ] **Step 4: Update `displayName` switch in TileConfig extension**

The `displayName` getter has no `default:` case — the Dart compiler will error until all cases are covered. Add before the closing `}`:
```dart
      case TileId.distance:         return 'Distance';
      case TileId.floorsClimbed:    return 'Floors Climbed';
      case TileId.exerciseMinutes:  return 'Exercise Minutes';
      case TileId.walkingSpeed:     return 'Walking Speed';
      case TileId.runningPace:      return 'Running Pace';
      case TileId.respiratoryRate:  return 'Respiratory Rate';
      case TileId.bodyTemperature:  return 'Body Temperature';
      case TileId.wristTemperature: return 'Wrist Temperature';
      case TileId.macros:           return 'Macros';
      case TileId.bloodGlucose:     return 'Blood Glucose';
      case TileId.mindfulMinutes:   return 'Mindful Minutes';
```

- [ ] **Step 5: Update `category` switch**

Add before the closing `}` of the `category` getter:
```dart
      case TileId.distance:
      case TileId.floorsClimbed:
      case TileId.exerciseMinutes:
      case TileId.walkingSpeed:
      case TileId.runningPace:
        return HealthCategory.activity;
      case TileId.respiratoryRate:
        return HealthCategory.heart;
      case TileId.bodyTemperature:
      case TileId.wristTemperature:
        return HealthCategory.body;
      case TileId.macros:
        return HealthCategory.nutrition;
      case TileId.bloodGlucose:
        return HealthCategory.vitals;
      case TileId.mindfulMinutes:
        return HealthCategory.wellness;
```

- [ ] **Step 6: Update `defaultSize` and `allowedSizes` switches**

`defaultSize` uses `default:` — no compile error, but must be updated manually. Add explicit cases before `default:`:
```dart
      case TileId.cycle:
        return TileSize.wide;  // wide strip, not square
      case TileId.sleepStages:
        return TileSize.wide;
      case TileId.weight:
        return TileSize.wide;
      case TileId.steps:
        return TileSize.tall;
      // All 11 new IDs default to square (handled by default:)
```

`allowedSizes` also uses `default:`. Update the `cycle` case and add new entries:
```dart
      case TileId.cycle:
        return const [TileSize.wide, TileSize.tall]; // was [TileSize.square]
      case TileId.wristTemperature:
        return const [TileSize.square]; // Apple Watch only, compact
      case TileId.walkingSpeed:
      case TileId.runningPace:
      case TileId.bodyTemperature:
      case TileId.respiratoryRate:
        return const [TileSize.square, TileSize.wide];
      case TileId.distance:
      case TileId.floorsClimbed:
      case TileId.exerciseMinutes:
      case TileId.macros:
      case TileId.bloodGlucose:
      case TileId.mindfulMinutes:
        return const [TileSize.square, TileSize.tall];
```

- [ ] **Step 7: Run tests**

```
flutter test test/features/data/domain/tile_models_test.dart
```
Expected: PASS.

- [ ] **Step 8: Compile check**

```
flutter analyze lib/features/data/domain/tile_models.dart
```
Expected: no errors.

- [ ] **Step 9: Commit**

```bash
git add lib/features/data/domain/tile_models.dart test/features/data/domain/tile_models_test.dart
git commit -m "feat(data): add 11 new TileId values; update all TileConfig switch getters"
```

---

## Task 2: New TileVisualizationConfig Data Model

**Files:**
- Create: `lib/features/data/domain/tile_visualization_config.dart`
- Create: `test/features/data/domain/tile_visualization_config_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/features/data/domain/tile_visualization_config_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

void main() {
  group('TileVisualizationConfig sealed class', () {
    test('LineChartConfig stores fields', () {
      final now = DateTime(2026, 3, 21);
      final config = LineChartConfig(
        points: [ChartPoint(date: now, value: 60.0)],
        positiveIsUp: true,
      );
      expect(config.points.length, 1);
      expect(config.referenceLine, isNull);
      expect(config.positiveIsUp, isTrue);
    });

    test('BarChartConfig stores fields', () {
      final config = BarChartConfig(
        bars: [BarPoint(label: 'Mon', value: 8000, isToday: false)],
        goalValue: 10000,
        showAvgLine: true,
      );
      expect(config.bars.length, 1);
      expect(config.goalValue, 10000);
    });

    test('RingConfig weeklyBars null means no bars', () {
      final config = RingConfig(value: 7500, maxValue: 10000, unit: 'steps');
      expect(config.weeklyBars, isNull);
    });

    test('RingConfig weeklyBars non-null enables bar row', () {
      final config = RingConfig(
        value: 7500,
        maxValue: 10000,
        unit: 'steps',
        weeklyBars: [BarPoint(label: 'M', value: 7500, isToday: true)],
      );
      expect(config.weeklyBars, isNotNull);
      expect(config.weeklyBars!.length, 1);
    });

    test('GaugeConfig stores zones', () {
      final config = GaugeConfig(
        value: 45.0,
        minValue: 0,
        maxValue: 70,
        zones: [
          GaugeZone(min: 0, max: 30, label: 'Poor', color: Colors.red),
          GaugeZone(min: 30, max: 70, label: 'Good', color: Colors.green),
        ],
      );
      expect(config.zones.length, 2);
    });

    test('HeatmapConfig is a TileVisualizationConfig', () {
      final config = HeatmapConfig(
        cells: [],
        colorLow: Colors.white,
        colorHigh: Colors.blue,
        legendLabel: 'Steps',
      );
      expect(config, isA<TileVisualizationConfig>());
    });
  });
}
```

- [ ] **Step 2: Run to confirm compile failure**

```
flutter test test/features/data/domain/tile_visualization_config_test.dart
```
Expected: FAIL — `tile_visualization_config.dart` doesn't exist yet.

- [ ] **Step 3: Create tile_visualization_config.dart**

Create `lib/features/data/domain/tile_visualization_config.dart`:
```dart
library;

import 'package:flutter/material.dart';

// ── Supporting models ──────────────────────────────────────────────────────────

class ChartPoint {
  const ChartPoint({required this.date, required this.value});
  final DateTime date;
  final double value;
}

class BarPoint {
  const BarPoint({required this.label, required this.value, required this.isToday});
  final String label;
  final double value;
  final bool isToday;
}

class GaugeZone {
  const GaugeZone({required this.min, required this.max, required this.label, required this.color});
  final double min;
  final double max;
  final String label;
  final Color color;
}

class Segment {
  const Segment({required this.label, required this.value, required this.color, this.icon});
  final String label;
  final double value;
  final Color color;
  final String? icon;
}

class DotPoint {
  const DotPoint({required this.value, this.label, this.emoji});
  final double value; // 0.0–1.0
  final String? label;
  final String? emoji;
}

class CalendarDay {
  const CalendarDay({required this.dayNumber, required this.value, this.phase, this.phaseColor});
  final int dayNumber;
  final double value; // 0.0–1.0
  final String? phase;
  final Color? phaseColor;
}

class HeatmapCell {
  const HeatmapCell({required this.date, required this.value});
  final DateTime date;
  final double value;
}

// ── TileVisualizationConfig sealed class ──────────────────────────────────────

sealed class TileVisualizationConfig {
  const TileVisualizationConfig();
}

class LineChartConfig extends TileVisualizationConfig {
  const LineChartConfig({
    required this.points,
    this.referenceLine,
    this.rangeMin,
    this.rangeMax,
    this.positiveIsUp = true,
  });
  final List<ChartPoint> points;
  final double? referenceLine;
  final double? rangeMin;
  final double? rangeMax;
  final bool positiveIsUp;
}
// LineChartConfig is always single-line. Paired metrics use DualValueConfig.

class BarChartConfig extends TileVisualizationConfig {
  const BarChartConfig({
    required this.bars,
    this.goalValue,
    this.showAvgLine = false,
  });
  final List<BarPoint> bars;
  final double? goalValue;
  final bool showAvgLine;
}

class AreaChartConfig extends TileVisualizationConfig {
  const AreaChartConfig({
    required this.points,
    this.targetLine,
    this.fillOpacity = 0.15,
    this.delta,
    this.positiveIsUp = true,
  });
  final List<ChartPoint> points;
  final double? targetLine;
  final double fillOpacity;
  final double? delta; // e.g. -0.03 = ↓ 3%
  final bool positiveIsUp;
}

class RingConfig extends TileVisualizationConfig {
  const RingConfig({
    required this.value,
    required this.maxValue,
    required this.unit,
    this.weeklyBars,
  });
  final double value;
  final double maxValue;
  final String unit;
  // Non-null enables the 7-day bar row on 1×2 tiles. No separate bool flag.
  final List<BarPoint>? weeklyBars;
}

class GaugeConfig extends TileVisualizationConfig {
  const GaugeConfig({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.zones,
  });
  final double value;
  final double minValue;
  final double maxValue;
  final List<GaugeZone> zones;
}

class SegmentedBarConfig extends TileVisualizationConfig {
  const SegmentedBarConfig({required this.segments, required this.totalLabel});
  final List<Segment> segments;
  final String totalLabel;
}

class FillGaugeConfig extends TileVisualizationConfig {
  const FillGaugeConfig({
    required this.value,
    required this.maxValue,
    required this.unit,
    this.unitIcon,
    this.unitSize,
  });
  final double value;
  final double maxValue;
  final String unit;
  final String? unitIcon;
  final double? unitSize; // e.g. 0.3 for 0.3L per glass
}

class DotRowConfig extends TileVisualizationConfig {
  const DotRowConfig({required this.points, this.invertedScale = false});
  final List<DotPoint> points;
  final bool invertedScale; // true for Stress — lower is better
}

class CalendarGridConfig extends TileVisualizationConfig {
  const CalendarGridConfig({required this.days, required this.totalDays});
  final List<CalendarDay> days;
  final int totalDays; // 28 for cycle, 30/31 for month
}

class HeatmapConfig extends TileVisualizationConfig {
  const HeatmapConfig({
    required this.cells,
    required this.colorLow,
    required this.colorHigh,
    required this.legendLabel,
  });
  final List<HeatmapCell> cells;
  final Color colorLow;
  final Color colorHigh;
  final String legendLabel;
}

class StatCardConfig extends TileVisualizationConfig {
  const StatCardConfig({
    required this.value,
    required this.unit,
    this.statusColor,
    this.statusLabel,
    this.secondaryValue,
    this.trendNote,
  });
  final String value;
  final String unit;
  final Color? statusColor;
  final String? statusLabel;
  final String? secondaryValue;
  final String? trendNote;
}

class DualValueConfig extends TileVisualizationConfig {
  const DualValueConfig({
    required this.value1,
    required this.label1,
    required this.value2,
    required this.label2,
    this.points1,
    this.points2,
  });
  final String value1;
  final String label1;
  final String value2;
  final String label2;
  final List<ChartPoint>? points1;
  final List<ChartPoint>? points2;
}
```

- [ ] **Step 4: Run tests**

```
flutter test test/features/data/domain/tile_visualization_config_test.dart
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/data/domain/tile_visualization_config.dart test/features/data/domain/tile_visualization_config_test.dart
git commit -m "feat(data): add TileVisualizationConfig sealed class + 7 supporting models"
```

---

## Task 3: Grid Gap Fix

**Files:**
- Modify: `lib/features/data/presentation/widgets/tile_grid.dart:221-246` (`_buildBands`)
- Test: create `test/features/data/presentation/widgets/tile_grid_band_test.dart`

Background: `_buildBands()` currently emits a `_Band.wide` immediately after flushing pending non-wide tiles. If pending count is odd, the masonry grid renders with one empty column before the wide tile. The fix: when a wide tile is encountered and the pending list has an odd count, look ahead in the remaining IDs for the next non-wide tile, pull it into pending first, then flush, then emit the wide band.

- [ ] **Step 1: Write failing test**

The `_buildBands` method is private, so test it indirectly via `TileGrid`'s rendered output, or extract it for testing. Easiest: extract the logic into a top-level function `buildBands(List<TileId> ids, TileSize Function(TileId) sizeOf)` and test that directly.

Create `test/features/data/presentation/widgets/tile_grid_band_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_grid.dart';

void main() {
  group('buildBands gap fix', () {
    // Helper: returns wide for sleepStages, square for everything else
    TileSize sizeOf(TileId id) =>
        id == TileId.sleepStages ? TileSize.wide : TileSize.square;

    test('odd pending count before wide: pulls next non-wide tile up', () {
      // [steps, activeCalories, workouts] = 3 (odd), then [sleepStages (wide)], then [weight]
      final ids = [
        TileId.steps,
        TileId.activeCalories,
        TileId.workouts,
        TileId.sleepStages,
        TileId.weight,
      ];
      final bands = buildBands(ids, sizeOf);
      // Expect first masonry band to have 4 tiles (workouts pulled up before wide)
      expect(bands[0].ids.length, 4);
      expect(bands[0].ids.last, TileId.weight);
      expect(bands[1].isWide, isTrue);
      // No remaining masonry band after wide
      expect(bands.length, 2);
    });

    test('even pending count before wide: no pull-up needed', () {
      final ids = [TileId.steps, TileId.activeCalories, TileId.sleepStages];
      final bands = buildBands(ids, sizeOf);
      expect(bands[0].ids.length, 2);
      expect(bands[1].isWide, isTrue);
    });

    test('odd pending, no non-wide tile after wide: inserts spacer', () {
      final ids = [TileId.steps, TileId.sleepStages];
      final bands = buildBands(ids, sizeOf);
      // Spacer pulled in — masonry band has 2 tiles (steps + spacer placeholder)
      expect(bands[0].ids.length, 2);
      expect(bands[0].ids.last, TileId.values.last); // spacer sentinel or null
    });
  });
}
```

> Note: The test for the spacer case will need adjustment based on your chosen spacer sentinel implementation. Adjust after seeing the implementation.

- [ ] **Step 2: Run test to confirm fail**

```
flutter test test/features/data/presentation/widgets/tile_grid_band_test.dart
```
Expected: compile error — `buildBands` not yet exported.

- [ ] **Step 3: Extract and implement `buildBands` in tile_grid.dart**

In `tile_grid.dart`, add a top-level function (below the imports, before the `TileGrid` class) that implements the pull-up algorithm:

Use a nullable list (`List<TileId?>`) to represent bands so a `null` entry signals an empty spacer slot — no enum sentinel needed:

```dart
/// A band item: either a real TileId or null (transparent spacer).
typedef BandItem = TileId?;

/// Extracted for testability. Call [_buildBands] inside TileGrid instead.
@visibleForTesting
List<Band> buildBands(List<TileId> ids, TileSize Function(TileId) sizeOf) {
  final bands = <Band>[];
  final remaining = ids.toList(); // mutable copy
  final pending = <BandItem>[]; // nullable — null = transparent spacer

  while (remaining.isNotEmpty) {
    final id = remaining.removeAt(0);
    final size = sizeOf(id);

    if (size == TileSize.wide) {
      if (pending.length.isOdd) {
        // Pull up next non-wide tile to fill the empty column.
        final nextNonWideIdx = remaining.indexWhere((r) => sizeOf(r) != TileSize.wide);
        if (nextNonWideIdx != -1) {
          pending.add(remaining.removeAt(nextNonWideIdx));
        } else {
          // No non-wide tile available — insert null spacer.
          pending.add(null);
        }
      }
      if (pending.isNotEmpty) {
        bands.add(Band.masonry(List.from(pending)));
        pending.clear();
      }
      bands.add(Band.wide(id));
    } else {
      pending.add(id);
    }
  }

  if (pending.isNotEmpty) {
    bands.add(Band.masonry(List.from(pending)));
  }

  return bands;
}
```

> **Important:** Change `Band.ids` from `List<TileId>` to `List<TileId?>` throughout. The `_Band` class in `tile_grid.dart` also needs this update.

Then update `_buildBands` in `TileGrid` to delegate:
```dart
List<Band> _buildBands(List<TileId> ids) =>
    buildBands(ids, _effectiveSize);
```

Update `_buildNormalMode` to handle null spacer items:
```dart
itemBuilder: (context, i) {
  final id = band.ids[i]; // TileId?
  if (id == null) return const SizedBox.shrink(); // transparent spacer
  return _buildTappableTile(context, id);
},
```

Rename `_Band` → `Band` (or keep as `_Band` and export `buildBands` separately using the `@visibleForTesting` pattern).

> **Important:** The existing `_Band` class is private. You have two options:
> 1. Rename it to `Band` (public), export `buildBands` — allows direct test of the function.
> 2. Keep `_Band` private, test via widget integration test that no `SizedBox` gap appears.
>
> Option 1 is cleaner. Rename `_Band` → `Band` throughout the file.

- [ ] **Step 4: Adjust test assertions if needed, then run**

```
flutter test test/features/data/presentation/widgets/tile_grid_band_test.dart
```
Expected: PASS.

- [ ] **Step 5: Run full test suite for the data feature**

```
flutter test test/features/data/
```
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/data/presentation/widgets/tile_grid.dart \
        test/features/data/presentation/widgets/tile_grid_band_test.dart
git commit -m "fix(data): pull-up algorithm in _buildBands fills odd-column gap before wide tiles"
```

---

## Task 4: Card Anatomy Redesign (metric_tile.dart)

**Files:**
- Modify: `lib/features/data/presentation/widgets/metric_tile.dart:136-259`
- Test: `test/features/data/presentation/widgets/metric_tile_test.dart`

Current: `_CategoryHeader` shows a colored dot + category name (e.g. "Activity").
Target (Option C): metric display name (STEPS, uppercase) + colored category pill (● Activity) + icon top-right + hero value larger.

- [ ] **Step 1: Write failing tests**

Add to `test/features/data/presentation/widgets/metric_tile_test.dart`:
```dart
testWidgets('shows tileId.displayName not category name', (tester) async {
  await tester.pumpWidget(_buildTile(tileId: TileId.steps, dataState: TileDataState.loaded));
  expect(find.text('STEPS'), findsOneWidget);         // metric name uppercased
  expect(find.text('ACTIVITY'), findsNothing);          // category must NOT be the header
});

testWidgets('shows category pill with category name', (tester) async {
  await tester.pumpWidget(_buildTile(tileId: TileId.steps, dataState: TileDataState.loaded));
  expect(find.text('● Activity'), findsOneWidget);
});

testWidgets('does not show _CategoryHeader dot', (tester) async {
  await tester.pumpWidget(_buildTile(tileId: TileId.steps, dataState: TileDataState.loaded));
  expect(find.byKey(const Key('category_color_dot')), findsNothing);
});
```

The `_buildTile` helper should already exist in the test file. If not, create:
```dart
Widget _buildTile({
  required TileId tileId,
  TileDataState dataState = TileDataState.loaded,
  TileSize size = TileSize.square,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MetricTile(
        tileId: tileId,
        dataState: dataState,
        size: size,
        primaryValue: '8,432',
        unit: 'steps today',
      ),
    ),
  );
}
```

- [ ] **Step 2: Run to confirm fail**

```
flutter test test/features/data/presentation/widgets/metric_tile_test.dart
```
Expected: FAIL — finds "Activity" header, doesn't find "STEPS" or pill.

- [ ] **Step 3: Implement Option C anatomy in `_buildTileContent`**

Replace the `_CategoryHeader` call and the area around it in `_buildTileContent` (lines 174–180 in metric_tile.dart):

**Remove:**
```dart
_CategoryHeader(
  categoryName: tileId.category.displayName,
  color: effectiveColor,
),
const SizedBox(height: 8),
```

**Replace with:**
```dart
_MetricHeader(tileId: tileId, color: effectiveColor),
const SizedBox(height: 6),
```

Then add the `_MetricHeader` widget class (replaces `_CategoryHeader`):
```dart
class _MetricHeader extends StatelessWidget {
  const _MetricHeader({required this.tileId, required this.color});
  final TileId tileId;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: metric name + category pill stacked
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tileId.displayName.toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              _CategoryPill(category: tileId.category, color: color),
            ],
          ),
        ),
        // Right: metric icon
        Text(
          tileId.icon,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category, required this.color});
  final HealthCategory category;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '● ${category.displayName}',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
```

> **Note:** This requires `tileId.icon` to exist on `TileId`. Check if the `TileConfig` extension already has an `icon` getter. If not, add it to `tile_models.dart` with emoji icons for each TileId. Example:
> ```dart
> String get icon {
>   switch (this) {
>     case TileId.steps:          return '👟';
>     case TileId.activeCalories: return '🔥';
>     case TileId.workouts:       return '💪';
>     // ... add for all 31 TileIds
>   }
> }
> ```

Also remove `_CategoryHeader` class (lines 224–258) from metric_tile.dart — it is no longer used. Check there are no other call sites first:
```
grep -r '_CategoryHeader' lib/
```
If zero results, delete the class.

- [ ] **Step 4: Run tests**

```
flutter test test/features/data/presentation/widgets/metric_tile_test.dart
```
Expected: PASS.

- [ ] **Step 5: Run full test suite**

```
flutter test test/features/data/
```
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/data/domain/tile_models.dart \
        lib/features/data/presentation/widgets/metric_tile.dart \
        test/features/data/presentation/widgets/metric_tile_test.dart
git commit -m "feat(data): Option C card anatomy — metric name + category pill + icon; fix label bug"
```

---

## Tasks 5–16: 12 Visualization Widgets

Each viz widget follows the same pattern. Complete them in this order (simplest first):

**Order:** StatCard → DualValue → Ring → BarChart → LineChart → AreaChart → Gauge → SegmentedBar → FillGauge → DotRow → CalendarGrid → Heatmap

### Task 5: StatCardViz

**Files:**
- Create: `lib/features/data/presentation/widgets/viz/stat_card_viz.dart`
- Create: `test/features/data/presentation/widgets/viz/stat_card_viz_test.dart`

- [ ] **Step 1: Write failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/stat_card_viz.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final config = StatCardConfig(
    value: '16',
    unit: 'breaths/min',
    statusColor: Colors.green,
    statusLabel: 'Normal',
  );

  testWidgets('square: shows value and status label', (tester) async {
    await tester.pumpWidget(_wrap(
      StatCardViz(config: config, color: Colors.blue, size: TileSize.square),
    ));
    expect(find.text('16'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
  });

  testWidgets('wide: shows secondary stats panel', (tester) async {
    final cfg = StatCardConfig(
      value: '16', unit: 'breaths/min',
      secondaryValue: '14–18 avg', trendNote: 'Stable this week',
    );
    await tester.pumpWidget(_wrap(
      StatCardViz(config: cfg, color: Colors.blue, size: TileSize.wide),
    ));
    expect(find.text('14–18 avg'), findsOneWidget);
  });

  testWidgets('renders without exception for all sizes', (tester) async {
    for (final size in TileSize.values) {
      await tester.pumpWidget(_wrap(
        StatCardViz(config: config, color: Colors.blue, size: size),
      ));
    }
  });
}
```

- [ ] **Step 2: Run to confirm fail** — `flutter test test/features/data/presentation/widgets/viz/stat_card_viz_test.dart`

- [ ] **Step 3: Implement StatCardViz**

Create `lib/features/data/presentation/widgets/viz/stat_card_viz.dart`:
```dart
library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class StatCardViz extends StatelessWidget {
  const StatCardViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final StatCardConfig config;
  final Color color;
  final TileSize size;

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      TileSize.square => _Square(config: config, color: color),
      TileSize.wide   => _Wide(config: config, color: color),
      TileSize.tall   => _Tall(config: config, color: color),
    };
  }
}

class _Square extends StatelessWidget {
  const _Square({required this.config, required this.color});
  final StatCardConfig config;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.statusLabel != null)
          Row(children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: config.statusColor ?? color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(config.statusLabel!, style: const TextStyle(fontSize: 9)),
          ]),
        Text(config.unit, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
      ],
    );
  }
}

class _Wide extends StatelessWidget {
  const _Wide({required this.config, required this.color});
  final StatCardConfig config;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (config.statusColor != null)
          Container(
            width: 6, height: 6,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: config.statusColor, shape: BoxShape.circle),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (config.statusLabel != null)
                Text(config.statusLabel!, style: const TextStyle(fontSize: 9)),
              if (config.secondaryValue != null)
                Text(config.secondaryValue!, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
              if (config.trendNote != null)
                Text(config.trendNote!, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tall extends StatelessWidget {
  const _Tall({required this.config, required this.color});
  final StatCardConfig config;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.statusLabel != null)
          Row(children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: config.statusColor ?? color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(config.statusLabel!, style: const TextStyle(fontSize: 9)),
          ]),
        if (config.trendNote != null) ...[
          const SizedBox(height: 4),
          Text(config.trendNote!, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        ],
        if (config.secondaryValue != null) ...[
          const SizedBox(height: 4),
          Text(config.secondaryValue!, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Run tests** — `flutter test test/features/data/presentation/widgets/viz/stat_card_viz_test.dart` → PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/data/presentation/widgets/viz/stat_card_viz.dart \
        test/features/data/presentation/widgets/viz/stat_card_viz_test.dart
git commit -m "feat(data): add StatCardViz — all 3 sizes"
```

---

### Task 6: DualValueViz

**Files:**
- Create: `lib/features/data/presentation/widgets/viz/dual_value_viz.dart`
- Create: `test/features/data/presentation/widgets/viz/dual_value_viz_test.dart`

- [ ] **Step 1: Write failing test**

```dart
testWidgets('square: shows both values with slash divider', (tester) async {
  final config = DualValueConfig(
    value1: '120', label1: 'SYS',
    value2: '78',  label2: 'DIA',
  );
  await tester.pumpWidget(_wrap(
    DualValueViz(config: config, color: Colors.red, size: TileSize.square),
  ));
  expect(find.text('120'), findsOneWidget);
  expect(find.text('78'), findsOneWidget);
  expect(find.text('SYS'), findsOneWidget);
});

testWidgets('renders without exception for all sizes', (tester) async { ... });
```

- [ ] **Step 2: Run to confirm fail**
- [ ] **Step 3: Implement DualValueViz**

Square layout: `Row(children: [_ValueColumn(value1, label1), Text('/'), _ValueColumn(value2, label2)])`.
Wide layout: same row on left + two mini sparklines on right (if `points1`/`points2` non-null, render tiny `CustomPaint` line; else show secondary stat).
Tall layout: two `_ValueColumn` stacked vertically with sparklines below each.

The sparklines in wide/tall are optional: if `config.points1 == null`, omit them and fill with `Text(config.label1)` only.

- [ ] **Step 4: Run tests** → PASS
- [ ] **Step 5: Commit** — `"feat(data): add DualValueViz — all 3 sizes"`

---

### Task 7: RingViz

**Files:**
- Create: `lib/features/data/presentation/widgets/viz/ring_viz.dart`
- Create: `test/features/data/presentation/widgets/viz/ring_viz_test.dart`

- [ ] **Step 1: Write failing test**

```dart
testWidgets('square: shows percentage text inside ring', (tester) async {
  final config = RingConfig(value: 7500, maxValue: 10000, unit: 'steps');
  await tester.pumpWidget(_wrap(
    RingViz(config: config, color: Colors.blue, size: TileSize.square),
  ));
  expect(find.text('75%'), findsOneWidget);
});

testWidgets('tall: shows bar row when weeklyBars non-null', (tester) async {
  final config = RingConfig(
    value: 7500, maxValue: 10000, unit: 'steps',
    weeklyBars: List.generate(7, (i) =>
      BarPoint(label: 'D$i', value: 5000.0 + i * 500, isToday: i == 6)),
  );
  await tester.pumpWidget(_wrap(
    RingViz(config: config, color: Colors.blue, size: TileSize.tall),
  ));
  expect(find.byType(RingViz), findsOneWidget); // smoke; bar row rendered
});

testWidgets('tall: no bar row when weeklyBars null', (tester) async {
  final config = RingConfig(value: 7500, maxValue: 10000, unit: 'steps');
  await tester.pumpWidget(_wrap(
    RingViz(config: config, color: Colors.blue, size: TileSize.tall),
  ));
  // Should not throw or produce overflow
});
```

- [ ] **Step 2: Run to confirm fail**
- [ ] **Step 3: Implement RingViz**

Use `CircularProgressIndicator` with `value: config.value / config.maxValue`. Center text: `'${(config.value / config.maxValue * 100).round()}%'`.

Square: 80px ring, centered.
Wide: 90px ring left, `Column(current, goal, remaining)` right in a `Row`.
Tall: 110px ring, below it a mini bar chart row if `config.weeklyBars != null` — 7 small `Container` bars with height proportional to value, today's bar uses `color` at full opacity.

- [ ] **Step 4: Run tests** → PASS
- [ ] **Step 5: Commit** — `"feat(data): add RingViz — 3 sizes; bar row on tall when weeklyBars non-null"`

---

### Task 8: BarChartViz

**Files:**
- Create: `lib/features/data/presentation/widgets/viz/bar_chart_viz.dart`
- Create: `test/features/data/presentation/widgets/viz/bar_chart_viz_test.dart`

- [ ] **Step 1: Write failing test**

```dart
testWidgets('square: renders 5 bars minimum', (tester) async {
  final bars = List.generate(7, (i) =>
    BarPoint(label: ['M','T','W','T','F','S','S'][i], value: 5000.0 + i * 1000, isToday: i == 6));
  final config = BarChartConfig(bars: bars);
  await tester.pumpWidget(_wrap(
    BarChartViz(config: config, color: Colors.green, size: TileSize.square),
  ));
  // 5 bars shown for square (last 5 of 7)
  expect(find.byKey(const Key('bar_chart_bar')), findsNWidgets(5));
});

testWidgets('wide: renders 7 bars with day labels', (tester) async { ... });
testWidgets('renders without exception for all sizes', (tester) async { ... });
```

- [ ] **Step 2: Run to confirm fail**
- [ ] **Step 3: Implement BarChartViz**

Square: show last 5 bars. No labels. Compact height (60px). Each bar is a `Container` with `color.withOpacity(isToday ? 1.0 : 0.25 + 0.15 * i)`. Tag each bar container with `Key('bar_chart_bar')`.

Wide: show all 7 bars. Day-of-week labels below each bar. Goal line: if `config.goalValue != null`, draw a dashed `Divider`-like line using `CustomPaint`. If `config.showAvgLine`, show a dotted average line in a secondary color.

Tall: same as wide but taller bars (full height), stats row at bottom with avg / best / delta.

- [ ] **Step 4: Run tests** → PASS
- [ ] **Step 5: Commit** — `"feat(data): add BarChartViz — 3 sizes; goal + avg lines on wide/tall"`

---

### Task 9: LineChartViz

**Files:**
- Create: `lib/features/data/presentation/widgets/viz/line_chart_viz.dart`
- Create: `test/features/data/presentation/widgets/viz/line_chart_viz_test.dart`

- [ ] **Step 1: Write failing test**

```dart
testWidgets('square: renders compact sparkline', (tester) async {
  final now = DateTime(2026, 3, 21);
  final config = LineChartConfig(
    points: List.generate(7, (i) =>
      ChartPoint(date: now.subtract(Duration(days: 6 - i)), value: 60.0 + i)),
    positiveIsUp: true,
  );
  await tester.pumpWidget(_wrap(SizedBox(
    height: 60, width: 120,
    child: LineChartViz(config: config, color: Colors.red, size: TileSize.square),
  )));
  expect(find.byType(LineChartViz), findsOneWidget);
});
testWidgets('renders without exception for all sizes', (tester) async { ... });
```

- [ ] **Step 2: Run to confirm fail**
- [ ] **Step 3: Implement LineChartViz**

Use `CustomPaint` with a `_LinePainter` that:
- Converts `List<ChartPoint>` to normalized x (time) + y (value) coordinates.
- Draws a single `Path` with `canvas.drawPath`.
- Square: 36px height, no axes, today dot only (filled circle at last point).
- Wide: full height, range band if `rangeMin`/`rangeMax` non-null (filled rect between two lines), reference line if non-null (dashed), today dot highlighted.
- Tall: 120px+, x-axis day labels via `TextPainter`, min/avg/max stats row.

If `config.points.isEmpty`, render a `SizedBox.shrink()` (no crash).

- [ ] **Step 4: Run tests** → PASS
- [ ] **Step 5: Commit** — `"feat(data): add LineChartViz — 3 sizes; range band + reference line support"`

---

### Task 10: AreaChartViz

- [ ] Follow same pattern as LineChartViz but:
  - Fill beneath the line using `path.lineTo(bottomRight)` + `path.lineTo(bottomLeft)` + `path.close()` with `color.withOpacity(config.fillOpacity)`.
  - Draw dashed `targetLine` if non-null.
  - Show `_DeltaBadge` if `config.delta != null` (reuse from old codebase or create small helper widget: arrow + percentage, color based on `positiveIsUp`).
- [ ] Commit: `"feat(data): add AreaChartViz — gradient fill + target line + delta badge"`

---

### Task 11: GaugeViz

- [ ] Use `CustomPaint` with a `_GaugePainter` that draws a 180° arc.
  - Arc divided into colored zone segments (paint each `GaugeZone` as an arc slice).
  - Current value needle or filled arc up to current value.
  - Square: 80px wide arc, value text below, zone label.
  - Wide: 130px arc + value + zone labels along arc base.
  - Tall: 140px arc + value + zone table rows below.
- [ ] Commit: `"feat(data): add GaugeViz — semicircle arc with zone coloring, 3 sizes"`

---

### Task 12: SegmentedBarViz

- [ ] Implement a horizontal `Row` where each child's `flex` = `segment.value / totalValue`.
  - Square: 10px height bar + dot legend row (3 dots max to fit).
  - Wide: 16px bar + duration labels above each segment + full legend.
  - Tall: bar + `ListView` of per-segment rows (icon, label, value, mini progress bar).
- [ ] Commit: `"feat(data): add SegmentedBarViz — proportional segments, 3 sizes"`

---

### Task 13: FillGaugeViz

- [ ] Use `CustomPaint` drawing a rounded rectangle that fills from bottom by `value / maxValue`.
  - Square: 26×54px tank + value text to the right.
  - Wide: tank + value + icon grid (e.g. water glass emoji count if `unitSize` non-null: `(value / unitSize).floor()` filled icons).
  - Tall: 34×90px tank + value + 2×4 icon grid (filled/empty emoji).
- [ ] Commit: `"feat(data): add FillGaugeViz — fill-from-bottom tank, 3 sizes"`

---

### Task 14: DotRowViz

- [ ] Row of 7 `Container` circles. `opacity = invertedScale ? (1 - point.value) : point.value`. Today's dot: size 12 with glow ring (`BoxDecoration(boxShadow: [BoxShadow(...)])`), others size 9.
  - Square: 7 dots, today label above.
  - Wide: 7 dots + emoji per dot below, weekly note at bottom.
  - Tall: 7 dots + day labels + scrollable per-day list (emoji, label, date).
- [ ] Commit: `"feat(data): add DotRowViz — 7-day dots with opacity encoding, 3 sizes"`

---

### Task 15: CalendarGridViz

- [ ] Square: show current day number + phase label only (two `Text` widgets stacked).
  Wide: 28 dots in a single `Row` with `Wrap`. Today has glow ring. Phase color per dot.
  Tall: 4×7 grid using `GridView.count(crossAxisCount: 7)`, day numbers inside dots.
- [ ] Assert in debug builds: `assert(size != TileSize.square || config.days.isEmpty || true)` — CalendarGrid always renders something at square (StatCard fallback); no assertion needed here since the factory handles it.
- [ ] Commit: `"feat(data): add CalendarGridViz — phase-colored dot grid, 3 sizes"`

---

### Task 16: HeatmapViz

- [ ] Assert `size != TileSize.square` in debug build.
  Wide: 5-week × 7-day grid of colored cells. Each cell's color = `Color.lerp(colorLow, colorHigh, normalizedValue)`. Legend strip on right.
  Tall: same grid with slightly larger cells + legend at bottom.
  Square: debug assert fires; render `SizedBox.shrink()` in release.
- [ ] Commit: `"feat(data): add HeatmapViz — color-intensity calendar grid, wide + tall only"`

---

## Task 17: Rewrite buildTileVisualization Factory

**Files:**
- Modify: `lib/features/data/presentation/widgets/tile_visualizations.dart`

Now that all 12 viz widgets exist, replace the entire contents of `tile_visualizations.dart`.

- [ ] **Step 1: Write a test for the factory dispatch**

Add to `test/features/data/presentation/widgets/tile_visualizations_test.dart`:
```dart
testWidgets('factory returns BarChartViz for BarChartConfig', (tester) async {
  final config = BarChartConfig(bars: [], showAvgLine: false);
  final widget = buildTileVisualization(
    config: config,
    categoryColor: Colors.blue,
    size: TileSize.square,
  );
  expect(widget, isA<BarChartViz>());
});

testWidgets('factory returns StatCardViz for StatCardConfig', (tester) async {
  final config = StatCardConfig(value: '16', unit: 'bpm');
  final widget = buildTileVisualization(
    config: config,
    categoryColor: Colors.red,
    size: TileSize.wide,
  );
  expect(widget, isA<StatCardViz>());
});
```

- [ ] **Step 2: Run to confirm fail**

- [ ] **Step 3: Replace tile_visualizations.dart contents**

```dart
library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/area_chart_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/bar_chart_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/calendar_grid_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/dot_row_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/dual_value_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/fill_gauge_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/gauge_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/heatmap_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/line_chart_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/ring_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/segmented_bar_viz.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/stat_card_viz.dart';

/// Dispatches to the correct viz widget based on [config] type and [size].
Widget buildTileVisualization({
  required TileVisualizationConfig config,
  required Color categoryColor,
  required TileSize size,
}) {
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
}
```

- [ ] **Step 4: Fix all compile errors**

`tile_grid.dart` imports `tile_visualizations.dart` and references old subtypes (e.g. `BarChartData`, `RingData`) in `_buildTileContent` (around line 100). Temporarily make `_buildTileContent` skip the visualization type switch by returning a placeholder, so compilation succeeds:

In `tile_grid.dart`, find where `TileVisualizationData` subtypes are pattern-matched (to extract `primaryValue`). Replace the entire switch with:
```dart
// TODO(Task 18): this switch will be replaced when data_providers produces TileVisualizationConfig
final primaryValue = tile.primaryValue ?? '—';
```

Also update `tile_expanded_view.dart` (Task 19).

- [ ] **Step 5: Run tests**

```
flutter test test/features/data/presentation/widgets/tile_visualizations_test.dart
```
Expected: PASS.

- [ ] **Step 6: Compile check**

```
flutter analyze lib/features/data/
```
Expected: no errors (warnings ok).

- [ ] **Step 7: Commit**

```bash
git add lib/features/data/presentation/widgets/tile_visualizations.dart
git commit -m "feat(data): replace tile_visualizations.dart with new factory dispatching to 12 viz widgets"
```

---

## Task 18: Rewrite _buildTileViz in data_providers.dart

**Files:**
- Modify: `lib/features/data/providers/data_providers.dart:257-404`
- Test: `test/features/data/providers/data_providers_test.dart`

- [ ] **Step 1: Write failing tests**

Add to `test/features/data/providers/data_providers_test.dart`:
```dart
group('_buildTileViz produces correct config types', () {
  final emptySummary = CategorySummary(
    primaryValue: '0', unit: '', trend: null, deltaPercent: null,
  );

  test('steps with no goal → BarChartConfig', () {
    final config = buildTileVizForTest(TileId.steps, emptySummary, [], TileSize.square);
    expect(config, isA<BarChartConfig>());
  });

  test('bloodPressure → DualValueConfig', () {
    final summary = CategorySummary(primaryValue: '120/78', unit: 'mmHg');
    final config = buildTileVizForTest(TileId.bloodPressure, summary, [], TileSize.square);
    expect(config, isA<DualValueConfig>());
  });

  test('sleepStages → SegmentedBarConfig when stage data available', () { ... });

  test('vo2Max → GaugeConfig', () {
    final summary = CategorySummary(primaryValue: '45', unit: 'ml/kg/min');
    final config = buildTileVizForTest(TileId.vo2Max, summary, [], TileSize.square);
    expect(config, isA<GaugeConfig>());
  });

  // Test all 11 new TileId values return a non-null config
  for (final id in [
    TileId.distance, TileId.floorsClimbed, TileId.exerciseMinutes,
    TileId.walkingSpeed, TileId.runningPace, TileId.respiratoryRate,
    TileId.bodyTemperature, TileId.wristTemperature,
    TileId.macros, TileId.bloodGlucose, TileId.mindfulMinutes,
  ]) {
    test('$id returns non-null config', () {
      final config = buildTileVizForTest(id, emptySummary, [], TileSize.square);
      expect(config, isNotNull);
      expect(config, isA<TileVisualizationConfig>());
    });
  }
});
```

> **Note:** `_buildTileViz` is a private top-level function. Extract it as `@visibleForTesting buildTileVizForTest(...)` or make it package-private by moving it to its own file. Simplest: add `@visibleForTesting` annotation and import in test with `// ignore: invalid_use_of_visible_for_testing_member`.

- [ ] **Step 2: Run to confirm fail**

- [ ] **Step 3: Rewrite `_buildTileViz`**

Replace the existing function signature:
```dart
TileVisualizationData _buildTileViz(TileId id, CategorySummary summary, List<DailyGoal> goals)
```
with:
```dart
@visibleForTesting
TileVisualizationConfig buildTileVizForTest(
  TileId id, CategorySummary summary, List<DailyGoal> goals, TileSize size,
) => _buildTileViz(id, summary, goals, size);

TileVisualizationConfig _buildTileViz(
  TileId id,
  CategorySummary summary,
  List<DailyGoal> goals,
  TileSize size,
) {
```

Then update every `case` in the switch to return a `TileVisualizationConfig`. Follow the migration table in spec Section 13 and size-switching pattern in spec Section 13.

Key cases:

```dart
case TileId.steps:
  final goal = _stepsGoal(goals);
  return switch (size) {
    TileSize.square => goal != null
        ? RingConfig(value: _parseDouble(summary.primaryValue), maxValue: goal, unit: 'steps')
        : BarChartConfig(bars: _toBars(summary.trend), goalValue: goal),
    TileSize.wide || TileSize.tall =>
        BarChartConfig(bars: _toBars(summary.trend), goalValue: goal, showAvgLine: true),
  };

case TileId.bloodPressure:
  final parts = summary.primaryValue.split('/');
  if (parts.length == 2) {
    return DualValueConfig(
      value1: parts[0].trim(), label1: 'SYS',
      value2: parts[1].trim(), label2: 'DIA',
    );
  }
  return StatCardConfig(value: summary.primaryValue, unit: summary.unit ?? '');

case TileId.vo2Max:
  final v = _parseDouble(summary.primaryValue);
  return GaugeConfig(
    value: v, minValue: 0, maxValue: 70,
    zones: const [
      GaugeZone(min: 0,  max: 25, label: 'Poor',      color: Color(0xFFFF5252)),
      GaugeZone(min: 25, max: 35, label: 'Fair',       color: Color(0xFFFF9800)),
      GaugeZone(min: 35, max: 45, label: 'Good',       color: Color(0xFF4CAF50)),
      GaugeZone(min: 45, max: 55, label: 'Excellent',  color: Color(0xFF2196F3)),
      GaugeZone(min: 55, max: 70, label: 'Superior',   color: Color(0xFF9C27B0)),
    ],
  );

case TileId.sleepStages:
  // Requires stage data parsed by bridge (Task 23).
  // Falls back to StatCardConfig if stage data unavailable.
  final stages = summary.sleepStages; // new field on CategorySummary
  if (stages != null && stages.isNotEmpty) {
    return SegmentedBarConfig(
      segments: stages,
      totalLabel: summary.primaryValue,
    );
  }
  return StatCardConfig(value: summary.primaryValue, unit: summary.unit ?? '');

// New tiles:
case TileId.distance:
  return BarChartConfig(bars: _toBars(summary.trend));
case TileId.floorsClimbed:
  return BarChartConfig(bars: _toBars(summary.trend));
case TileId.exerciseMinutes:
  return switch (size) {
    TileSize.square => RingConfig(
        value: _parseDouble(summary.primaryValue), maxValue: 30, unit: 'min'),
    _ => BarChartConfig(bars: _toBars(summary.trend), goalValue: 30),
  };
case TileId.walkingSpeed:
  return LineChartConfig(points: _toPoints(summary.trend), positiveIsUp: true);
case TileId.runningPace:
  return LineChartConfig(points: _toPoints(summary.trend), positiveIsUp: false);
case TileId.respiratoryRate:
  return StatCardConfig(
    value: summary.primaryValue,
    unit: summary.unit ?? 'breaths/min',
    statusColor: Colors.green,
    statusLabel: 'Normal',
  );
case TileId.bodyTemperature:
  return LineChartConfig(points: _toPoints(summary.trend), positiveIsUp: false);
case TileId.wristTemperature:
  return LineChartConfig(points: _toPoints(summary.trend), positiveIsUp: false);
case TileId.macros:
  return SegmentedBarConfig(
    segments: _toMacroSegments(summary),
    totalLabel: summary.primaryValue,
  );
case TileId.bloodGlucose:
  return switch (size) {
    TileSize.square => GaugeConfig(
        value: _parseDouble(summary.primaryValue),
        minValue: 2.8, maxValue: 11.1,
        zones: const [
          GaugeZone(min: 2.8, max: 3.9, label: 'Low',    color: Color(0xFFFF5252)),
          GaugeZone(min: 3.9, max: 7.8, label: 'Normal', color: Color(0xFF4CAF50)),
          GaugeZone(min: 7.8, max: 11.1, label: 'High',  color: Color(0xFFFF9800)),
        ],
      ),
    _ => LineChartConfig(points: _toPoints(summary.trend), referenceLine: 7.8),
  };
case TileId.mindfulMinutes:
  return BarChartConfig(bars: _toBars(summary.trend));
```

Add private helpers below the function:
```dart
double _parseDouble(String? s) =>
    double.tryParse(s?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '') ?? 0;

List<BarPoint> _toBars(List<double>? trend) {
  if (trend == null || trend.isEmpty) return [];
  final labels = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  return List.generate(trend.length, (i) =>
    BarPoint(label: labels[i % labels.length], value: trend[i], isToday: i == trend.length - 1));
}

List<ChartPoint> _toPoints(List<double>? trend) {
  if (trend == null || trend.isEmpty) return [];
  final now = DateTime.now();
  return List.generate(trend.length, (i) =>
    ChartPoint(date: now.subtract(Duration(days: trend.length - 1 - i)), value: trend[i]));
}
```

- [ ] **Step 4: Update callers**

`_buildTileViz` is called in `dashboardTilesProvider`. Find the call site and add `size: tile.effectiveSize` (or pass `TileSize.square` as default until the provider has size information). Also update `tile_grid.dart`'s `_buildTileContent` to use the new config type.

- [ ] **Step 5: Run tests**

```
flutter test test/features/data/providers/data_providers_test.dart
flutter test test/features/data/
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/data/providers/data_providers.dart \
        test/features/data/providers/data_providers_test.dart
git commit -m "feat(data): rewrite _buildTileViz to produce TileVisualizationConfig for all 31 TileIds"
```

---

## Task 19: Update tile_expanded_view.dart Call Site

**Files:**
- Modify: `lib/features/data/presentation/widgets/tile_expanded_view.dart`

- [ ] **Step 1: Find the `buildTileVisualization` call** — search for it in the file.

- [ ] **Step 2: Update signature**

Old call: `buildTileVisualization(data: viz, categoryColor: color)`
New call: `buildTileVisualization(config: viz, categoryColor: color, size: effectiveExpandedSize)`

Where `effectiveExpandedSize`:
```dart
final effectiveExpandedSize =
    size == TileSize.square ? TileSize.tall : size;
```
Add this local variable just before the `buildTileVisualization` call. Never pass `TileSize.square` to the expanded view.

- [ ] **Step 3: Fix the type of `visualization` field**

If `tile_expanded_view.dart` stores a `TileVisualizationData? visualization` field, change it to `TileVisualizationConfig? visualization`. Update all call sites in `tile_grid.dart` and `metric_tile.dart` accordingly.

- [ ] **Step 4: Compile check + run tests**

```
flutter analyze lib/
flutter test test/features/data/
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/data/presentation/widgets/tile_expanded_view.dart
git commit -m "fix(data): update tile_expanded_view to new buildTileVisualization signature; never pass square size"
```

---

## Task 20: Delete Old TileVisualizationData

**Files:**
- Modify: `lib/features/data/domain/tile_models.dart` (remove 14 subtype classes, lines 79–263)

- [ ] **Step 1: Confirm no references remain**

```bash
grep -r 'TileVisualizationData\|BarChartData\|RingData\|LineChartData\|StackedBarData\|AreaChartData\|GaugeData\|ValueData\|DualValueData\|MacroBarsData\|FillGaugeData\|DotsData\|CountBadgeData\|CalendarDotsData\|EnvironmentData' lib/
```
Expected: 0 results (all replaced in previous tasks).

- [ ] **Step 2: Delete the sealed class block**

Remove lines 73–263 from `tile_models.dart` (the `TileVisualizationData` sealed class and all 14 subtypes).

- [ ] **Step 3: Compile + test**

```
flutter analyze lib/
flutter test test/features/data/
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/data/domain/tile_models.dart
git commit -m "chore(data): remove TileVisualizationData sealed class and 14 subtypes — replaced by TileVisualizationConfig"
```

---

## Task 21: iOS HealthKitBridge Additions

**File:** `ios/Runner/HealthKitBridge.swift`

- [ ] **Step 1: Add 15 new readTypes**

In the `readTypes` set (lines 21–39), add:
```swift
HKQuantityType(.walkingSpeed),
HKQuantityType(.bodyTemperature),
HKQuantityType(.appleSleepingWristTemperature),
HKQuantityType(.dietaryWater),
HKCategoryType(.menstrualFlow),
HKCategoryType(.intermenstrualBleeding),
HKCategoryType(.ovulationTestResult),
HKQuantityType(.basalBodyTemperature),
HKQuantityType(.walkingAsymmetryPercentage),
HKQuantityType(.walkingDoubleSupportPercentage),
HKQuantityType(.sixMinuteWalkTestDistance),
HKQuantityType(.dietaryProtein),
HKQuantityType(.dietaryCarbohydrates),
HKQuantityType(.dietaryFatTotal),
HKCategoryType(.mindfulSession),
```

- [ ] **Step 2: Add `blood_pressure` observer case**

Find `func notifyOfChange(_ identifier: String)` (or equivalent background observer dispatcher). Add:
```swift
case "blood_pressure":
    readBloodPressure { result in
        self.postToFlutter("blood_pressure", payload: result)
    }
```

- [ ] **Step 3: Add read methods**

Add the following methods to `HealthKitBridge`. Pattern: query `HKStatisticsQuery` for quantity types, `HKSampleQuery` for category types, call the completion with a `[String: Any]` dict.

```swift
func getWalkingSpeed(date: Date, completion: @escaping ([String: Any]?) -> Void) {
    let type = HKQuantityType(.walkingSpeed)
    queryDaily(type: type, date: date, unit: HKUnit.meter().unitDivided(by: .second())) { value in
        completion(value.map { ["walking_speed_mps": $0] })
    }
}

func getBodyTemperature(date: Date, completion: @escaping ([String: Any]?) -> Void) {
    let type = HKQuantityType(.bodyTemperature)
    queryLatest(type: type, unit: .degreeCelsius()) { value in
        completion(value.map { ["body_temperature_celsius": $0] })
    }
}

func getWristTemperature(completion: @escaping ([String: Any]?) -> Void) {
    let type = HKQuantityType(.appleSleepingWristTemperature)
    queryLatest(type: type, unit: .degreeCelsius()) { value in
        completion(value.map { ["wrist_temperature_deviation": $0] })
    }
}

func getWater(date: Date, completion: @escaping ([String: Any]?) -> Void) {
    let type = HKQuantityType(.dietaryWater)
    queryDaily(type: type, date: date, unit: .liter()) { value in
        completion(value.map { ["water_liters": $0] })
    }
}

func getMindfulMinutes(date: Date, completion: @escaping ([String: Any]?) -> Void) {
    let type = HKCategoryType(.mindfulSession)
    queryCategoryDurationSum(type: type, date: date) { minutes in
        completion(minutes.map { ["mindful_minutes": $0] })
    }
}

func getCycleData(startDate: Date, endDate: Date, completion: @escaping ([[String: Any]]) -> Void) {
    let type = HKCategoryType(.menstrualFlow)
    queryCategorySamples(type: type, startDate: startDate, endDate: endDate) { samples in
        let result = samples.map { sample -> [String: Any] in
            let flow = (sample as? HKCategorySample)?.value ?? 0
            return [
                "date": sample.startDate.timeIntervalSince1970 * 1000,
                "cycle_flow_intensity": flow,
            ]
        }
        completion(result)
    }
}

func getWalkingMetrics(completion: @escaping ([String: Any?]) -> Void) {
    let asymmetryType = HKQuantityType(.walkingAsymmetryPercentage)
    queryLatest(type: asymmetryType, unit: .percent()) { asymmetry in
        completion(["walking_asymmetry_pct": asymmetry])
    }
}

func getNutrition(date: Date, completion: @escaping ([String: Any?]) -> Void) {
    let types: [(HKQuantityTypeIdentifier, String, HKUnit)] = [
        (.dietaryEnergyConsumed,  "nutrition_calories",  .kilocalorie()),
        (.dietaryProtein,         "nutrition_protein_g", .gram()),
        (.dietaryCarbohydrates,   "nutrition_carbs_g",   .gram()),
        (.dietaryFatTotal,        "nutrition_fat_g",     .gram()),
        (.dietaryFiber,           "nutrition_fiber_g",   .gram()),
    ]
    var result: [String: Any?] = [:]
    let group = DispatchGroup()
    for (typeId, key, unit) in types {
        group.enter()
        queryDaily(type: HKQuantityType(typeId), date: date, unit: unit) { value in
            result[key] = value
            group.leave()
        }
    }
    group.notify(queue: .main) { completion(result) }
}
```

> **Note:** `queryDaily`, `queryLatest`, `queryCategoryDurationSum`, `queryCategorySamples` should already exist as private helpers in HealthKitBridge.swift (they are the standard HK query patterns used by existing methods). Reuse them. If they don't exist, implement using `HKStatisticsQuery` (cumulative sum for daily totals) and `HKSampleQuery` (most recent sample for point-in-time values).

- [ ] **Step 4: Wire new methods to the channel handler**

In `AppDelegate.swift` (or wherever the `MethodChannel` switch is), add cases:
```swift
case "getWalkingSpeed": ...
case "getBodyTemperature": ...
case "getWristTemperature": ...
case "getWater": ...
case "getMindfulMinutes": ...
case "getCycleData": ...
case "getWalkingMetrics": ...
case "getNutrition": ...  // replaces old "getNutritionCalories"
```

- [ ] **Step 5: Build iOS to check for Swift compile errors**

```bash
cd zuralog && flutter build ios --no-codesign 2>&1 | head -50
```
Expected: no Swift compile errors (linker errors ok without device).

- [ ] **Step 6: Commit**

```bash
git add ios/Runner/HealthKitBridge.swift ios/Runner/AppDelegate.swift
git commit -m "feat(ios): add 15 new HealthKit readTypes + 8 bridge methods for new tiles"
```

---

## Task 22: Android HealthConnectBridge Additions

**File:** `android/app/src/main/kotlin/com/zuralog/zuralog/HealthConnectBridge.kt`

- [ ] **Step 1: Add import statements**

At the top of the file, add:
```kotlin
import androidx.health.connect.client.records.BodyTemperatureRecord
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.MenstruationFlowRecord
import androidx.health.connect.client.records.MindfulnessSessionRecord
import androidx.health.connect.client.records.OvulationTestRecord
import androidx.health.connect.client.records.BloodGlucoseRecord
import androidx.health.connect.client.units.Volume
import androidx.health.connect.client.units.Temperature
```

- [ ] **Step 2: Add new permissions to REQUIRED_PERMISSIONS**

```kotlin
HealthPermission.getReadPermission(HydrationRecord::class),
HealthPermission.getReadPermission(MenstruationFlowRecord::class),
HealthPermission.getReadPermission(OvulationTestRecord::class),
HealthPermission.getReadPermission(BodyTemperatureRecord::class),
HealthPermission.getReadPermission(MindfulnessSessionRecord::class),
HealthPermission.getReadPermission(BloodGlucoseRecord::class),
```

- [ ] **Step 3: Add read methods**

```kotlin
suspend fun readWater(date: LocalDate): Double? {
    val start = date.atStartOfDay(ZoneId.systemDefault()).toInstant()
    val end = date.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant()
    val request = ReadRecordsRequest(
        recordType = HydrationRecord::class,
        timeRangeFilter = TimeRangeFilter.between(start, end),
    )
    val records = healthConnectClient.readRecords(request).records
    return records.sumOf { it.volume.inLiters }.takeIf { it > 0 }
}

suspend fun readBodyTemperature(date: LocalDate): Double? {
    val start = date.atStartOfDay(ZoneId.systemDefault()).toInstant()
    val end = date.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant()
    val request = ReadRecordsRequest(
        recordType = BodyTemperatureRecord::class,
        timeRangeFilter = TimeRangeFilter.between(start, end),
    )
    return healthConnectClient.readRecords(request).records.lastOrNull()
        ?.temperature?.inCelsius
}

suspend fun readMindfulMinutes(date: LocalDate): Double? {
    val start = date.atStartOfDay(ZoneId.systemDefault()).toInstant()
    val end = date.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant()
    val request = ReadRecordsRequest(
        recordType = MindfulnessSessionRecord::class,
        timeRangeFilter = TimeRangeFilter.between(start, end),
    )
    val records = healthConnectClient.readRecords(request).records
    val totalSeconds = records.sumOf {
        java.time.Duration.between(it.startTime, it.endTime).seconds
    }
    return if (totalSeconds > 0) totalSeconds / 60.0 else null
}

suspend fun readCycleData(startDate: LocalDate, endDate: LocalDate): List<Map<String, Any>> {
    val start = startDate.atStartOfDay(ZoneId.systemDefault()).toInstant()
    val end = endDate.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant()
    val request = ReadRecordsRequest(
        recordType = MenstruationFlowRecord::class,
        timeRangeFilter = TimeRangeFilter.between(start, end),
    )
    return healthConnectClient.readRecords(request).records.map { record ->
        mapOf(
            "date" to record.time.toEpochMilli(),
            "cycle_flow_intensity" to (record.flow?.ordinal ?: 0),
        )
    }
}

suspend fun readBloodGlucose(date: LocalDate): Double? {
    val start = date.atStartOfDay(ZoneId.systemDefault()).toInstant()
    val end = date.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant()
    val request = ReadRecordsRequest(
        recordType = BloodGlucoseRecord::class,
        timeRangeFilter = TimeRangeFilter.between(start, end),
    )
    return healthConnectClient.readRecords(request).records.lastOrNull()
        ?.level?.inMillimolesPerLiter
}

// Update existing readNutrition to include macros:
suspend fun readNutrition(date: LocalDate): Map<String, Double?> {
    val start = date.atStartOfDay(ZoneId.systemDefault()).toInstant()
    val end = date.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant()
    val request = ReadRecordsRequest(
        recordType = NutritionRecord::class,
        timeRangeFilter = TimeRangeFilter.between(start, end),
    )
    val records = healthConnectClient.readRecords(request).records
    return mapOf(
        "nutrition_calories"  to records.mapNotNull { it.energy?.inKilocalories }.sum().takeIf { it > 0 },
        "nutrition_protein_g" to records.mapNotNull { it.protein?.inGrams }.sum().takeIf { it > 0 },
        "nutrition_carbs_g"   to records.mapNotNull { it.totalCarbohydrate?.inGrams }.sum().takeIf { it > 0 },
        "nutrition_fat_g"     to records.mapNotNull { it.totalFat?.inGrams }.sum().takeIf { it > 0 },
    )
}
```

- [ ] **Step 4: Wire new methods in MainActivity.kt**

Find the when-block that routes method channel calls. Add:
```kotlin
"getWater"          -> result.success(bridge.readWater(today))
"getBodyTemperature"-> result.success(bridge.readBodyTemperature(today))
"getMindfulMinutes" -> result.success(bridge.readMindfulMinutes(today))
"getCycleData"      -> result.success(bridge.readCycleData(rangeStart, today))
"getBloodGlucose"   -> result.success(bridge.readBloodGlucose(today))
"getNutrition"      -> result.success(bridge.readNutrition(today))
```

- [ ] **Step 5: Build Android**

```bash
cd zuralog && flutter build apk --debug 2>&1 | tail -20
```
Expected: BUILD SUCCESSFUL (or only packaging errors, not Kotlin compile errors).

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/zuralog/zuralog/HealthConnectBridge.kt \
        android/app/src/main/kotlin/com/zuralog/zuralog/MainActivity.kt
git commit -m "feat(android): add HydrationRecord, BodyTemperatureRecord, MindfulnessSessionRecord, MenstruationFlowRecord, BloodGlucoseRecord + readNutrition macros"
```

---

## Task 23: Flutter health_bridge.dart + HealthRepository wrappers + health_sync_service.dart

**Files:**
- Modify: `lib/core/health/health_bridge.dart`
- Modify: `lib/features/health/data/health_repository.dart`
- Modify: `lib/features/health/data/health_sync_service.dart`

- [ ] **Step 1: Add 8 new methods to health_bridge.dart**

Following the existing pattern (invokes method channel, catches `PlatformException`, returns null on error):

```dart
Future<double?> getWater(DateTime date) async {
  try {
    final result = await _channel.invokeMethod<num>('getWater', {
      'date': date.millisecondsSinceEpoch,
    });
    return result?.toDouble();
  } on PlatformException {
    return null;
  }
}

Future<double?> getBodyTemperature(DateTime date) async {
  try {
    final result = await _channel.invokeMethod<num>('getBodyTemperature', {
      'date': date.millisecondsSinceEpoch,
    });
    return result?.toDouble();
  } on PlatformException {
    return null;
  }
}

Future<double?> getWristTemperature() async {
  try {
    final result = await _channel.invokeMethod<num>('getWristTemperature');
    return result?.toDouble();
  } on PlatformException {
    return null;
  }
}

Future<double?> getWalkingSpeed(DateTime date) async {
  try {
    final result = await _channel.invokeMethod<num>('getWalkingSpeed', {
      'date': date.millisecondsSinceEpoch,
    });
    return result?.toDouble();
  } on PlatformException {
    return null;
  }
}

Future<double?> getMindfulMinutes(DateTime date) async {
  try {
    final result = await _channel.invokeMethod<num>('getMindfulMinutes', {
      'date': date.millisecondsSinceEpoch,
    });
    return result?.toDouble();
  } on PlatformException {
    return null;
  }
}

Future<List<Map<String, dynamic>>> getCycleData(DateTime start, DateTime end) async {
  try {
    final result = await _channel.invokeMethod<List<dynamic>>('getCycleData', {
      'startDate': start.millisecondsSinceEpoch,
      'endDate': end.millisecondsSinceEpoch,
    });
    return (result ?? []).cast<Map<String, dynamic>>();
  } on PlatformException {
    return [];
  }
}

Future<Map<String, dynamic>?> getNutrition(DateTime date) async {
  try {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getNutrition', {
      'date': date.millisecondsSinceEpoch,
    });
    return result?.cast<String, dynamic>();
  } on PlatformException {
    return null;
  }
}

Future<Map<String, double?>?> getWalkingMetrics() async {
  try {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getWalkingMetrics');
    return result?.cast<String, double?>();
  } on PlatformException {
    return null;
  }
}
```

Also update `getNutritionCalories` → delegates to `getNutrition` for backward compat or remove if no other callers exist.

- [ ] **Step 2: Add thin wrapper methods to HealthRepository**

Open `lib/features/health/data/health_repository.dart`. Find the existing pattern (each method calls the corresponding `_bridge` method). Add the following wrappers in the same style:

```dart
Future<double?> getWater(DateTime date) => _bridge.getWater(date);
Future<double?> getBodyTemperature(DateTime date) => _bridge.getBodyTemperature(date);
Future<double?> getWristTemperature() => _bridge.getWristTemperature();
Future<double?> getWalkingSpeed(DateTime date) => _bridge.getWalkingSpeed(date);
Future<double?> getMindfulMinutes(DateTime date) => _bridge.getMindfulMinutes(date);
Future<List<Map<String, dynamic>>> getCycleData(DateTime start, DateTime end) =>
    _bridge.getCycleData(start, end);
Future<Map<String, dynamic>?> getNutrition(DateTime date) => _bridge.getNutrition(date);
Future<Map<String, double?>?> getWalkingMetrics() => _bridge.getWalkingMetrics();
```

Compile check: `flutter analyze lib/features/health/`

- [ ] **Step 3: Add new sync payload keys to health_sync_service.dart**

Find the `daily_metrics` map construction in `syncToCloud`. Add:

```dart
// Blood pressure (bug fix — was fetched but never sent)
final bp = await _healthRepo.getBloodPressure(today);
if (bp != null) {
  dailyMetrics['blood_pressure_systolic'] = bp['systolic'];
  dailyMetrics['blood_pressure_diastolic'] = bp['diastolic'];
}

// Water
final water = await _healthRepo.getWater(today);
if (water != null) dailyMetrics['water_liters'] = water;

// Body temperature
final bodyTemp = await _healthRepo.getBodyTemperature(today);
if (bodyTemp != null) dailyMetrics['body_temperature_celsius'] = bodyTemp;

// Wrist temperature
final wristTemp = await _healthRepo.getWristTemperature();
if (wristTemp != null) dailyMetrics['wrist_temperature_deviation'] = wristTemp;

// Walking speed
final walkingSpeed = await _healthRepo.getWalkingSpeed(today);
if (walkingSpeed != null) dailyMetrics['walking_speed_mps'] = walkingSpeed;

// Mindful minutes
final mindfulMin = await _healthRepo.getMindfulMinutes(today);
if (mindfulMin != null) dailyMetrics['mindful_minutes'] = mindfulMin;

// Nutrition macros (extends existing nutrition call)
final nutrition = await _healthRepo.getNutrition(today);
if (nutrition != null) {
  if (nutrition['nutrition_calories'] != null)  dailyMetrics['nutrition_calories']  = nutrition['nutrition_calories'];
  if (nutrition['nutrition_protein_g'] != null) dailyMetrics['nutrition_protein_g'] = nutrition['nutrition_protein_g'];
  if (nutrition['nutrition_carbs_g'] != null)   dailyMetrics['nutrition_carbs_g']   = nutrition['nutrition_carbs_g'];
  if (nutrition['nutrition_fat_g'] != null)     dailyMetrics['nutrition_fat_g']     = nutrition['nutrition_fat_g'];
  if (nutrition['nutrition_fiber_g'] != null)   dailyMetrics['nutrition_fiber_g']   = nutrition['nutrition_fiber_g'];
}

// Cycle data (multi-field, per spec §9.6) — today's entry is last
final cycleData = await _healthRepo.getCycleData(rangeStart, today);
if (cycleData.isNotEmpty) {
  final todayEntry = cycleData.last;
  dailyMetrics['cycle_phase'] = todayEntry['cycle_phase'] ?? 'unknown';
  dailyMetrics['cycle_flow_intensity'] = todayEntry['cycle_flow_intensity'] ?? 0;
  dailyMetrics['cycle_day'] = cycleData.length; // day number within current cycle
}

// Running pace (per spec §9.5) — derived from most recent running workout
final workouts = await _healthRepo.getWorkouts(rangeStart, today);
final latestRun = workouts
    .where((w) => (w['type'] as String?)?.toLowerCase().contains('run') == true
               && (w['distance'] as num?) != null
               && (w['duration'] as num?) != null)
    .lastOrNull;
if (latestRun != null) {
  final distM = (latestRun['distance'] as num).toDouble();
  final durS  = (latestRun['duration'] as num).toDouble();
  if (durS > 0) dailyMetrics['running_pace_mps'] = distM / durS;
}

```

- [ ] **Step 3: Run tests**

```
flutter test test/features/data/
flutter analyze lib/
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/health/health_bridge.dart \
        lib/features/health/data/health_sync_service.dart
git commit -m "feat(health): add 8 new bridge methods; wire blood pressure, water, macros, cycle, temperature, walking speed, mindful minutes to sync payload"
```

---

## Task 24: Blood Pressure Sync Bug Fix (Critical)

This is a targeted fix separate from the new bridge methods.

**File:** `lib/features/health/data/health_sync_service.dart`

- [ ] **Step 1: Locate the existing `getBloodPressure()` call**

Search: `grep -n 'getBloodPressure\|blood_pressure' lib/features/health/data/health_sync_service.dart`

You will find the call exists but the result is never added to `daily_metrics`.

- [ ] **Step 2: Add result to payload**

The fix is already included in Task 23 Step 2 above. Confirm that:
```dart
dailyMetrics['blood_pressure_systolic'] = bp['systolic'];
dailyMetrics['blood_pressure_diastolic'] = bp['diastolic'];
```
is present as flat keys (NOT a nested `blood_pressure: {...}` map).

- [ ] **Step 3: Fix iOS observer**

In `HealthKitBridge.swift`, find `notifyOfChange()`. Add the `blood_pressure` case (already done in Task 21 Step 2).

- [ ] **Step 4: Commit if not already committed in Task 23**

```bash
git add lib/features/health/data/health_sync_service.dart
git commit -m "fix(health): blood pressure sync bug — add systolic/diastolic flat keys to sync payload"
```

---

## Task 25: Sleep Stage Parsing Fix

**Files:**
- Modify: `lib/core/health/health_bridge.dart` — `getSleep()` return format
- Modify: `lib/features/data/providers/data_providers.dart` — parse stages

- [ ] **Step 1: Update getSleep() to include parsed stage key**

In `health_bridge.dart`, find `getSleep()`. The raw result from the channel is a `List<Map>` where each map has a `value` field encoding the stage. Add parsing:

```dart
Future<List<Map<String, dynamic>>> getSleep(DateTime start, DateTime end) async {
  try {
    final raw = await _channel.invokeMethod<List<dynamic>>('getSleep', {
      'startDate': start.millisecondsSinceEpoch,
      'endDate': end.millisecondsSinceEpoch,
    });
    final segments = (raw ?? []).cast<Map<dynamic, dynamic>>();
    return segments.map((s) {
      final map = Map<String, dynamic>.from(s);
      // Parse iOS HKCategoryValueSleepAnalysis int or Android StageType string
      // into a normalized stage key
      final rawValue = map['value'];
      map['stage'] = _parseSleepStage(rawValue);
      return map;
    }).toList();
  } on PlatformException {
    return [];
  }
}

String _parseSleepStage(dynamic value) {
  if (value is String) {
    // Android: StageType enum name
    return switch (value.toLowerCase()) {
      'deep'   => 'deep',
      'rem'    => 'rem',
      'light'  => 'light',
      'awake'  => 'awake',
      _        => 'inBed',
    };
  }
  if (value is int) {
    // iOS: HKCategoryValueSleepAnalysis raw int
    // 0=inBed, 1=asleepUnspecified, 5=awake, 6=asleepCore(light), 7=asleepDeep, 8=asleepREM
    return switch (value) {
      5 => 'awake',
      6 => 'light',
      7 => 'deep',
      8 => 'rem',
      _ => 'inBed',
    };
  }
  return 'inBed';
}
```

- [ ] **Step 2: In data_providers.dart, group sleep segments by stage**

In `_buildTileViz` for `TileId.sleepStages`, use the stage data:
```dart
case TileId.sleepStages:
  final stages = summary.sleepStages; // populated from grouped segments
  if (stages != null && stages.isNotEmpty) {
    return SegmentedBarConfig(segments: stages, totalLabel: summary.primaryValue);
  }
  return StatCardConfig(value: summary.primaryValue, unit: 'hrs');
```

The `CategorySummary` model may need a `sleepStages: List<Segment>?` field added. If it doesn't have this field, check `CategorySummary` definition and add the field.

- [ ] **Step 3: Run tests + commit**

```
flutter test test/features/data/
git add lib/core/health/health_bridge.dart lib/features/data/providers/data_providers.dart
git commit -m "fix(health): parse sleep stage from native bridge value field; populate SegmentedBarConfig for sleepStages tile"
```

---

## Final Verification

- [ ] **Run full test suite**

```
flutter test
```
Expected: all tests pass.

- [ ] **Analyze for lint errors**

```
flutter analyze
```
Expected: 0 errors (warnings acceptable).

- [ ] **Check for any remaining references to old types**

```bash
grep -r 'TileVisualizationData\|BarChartData\|RingData\|buildTileVisualization.*data:' lib/
```
Expected: 0 results.

- [ ] **Build iOS and Android**

```bash
flutter build ios --no-codesign
flutter build apk --debug
```
Expected: both succeed.

- [ ] **Final commit**

```bash
git commit -m "chore(data): final cleanup — all tests passing, no old viz type references"
```
