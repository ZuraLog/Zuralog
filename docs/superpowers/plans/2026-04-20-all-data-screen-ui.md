# All-Data Screen UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shared `AllDataScreen` widget and wire it into `SleepAllDataScreen` and `NutritionAllDataScreen`, backed by mock data, with full paywall gating on time depth and placeholder benchmark/distribution sections.

**Architecture:** A generic `AllDataScreen` (`ConsumerStatefulWidget`) owns all UI state (selected tab, selected range) and renders tabs, chart, time range selector, paywall prompt, and two placeholder cards. Section-specific screens (`SleepAllDataScreen`, `NutritionAllDataScreen`) are thin `ConsumerWidget`s that construct an `AllDataSectionConfig` (including a `fetchData` closure wired to the repo obtained via `ref.read`) and pass it to `AllDataScreen`. Data loading uses `FutureBuilder` inside `AllDataScreen` so no extra family providers are needed.

**Tech Stack:** Flutter, Riverpod 2.0, GoRouter, `BarRenderer` + `LineRenderer` + `ChartRenderContext` from `shared/widgets/charts/`, `isPremiumProvider` from subscription, `USE_MOCK_DATA` compile-time flag.

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Create | `zuralog/lib/shared/all_data/all_data_models.dart` | `AllDataDay`, `AllDataSectionConfig`, `AllDataMetricTab`, `AllDataChartType` |
| Modify | `zuralog/lib/features/sleep/data/sleep_repository_interface.dart` | Add `getSleepAllData(String range)` |
| Modify | `zuralog/lib/features/sleep/data/mock_sleep_repository.dart` | Implement `getSleepAllData` with 7-day mock fixture |
| Modify | `zuralog/lib/features/sleep/data/api_sleep_repository.dart` | Add stub `getSleepAllData` (throws `UnimplementedError`) |
| Modify | `zuralog/lib/features/nutrition/data/nutrition_repository_interface.dart` | Add `getNutritionAllData(String range)` |
| Modify | `zuralog/lib/features/nutrition/data/mock_nutrition_repository.dart` | Implement `getNutritionAllData` with 7-day mock fixture |
| Modify | `zuralog/lib/features/nutrition/data/api_nutrition_repository.dart` | Add stub `getNutritionAllData` (throws `UnimplementedError`) |
| Create | `zuralog/lib/shared/all_data/all_data_screen.dart` | Shared base screen |
| Create | `zuralog/lib/features/sleep/presentation/all_data/sleep_all_data_screen.dart` | Sleep config + screen entry point |
| Create | `zuralog/lib/features/nutrition/presentation/all_data/nutrition_all_data_screen.dart` | Nutrition config + screen entry point |
| Modify | `zuralog/lib/core/router/route_names.dart` | Add `sleepAllData` + `nutritionAllData` routes |
| Modify | `zuralog/lib/core/router/app_router.dart` | Register new routes |
| Modify | `zuralog/lib/features/sleep/presentation/sleep_detail_screen.dart` | Add "View All Data →" row after `SleepTrendSection` |
| Modify | `zuralog/lib/features/nutrition/presentation/nutrition_home_screen.dart` | Replace SnackBar placeholder with real navigation |
| Create | `zuralog/test/shared/all_data/all_data_models_test.dart` | Unit tests for model constructors and `AllDataSectionConfig` |
| Create | `zuralog/test/features/sleep/data/mock_sleep_all_data_test.dart` | Tests for `MockSleepRepository.getSleepAllData` |
| Create | `zuralog/test/features/nutrition/data/mock_nutrition_all_data_test.dart` | Tests for `MockNutritionRepository.getNutritionAllData` |

---

### Task 1: AllData domain models

**Files:**
- Create: `zuralog/lib/shared/all_data/all_data_models.dart`
- Create: `zuralog/test/shared/all_data/all_data_models_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// zuralog/test/shared/all_data/all_data_models_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';

void main() {
  group('AllDataDay', () {
    test('stores values by metric id', () {
      final day = AllDataDay(
        date: '2026-04-20',
        isToday: true,
        values: {'duration': 420.0, 'quality': 4.0, 'deep_sleep': null},
      );
      expect(day.date, '2026-04-20');
      expect(day.isToday, isTrue);
      expect(day.values['duration'], 420.0);
      expect(day.values['deep_sleep'], isNull);
    });
  });

  group('AllDataChartType', () {
    test('has bar and line values', () {
      expect(AllDataChartType.values, contains(AllDataChartType.bar));
      expect(AllDataChartType.values, contains(AllDataChartType.line));
    });
  });

  group('AllDataMetricTab', () {
    test('valueExtractor returns value from AllDataDay', () {
      final day = AllDataDay(
        date: '2026-04-20',
        isToday: false,
        values: {'calories': 1850.0},
      );
      final tab = AllDataMetricTab(
        id: 'calories',
        label: 'Calories',
        chartType: AllDataChartType.bar,
        unit: 'kcal',
        valueExtractor: (d) => d.values['calories'],
      );
      expect(tab.valueExtractor(day), 1850.0);
    });

    test('emptyStateSource defaults to null', () {
      final tab = AllDataMetricTab(
        id: 'duration',
        label: 'Duration',
        chartType: AllDataChartType.bar,
        unit: 'h',
        valueExtractor: (d) => d.values['duration'],
      );
      expect(tab.emptyStateSource, isNull);
    });
  });

  group('AllDataSectionConfig', () {
    test('holds all required fields', () {
      final config = AllDataSectionConfig(
        sectionTitle: 'Sleep',
        categoryColor: Colors.indigo,
        tabs: [],
        fetchData: (_) async => [],
      );
      expect(config.sectionTitle, 'Sleep');
      expect(config.tabs, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the test to confirm it fails**

```
cd zuralog
flutter test test/shared/all_data/all_data_models_test.dart
```

Expected: FAIL — `all_data_models.dart` does not exist.

- [ ] **Step 3: Create the models file**

```dart
// zuralog/lib/shared/all_data/all_data_models.dart
library;

import 'package:flutter/material.dart';

enum AllDataChartType { bar, line }

/// One day of data for the All-Data screen. Values are keyed by metric id
/// (e.g. 'duration', 'calories'). A null value means no data for that metric
/// on that day.
class AllDataDay {
  const AllDataDay({
    required this.date,
    required this.isToday,
    required this.values,
  });

  final String date;
  final bool isToday;
  final Map<String, double?> values;
}

/// Describes a single metric tab on the All-Data screen.
class AllDataMetricTab {
  const AllDataMetricTab({
    required this.id,
    required this.label,
    required this.chartType,
    required this.unit,
    required this.valueExtractor,
    this.emptyStateSource,
  });

  final String id;
  final String label;
  final AllDataChartType chartType;

  /// Unit suffix displayed on chart axes (e.g. 'h', 'kcal', 'bpm', '%').
  final String unit;

  /// Pulls this tab's value from a day row.
  final double? Function(AllDataDay day) valueExtractor;

  /// Human-readable data source prompt shown when the user has no data for
  /// this metric (e.g. 'Connect a wearable'). Null means generic empty state.
  final String? emptyStateSource;
}

/// All configuration that varies per section. Passed into [AllDataScreen] by
/// each section-specific entry point (e.g. [SleepAllDataScreen]).
class AllDataSectionConfig {
  const AllDataSectionConfig({
    required this.sectionTitle,
    required this.categoryColor,
    required this.tabs,
    required this.fetchData,
  });

  final String sectionTitle;
  final Color categoryColor;
  final List<AllDataMetricTab> tabs;

  /// Fetches per-day rows for the given range string ('7d', '30d', '3m',
  /// '6m', '1y'). Called by [AllDataScreen] whenever the range changes.
  final Future<List<AllDataDay>> Function(String range) fetchData;
}
```

- [ ] **Step 4: Run the test to confirm it passes**

```
flutter test test/shared/all_data/all_data_models_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

Use the `git` subagent:
```
git add zuralog/lib/shared/all_data/all_data_models.dart \
        zuralog/test/shared/all_data/all_data_models_test.dart
git commit -m "feat(all-data): add AllDataDay, AllDataMetricTab, AllDataSectionConfig models"
```

---

### Task 2: Sleep repository — getSleepAllData

**Files:**
- Modify: `zuralog/lib/features/sleep/data/sleep_repository_interface.dart`
- Modify: `zuralog/lib/features/sleep/data/mock_sleep_repository.dart`
- Modify: `zuralog/lib/features/sleep/data/api_sleep_repository.dart`
- Create: `zuralog/test/features/sleep/data/mock_sleep_all_data_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// zuralog/test/features/sleep/data/mock_sleep_all_data_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/sleep/data/mock_sleep_repository.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';

void main() {
  late MockSleepRepository repo;

  setUp(() => repo = MockSleepRepository());

  group('MockSleepRepository.getSleepAllData', () {
    test('7d returns 7 days', () async {
      final days = await repo.getSleepAllData('7d');
      expect(days.length, 7);
    });

    test('each day has a non-empty values map', () async {
      final days = await repo.getSleepAllData('7d');
      for (final day in days) {
        expect(day.values, isNotEmpty);
      }
    });

    test('today entry has isToday = true', () async {
      final days = await repo.getSleepAllData('7d');
      final todayDays = days.where((d) => d.isToday).toList();
      expect(todayDays.length, 1);
    });

    test('duration values are in minutes (nullable)', () async {
      final days = await repo.getSleepAllData('7d');
      for (final day in days) {
        final dur = day.values['duration'];
        if (dur != null) {
          expect(dur, greaterThan(0));
          expect(dur, lessThan(900)); // < 15 hours
        }
      }
    });

    test('throws ArgumentError for unknown range', () async {
      await expectLater(
        () => repo.getSleepAllData('invalid'),
        throwsArgumentError,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to confirm it fails**

```
flutter test test/features/sleep/data/mock_sleep_all_data_test.dart
```

Expected: FAIL — `getSleepAllData` does not exist on the interface.

- [ ] **Step 3: Add `getSleepAllData` to the interface**

Open `zuralog/lib/features/sleep/data/sleep_repository_interface.dart`. Replace the entire file:

```dart
// zuralog/lib/features/sleep/data/sleep_repository_interface.dart
library;

import 'package:zuralog/features/sleep/domain/sleep_models.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';

abstract interface class SleepRepositoryInterface {
  Future<SleepDaySummary> getSleepSummary();
  Future<List<SleepTrendDay>> getSleepTrend(String range);

  /// Returns per-day rows for every sleep metric. Valid range values:
  /// '7d', '30d', '3m', '6m', '1y'. Throws [ArgumentError] for unknown ranges.
  Future<List<AllDataDay>> getSleepAllData(String range);
}
```

- [ ] **Step 4: Implement in MockSleepRepository**

Read `zuralog/lib/features/sleep/data/mock_sleep_repository.dart` first. Add the following method. The metric ids match the `AllDataMetricTab` ids used in `SleepAllDataScreen` (Task 5): `'duration'`, `'quality'`, `'deep_sleep'`, `'rem'`, `'light_sleep'`, `'heart_rate'`, `'efficiency'`.

Add after the closing brace of `getSleepTrend`:

```dart
  @override
  Future<List<AllDataDay>> getSleepAllData(String range) async {
    if (range != '7d' && range != '30d' && range != '3m' &&
        range != '6m' && range != '1y') {
      throw ArgumentError.value(range, 'range', 'Unknown range');
    }
    final now = DateTime.now();
    // For mock purposes always return 7 days regardless of range.
    const count = 7;
    return List.generate(count, (i) {
      final date = now.subtract(Duration(days: count - 1 - i));
      final isToday = i == count - 1;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (isToday) {
        // Today has no sleep data yet.
        return AllDataDay(
          date: dateStr,
          isToday: true,
          values: {
            'duration': null,
            'quality': null,
            'deep_sleep': null,
            'rem': null,
            'light_sleep': null,
            'heart_rate': null,
            'efficiency': null,
          },
        );
      }
      final seed = i + 1;
      final duration = 380.0 + (seed % 3) * 20; // 380–420 min
      return AllDataDay(
        date: dateStr,
        isToday: false,
        values: {
          'duration': duration,
          'quality': (3.0 + (seed % 3)).clamp(1.0, 5.0),
          'deep_sleep': duration * 0.20,
          'rem': duration * 0.22,
          'light_sleep': duration * 0.58,
          'heart_rate': 55.0 + (seed % 4),
          'efficiency': 82.0 + (seed % 6),
        },
      );
    });
  }
```

Also add the import at the top of `mock_sleep_repository.dart`:
```dart
import 'package:zuralog/shared/all_data/all_data_models.dart';
```

- [ ] **Step 5: Add stub to ApiSleepRepository**

Read `zuralog/lib/features/sleep/data/api_sleep_repository.dart`. Add to the class:

```dart
  @override
  Future<List<AllDataDay>> getSleepAllData(String range) =>
      throw UnimplementedError('getSleepAllData — backend not yet built');
```

Also add the import:
```dart
import 'package:zuralog/shared/all_data/all_data_models.dart';
```

- [ ] **Step 6: Run the tests to confirm they pass**

```
flutter test test/features/sleep/data/mock_sleep_all_data_test.dart
```

Expected: All tests PASS.

- [ ] **Step 7: Commit**

Use the `git` subagent:
```
git add zuralog/lib/features/sleep/data/sleep_repository_interface.dart \
        zuralog/lib/features/sleep/data/mock_sleep_repository.dart \
        zuralog/lib/features/sleep/data/api_sleep_repository.dart \
        zuralog/test/features/sleep/data/mock_sleep_all_data_test.dart
git commit -m "feat(sleep): add getSleepAllData to repo interface, mock, and api stub"
```

---

### Task 3: Nutrition repository — getNutritionAllData

**Files:**
- Modify: `zuralog/lib/features/nutrition/data/nutrition_repository_interface.dart`
- Modify: `zuralog/lib/features/nutrition/data/mock_nutrition_repository.dart`
- Modify: `zuralog/lib/features/nutrition/data/api_nutrition_repository.dart`
- Create: `zuralog/test/features/nutrition/data/mock_nutrition_all_data_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// zuralog/test/features/nutrition/data/mock_nutrition_all_data_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/data/mock_nutrition_repository.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';

void main() {
  late MockNutritionRepository repo;

  setUp(() => repo = const MockNutritionRepository());

  group('MockNutritionRepository.getNutritionAllData', () {
    test('7d returns 7 days', () async {
      final days = await repo.getNutritionAllData('7d');
      expect(days.length, 7);
    });

    test('each day has a non-empty values map', () async {
      final days = await repo.getNutritionAllData('7d');
      for (final day in days) {
        expect(day.values, isNotEmpty);
      }
    });

    test('today entry has isToday = true', () async {
      final days = await repo.getNutritionAllData('7d');
      final todayDays = days.where((d) => d.isToday).toList();
      expect(todayDays.length, 1);
    });

    test('calories values are positive when not null', () async {
      final days = await repo.getNutritionAllData('7d');
      for (final day in days) {
        final cal = day.values['calories'];
        if (cal != null) expect(cal, greaterThan(0));
      }
    });

    test('throws ArgumentError for unknown range', () async {
      await expectLater(
        () => repo.getNutritionAllData('invalid'),
        throwsArgumentError,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to confirm it fails**

```
flutter test test/features/nutrition/data/mock_nutrition_all_data_test.dart
```

Expected: FAIL — `getNutritionAllData` does not exist.

- [ ] **Step 3: Add `getNutritionAllData` to the interface**

Read `zuralog/lib/features/nutrition/data/nutrition_repository_interface.dart`. Add the method signature below `getTrend`:

```dart
import 'package:zuralog/shared/all_data/all_data_models.dart';

// (add to the abstract interface class)
  /// Returns per-day rows for every nutrition metric. Valid range values:
  /// '7d', '30d', '3m', '6m', '1y'. Throws [ArgumentError] for unknown ranges.
  Future<List<AllDataDay>> getNutritionAllData(String range);
```

- [ ] **Step 4: Implement in MockNutritionRepository**

Read `zuralog/lib/features/nutrition/data/mock_nutrition_repository.dart`. Add the following method. Metric ids: `'calories'`, `'protein'`, `'carbs'`, `'fat'`, `'meals'`.

```dart
  @override
  Future<List<AllDataDay>> getNutritionAllData(String range) async {
    if (range != '7d' && range != '30d' && range != '3m' &&
        range != '6m' && range != '1y') {
      throw ArgumentError.value(range, 'range', 'Unknown range');
    }
    final now = DateTime.now();
    const count = 7;
    return List.generate(count, (i) {
      final date = now.subtract(Duration(days: count - 1 - i));
      final isToday = i == count - 1;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final seed = i + 1;
      // Today: only calories and protein logged so far.
      if (isToday) {
        return AllDataDay(
          date: dateStr,
          isToday: true,
          values: {
            'calories': 840.0,
            'protein': 38.0,
            'carbs': null,
            'fat': null,
            'meals': 1.0,
          },
        );
      }
      return AllDataDay(
        date: dateStr,
        isToday: false,
        values: {
          'calories': 1800.0 + (seed % 3) * 80,
          'protein': 110.0 + (seed % 4) * 5,
          'carbs': 200.0 + (seed % 5) * 10,
          'fat': 65.0 + (seed % 3) * 5,
          'meals': (2.0 + (seed % 2)),
        },
      );
    });
  }
```

Also add the import:
```dart
import 'package:zuralog/shared/all_data/all_data_models.dart';
```

- [ ] **Step 5: Add stub to ApiNutritionRepository**

Read `zuralog/lib/features/nutrition/data/api_nutrition_repository.dart`. Add:

```dart
  @override
  Future<List<AllDataDay>> getNutritionAllData(String range) =>
      throw UnimplementedError('getNutritionAllData — backend not yet built');
```

Also add the import:
```dart
import 'package:zuralog/shared/all_data/all_data_models.dart';
```

- [ ] **Step 6: Run the tests to confirm they pass**

```
flutter test test/features/nutrition/data/mock_nutrition_all_data_test.dart
```

Expected: All tests PASS.

- [ ] **Step 7: Commit**

Use the `git` subagent:
```
git add zuralog/lib/features/nutrition/data/nutrition_repository_interface.dart \
        zuralog/lib/features/nutrition/data/mock_nutrition_repository.dart \
        zuralog/lib/features/nutrition/data/api_nutrition_repository.dart \
        zuralog/test/features/nutrition/data/mock_nutrition_all_data_test.dart
git commit -m "feat(nutrition): add getNutritionAllData to repo interface, mock, and api stub"
```

---

### Task 4: AllDataScreen — shared base widget

**Files:**
- Create: `zuralog/lib/shared/all_data/all_data_screen.dart`

This is the heart of the feature. No unit tests — it is a widget with complex interaction state. Smoke-tested manually in Task 5 and Task 6 when the section screens are wired up.

- [ ] **Step 1: Read the chart renderer files to confirm APIs**

Read the following before writing:
- `zuralog/lib/shared/widgets/charts/renderers/bar_renderer.dart` — confirm `BarRenderer` constructor, `BarChartConfig`, `BarPoint`
- `zuralog/lib/shared/widgets/charts/renderers/line_renderer.dart` — confirm `LineRenderer` constructor (it is a `StatefulWidget`, not const)
- `zuralog/lib/shared/widgets/charts/chart_render_context.dart` — confirm `ChartRenderContext.fromMode`
- `zuralog/lib/shared/widgets/charts/chart_mode.dart` — confirm `ChartMode.tall`
- `zuralog/lib/features/data/domain/tile_visualization_config.dart` — confirm `BarPoint`, `BarChartConfig`, `ChartPoint`, `LineChartConfig`
- `zuralog/lib/features/subscription/domain/subscription_providers.dart` — confirm `isPremiumProvider` import path

- [ ] **Step 2: Create AllDataScreen**

```dart
// zuralog/lib/shared/all_data/all_data_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/subscription/domain/subscription_providers.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';
import 'package:zuralog/shared/widgets/charts/chart_mode.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';
import 'package:zuralog/shared/widgets/charts/renderers/bar_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/line_renderer.dart';

/// Shared All-Data screen used by every health section.
///
/// Accepts an [AllDataSectionConfig] and renders the full deep-dive experience:
/// metric tabs, chart, time range selector, paywall gating on extended ranges,
/// personal benchmark band placeholder, and distribution breakdown placeholder.
class AllDataScreen extends ConsumerStatefulWidget {
  const AllDataScreen({super.key, required this.config});

  final AllDataSectionConfig config;

  @override
  ConsumerState<AllDataScreen> createState() => _AllDataScreenState();
}

class _AllDataScreenState extends ConsumerState<AllDataScreen> {
  int _selectedTab = 0;
  String _range = '7d';
  late Future<List<AllDataDay>> _dataFuture;
  bool _showUpgradePrompt = false;

  static const _ranges = ['7d', '30d', '3m', '6m', '1y'];
  static const _freeRange = '7d';

  @override
  void initState() {
    super.initState();
    _dataFuture = widget.config.fetchData(_range);
  }

  void _selectTab(int index) {
    setState(() => _selectedTab = index);
  }

  void _selectRange(String range) {
    final isPremium = ref.read(isPremiumProvider);
    if (range != _freeRange && !isPremium) {
      setState(() => _showUpgradePrompt = true);
      return;
    }
    setState(() {
      _range = range;
      _showUpgradePrompt = false;
      _dataFuture = widget.config.fetchData(range);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final catColor = widget.config.categoryColor;
    final tab = widget.config.tabs[_selectedTab];

    return Scaffold(
      backgroundColor: colors.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text('${widget.config.sectionTitle} — All Data'),
            pinned: true,
            backgroundColor: colors.surface,
            surfaceTintColor: Colors.transparent,
          ),

          // ── Metric tabs ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                itemCount: widget.config.tabs.length,
                itemBuilder: (context, i) {
                  final t = widget.config.tabs[i];
                  final isSelected = i == _selectedTab;
                  return GestureDetector(
                    onTap: () => _selectTab(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: AppDimens.spaceSm),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                        vertical: AppDimens.spaceXs,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? catColor.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppDimens.shapeXs),
                        border: Border.all(
                          color: isSelected
                              ? catColor.withValues(alpha: 0.4)
                              : colors.textSecondary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        t.label,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isSelected ? catColor : colors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),

          // ── Main chart ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
              ),
              child: ZuralogCard(
                variant: ZCardVariant.data,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: FutureBuilder<List<AllDataDay>>(
                    future: _dataFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 140,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final days = snapshot.data ?? [];
                      final hasAnyData = days.any(
                        (d) => tab.valueExtractor(d) != null,
                      );

                      if (!hasAnyData) {
                        return SizedBox(
                          height: 120,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'No data for ${tab.label}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                                if (tab.emptyStateSource != null) ...[
                                  const SizedBox(height: AppDimens.spaceXs),
                                  Text(
                                    tab.emptyStateSource!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }

                      final renderCtx = ChartRenderContext.fromMode(
                        ChartMode.tall,
                      ).copyWith(
                        showAxes: true,
                        showGrid: false,
                        animationProgress: 1.0,
                      );

                      if (tab.chartType == AllDataChartType.bar) {
                        final bars = days
                            .map((d) => BarPoint(
                                  label: d.date.length >= 10
                                      ? d.date.substring(5)
                                      : d.date,
                                  value: tab.valueExtractor(d) ?? 0,
                                  isToday: d.isToday,
                                ))
                            .toList();
                        return SizedBox(
                          height: 140,
                          child: BarRenderer(
                            config: BarChartConfig(
                              bars: bars,
                              showAvgLine: true,
                            ),
                            color: catColor,
                            renderCtx: renderCtx,
                          ),
                        );
                      }

                      // Line chart
                      final points = days
                          .where((d) => tab.valueExtractor(d) != null)
                          .map((d) {
                        final parts = d.date.split('-');
                        final date = DateTime(
                          int.parse(parts[0]),
                          int.parse(parts[1]),
                          int.parse(parts[2]),
                        );
                        return ChartPoint(
                          date: date,
                          value: tab.valueExtractor(d)!,
                        );
                      }).toList();
                      return SizedBox(
                        height: 140,
                        child: LineRenderer(
                          config: LineChartConfig(points: points),
                          color: catColor,
                          renderCtx: renderCtx,
                          unit: tab.unit,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),

          // ── Time range selector ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
              ),
              child: _RangeSelector(
                selected: _range,
                catColor: catColor,
                onChanged: _selectRange,
              ),
            ),
          ),

          // ── Upgrade prompt (shown when free user taps Pro range) ─────
          if (_showUpgradePrompt) ...[
            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimens.spaceMd),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: _UpgradePromptCard(catColor: catColor),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),

          // ── Personal benchmark band placeholder ──────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
              ),
              child: _PlaceholderCard(
                title: 'Personal Benchmark',
                body: 'Building your baseline… keep logging to see your personal range.',
                catColor: catColor,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),

          // ── Distribution breakdown placeholder ───────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
              ),
              child: _PlaceholderCard(
                title: 'Distribution',
                body: 'Building your baseline… keep logging to see your breakdown.',
                catColor: catColor,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimens.spaceLg),
          ),
        ],
      ),
    );
  }
}

// ── Time range selector ────────────────────────────────────────────────────────

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selected,
    required this.catColor,
    required this.onChanged,
  });

  final String selected;
  final Color catColor;
  final ValueChanged<String> onChanged;

  static const _ranges = ['7d', '30d', '3m', '6m', '1y'];
  static const _labels = ['7d', '30d', '3m', '6m', '1y'];

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      children: List.generate(_ranges.length, (i) {
        final r = _ranges[i];
        final isSelected = selected == r;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(right: i < _ranges.length - 1 ? 4 : 0),
              padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceXs),
              decoration: BoxDecoration(
                color: isSelected
                    ? catColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppDimens.shapeXs),
                border: Border.all(
                  color: isSelected
                      ? catColor.withValues(alpha: 0.4)
                      : colors.textSecondary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                _labels[i],
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(
                  color: isSelected ? catColor : colors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Upgrade prompt card ────────────────────────────────────────────────────────

class _UpgradePromptCard extends StatelessWidget {
  const _UpgradePromptCard({required this.catColor});

  final Color catColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: catColor,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock your full history with ZuraLog Pro',
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              'Extended time ranges — 30 days, 3 months, 6 months, and 1 year — require a Pro subscription.',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Placeholder card ───────────────────────────────────────────────────────────

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({
    required this.title,
    required this.body,
    required this.catColor,
  });

  final String title;
  final String body;
  final Color catColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogCard(
      variant: ZCardVariant.data,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              body,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify the file compiles**

```
flutter analyze zuralog/lib/shared/all_data/all_data_screen.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

Use the `git` subagent:
```
git add zuralog/lib/shared/all_data/all_data_screen.dart
git commit -m "feat(all-data): add shared AllDataScreen base widget"
```

---

### Task 5: SleepAllDataScreen

**Files:**
- Create: `zuralog/lib/features/sleep/presentation/all_data/sleep_all_data_screen.dart`

- [ ] **Step 1: Read the sleep providers file**

Read `zuralog/lib/features/sleep/providers/sleep_providers.dart` to confirm `sleepRepositoryProvider` import path.

- [ ] **Step 2: Create SleepAllDataScreen**

```dart
// zuralog/lib/features/sleep/presentation/all_data/sleep_all_data_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/sleep/providers/sleep_providers.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';
import 'package:zuralog/shared/all_data/all_data_screen.dart';

/// Entry point for the Sleep All-Data screen. Constructs the section config
/// and delegates all rendering to [AllDataScreen].
class SleepAllDataScreen extends ConsumerWidget {
  const SleepAllDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(sleepRepositoryProvider);
    final config = AllDataSectionConfig(
      sectionTitle: 'Sleep',
      categoryColor: AppColors.categorySleep,
      tabs: [
        AllDataMetricTab(
          id: 'duration',
          label: 'Duration',
          chartType: AllDataChartType.bar,
          unit: 'h',
          valueExtractor: (d) => d.values['duration'],
        ),
        AllDataMetricTab(
          id: 'quality',
          label: 'Quality',
          chartType: AllDataChartType.bar,
          unit: '',
          valueExtractor: (d) => d.values['quality'],
        ),
        AllDataMetricTab(
          id: 'deep_sleep',
          label: 'Deep Sleep',
          chartType: AllDataChartType.bar,
          unit: 'h',
          valueExtractor: (d) => d.values['deep_sleep'],
          emptyStateSource: 'Connect a wearable to see this metric',
        ),
        AllDataMetricTab(
          id: 'rem',
          label: 'REM',
          chartType: AllDataChartType.bar,
          unit: 'h',
          valueExtractor: (d) => d.values['rem'],
          emptyStateSource: 'Connect a wearable to see this metric',
        ),
        AllDataMetricTab(
          id: 'light_sleep',
          label: 'Light Sleep',
          chartType: AllDataChartType.bar,
          unit: 'h',
          valueExtractor: (d) => d.values['light_sleep'],
          emptyStateSource: 'Connect a wearable to see this metric',
        ),
        AllDataMetricTab(
          id: 'heart_rate',
          label: 'Heart Rate',
          chartType: AllDataChartType.line,
          unit: 'bpm',
          valueExtractor: (d) => d.values['heart_rate'],
          emptyStateSource: 'Connect a wearable to see this metric',
        ),
        AllDataMetricTab(
          id: 'efficiency',
          label: 'Efficiency',
          chartType: AllDataChartType.line,
          unit: '%',
          valueExtractor: (d) => d.values['efficiency'],
          emptyStateSource: 'Connect a wearable to see this metric',
        ),
      ],
      fetchData: repo.getSleepAllData,
    );
    return AllDataScreen(config: config);
  }
}
```

- [ ] **Step 3: Verify the file compiles**

```
flutter analyze zuralog/lib/features/sleep/presentation/all_data/sleep_all_data_screen.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

Use the `git` subagent:
```
git add zuralog/lib/features/sleep/presentation/all_data/sleep_all_data_screen.dart
git commit -m "feat(sleep): add SleepAllDataScreen wired to AllDataScreen"
```

---

### Task 6: NutritionAllDataScreen

**Files:**
- Create: `zuralog/lib/features/nutrition/presentation/all_data/nutrition_all_data_screen.dart`

- [ ] **Step 1: Read the nutrition providers file**

Read `zuralog/lib/features/nutrition/providers/nutrition_providers.dart` to confirm `nutritionRepositoryProvider` import path.

- [ ] **Step 2: Create NutritionAllDataScreen**

```dart
// zuralog/lib/features/nutrition/presentation/all_data/nutrition_all_data_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';
import 'package:zuralog/shared/all_data/all_data_screen.dart';

/// Entry point for the Nutrition All-Data screen.
class NutritionAllDataScreen extends ConsumerWidget {
  const NutritionAllDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(nutritionRepositoryProvider);
    final config = AllDataSectionConfig(
      sectionTitle: 'Nutrition',
      categoryColor: AppColors.categoryNutrition,
      tabs: [
        AllDataMetricTab(
          id: 'calories',
          label: 'Calories',
          chartType: AllDataChartType.bar,
          unit: 'kcal',
          valueExtractor: (d) => d.values['calories'],
        ),
        AllDataMetricTab(
          id: 'protein',
          label: 'Protein',
          chartType: AllDataChartType.bar,
          unit: 'g',
          valueExtractor: (d) => d.values['protein'],
        ),
        AllDataMetricTab(
          id: 'carbs',
          label: 'Carbs',
          chartType: AllDataChartType.bar,
          unit: 'g',
          valueExtractor: (d) => d.values['carbs'],
        ),
        AllDataMetricTab(
          id: 'fat',
          label: 'Fat',
          chartType: AllDataChartType.bar,
          unit: 'g',
          valueExtractor: (d) => d.values['fat'],
        ),
        AllDataMetricTab(
          id: 'meals',
          label: 'Meals',
          chartType: AllDataChartType.bar,
          unit: '',
          valueExtractor: (d) => d.values['meals'],
        ),
      ],
      fetchData: repo.getNutritionAllData,
    );
    return AllDataScreen(config: config);
  }
}
```

- [ ] **Step 3: Verify the file compiles**

```
flutter analyze zuralog/lib/features/nutrition/presentation/all_data/nutrition_all_data_screen.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

Use the `git` subagent:
```
git add zuralog/lib/features/nutrition/presentation/all_data/nutrition_all_data_screen.dart
git commit -m "feat(nutrition): add NutritionAllDataScreen wired to AllDataScreen"
```

---

### Task 7: Routes, navigation wiring, and sleep "View All Data →" row

**Files:**
- Modify: `zuralog/lib/core/router/route_names.dart`
- Modify: `zuralog/lib/core/router/app_router.dart`
- Modify: `zuralog/lib/features/sleep/presentation/sleep_detail_screen.dart`
- Modify: `zuralog/lib/features/nutrition/presentation/nutrition_home_screen.dart`

- [ ] **Step 1: Add route constants to RouteNames**

Read `zuralog/lib/core/router/route_names.dart`. After the `// ── Sleep Detail` block (around line 163), add:

```dart
  // ── Sleep All-Data ────────────────────────────────────────────────────────
  static const String sleepAllData     = 'sleepAllData';
  static const String sleepAllDataPath = '/sleep/all-data';
```

After the `// ── Nutrition (pushed over shell)` block, add inside the nutrition section:

```dart
  /// Name for the Nutrition All-Data screen.
  static const String nutritionAllData     = 'nutritionAllData';

  /// Path for the Nutrition All-Data screen.
  static const String nutritionAllDataPath = '/nutrition/all-data';
```

Also update the doc comment at the top of the file to include the two new routes in the route tree comment block.

- [ ] **Step 2: Register the routes in app_router.dart**

Read `zuralog/lib/core/router/app_router.dart`. 

Add import for the two new screens near the other feature imports:
```dart
import 'package:zuralog/features/sleep/presentation/all_data/sleep_all_data_screen.dart';
import 'package:zuralog/features/nutrition/presentation/all_data/nutrition_all_data_screen.dart';
```

Locate the sleep route (around line 376):
```dart
    GoRoute(
      path: RouteNames.sleepPath,
      name: RouteNames.sleep,
      pageBuilder: (context, state) => const MaterialPage(
        child: SentryErrorBoundary(
          module: 'sleep.detail',
          child: SleepDetailScreen(),
        ),
      ),
    ),
```

Replace with a nested route so Sleep All-Data is a child of Sleep:
```dart
    GoRoute(
      path: RouteNames.sleepPath,
      name: RouteNames.sleep,
      pageBuilder: (context, state) => const MaterialPage(
        child: SentryErrorBoundary(
          module: 'sleep.detail',
          child: SleepDetailScreen(),
        ),
      ),
      routes: [
        GoRoute(
          path: 'all-data',
          name: RouteNames.sleepAllData,
          pageBuilder: (context, state) => const MaterialPage(
            child: SentryErrorBoundary(
              module: 'sleep.all_data',
              child: SleepAllDataScreen(),
            ),
          ),
        ),
      ],
    ),
```

Locate the nutrition routes block. Find where `NutritionHomeScreen` is registered and add a sibling route for `all-data` inside the nutrition `GoRoute` routes list:
```dart
        GoRoute(
          path: 'all-data',
          name: RouteNames.nutritionAllData,
          pageBuilder: (context, state) => const MaterialPage(
            child: SentryErrorBoundary(
              module: 'nutrition.all_data',
              child: NutritionAllDataScreen(),
            ),
          ),
        ),
```

> **Note:** Read the nutrition routes block in full before editing to understand the existing nesting structure. The new all-data route is a sibling of `meal/:id`, `rules`, `meal-edit`, etc.

- [ ] **Step 3: Add "View All Data →" to SleepDetailScreen**

Read `zuralog/lib/features/sleep/presentation/sleep_detail_screen.dart`. 

Add import at the top:
```dart
import 'package:go_router/go_router.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/shared/widgets/widgets.dart';
```

Locate the `ZStaggeredList` children list. After `const SleepTrendSection()` and its spacing `SizedBox`, add:

```dart
                  const SizedBox(height: AppDimens.spaceSm),
                  InkWell(
                    onTap: () => context.pushNamed(RouteNames.sleepAllData),
                    borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimens.spaceXs,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'View All Data',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: AppDimens.spaceXs),
                          const ZProBadge(showLock: true),
                          const SizedBox(width: AppDimens.spaceXs),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: AppDimens.iconSm,
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
```

Also add the required import for `AppTextStyles` if not already present:
```dart
import 'package:zuralog/core/theme/app_text_styles.dart';
```

- [ ] **Step 4: Wire NutritionHomeScreen "View All Data →" to real route**

Read `zuralog/lib/features/nutrition/presentation/nutrition_home_screen.dart`. Locate the `InkWell` for "View All Data" (the one with the SnackBar onTap). Replace the `onTap` callback:

Old:
```dart
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All-Data screen coming in a future update'),
                          duration: Duration(seconds: 2),
                        ),
                      ),
```

New:
```dart
                      onTap: () => context.pushNamed(RouteNames.nutritionAllData),
```

- [ ] **Step 5: Run flutter analyze and fix any issues**

```
flutter analyze zuralog/
```

Expected: No errors. Fix any import or type issues before committing.

- [ ] **Step 6: Run all tests to verify nothing broke**

```
flutter test zuralog/
```

Expected: All previously passing tests continue to pass.

- [ ] **Step 7: Commit**

Use the `git` subagent:
```
git add zuralog/lib/core/router/route_names.dart \
        zuralog/lib/core/router/app_router.dart \
        zuralog/lib/features/sleep/presentation/sleep_detail_screen.dart \
        zuralog/lib/features/nutrition/presentation/nutrition_home_screen.dart
git commit -m "feat(routes): add sleepAllData + nutritionAllData routes and wire View All Data navigation"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] `AllDataDay`, `AllDataSectionConfig`, `AllDataMetricTab`, `AllDataChartType` — Task 1
- [x] `getSleepAllData` in interface + mock + stub — Task 2
- [x] `getNutritionAllData` in interface + mock + stub — Task 3
- [x] Shared `AllDataScreen` with tabs, chart, time range selector — Task 4
- [x] Paywall gating (free = 7d only, Pro = all ranges, inline upgrade prompt) — Task 4
- [x] Benchmark band placeholder — Task 4
- [x] Distribution breakdown placeholder — Task 4
- [x] Empty state per metric with optional emptyStateSource — Task 4
- [x] `SleepAllDataScreen` with 7 metric tabs — Task 5
- [x] `NutritionAllDataScreen` with 5 metric tabs — Task 6
- [x] Routes registered — Task 7
- [x] Sleep "View All Data →" row added to `SleepDetailScreen` — Task 7
- [x] Nutrition InkWell wired to real route — Task 7

**No placeholders found in plan.**

**Type consistency check:**
- `AllDataDay.values` is `Map<String, double?>` — extractors use `d.values['id']` which returns `double?` ✓
- `AllDataMetricTab.valueExtractor` signature is `double? Function(AllDataDay)` — all uses match ✓
- `BarRenderer` takes `BarChartConfig(bars: List<BarPoint>, ...)` — matches tile_visualization_config.dart ✓
- `LineRenderer` takes `LineChartConfig(points: List<ChartPoint>)` — matches tile_visualization_config.dart ✓
- `ChartPoint` constructor: `(date: DateTime, value: double)` — used correctly in Task 4 ✓
- `isPremiumProvider` is `Provider<bool>` — used with `ref.read(isPremiumProvider)` ✓
- `sleepRepositoryProvider` referenced from `sleep_providers.dart` — correct ✓
- `nutritionRepositoryProvider` referenced from `nutrition_providers.dart` — correct ✓
