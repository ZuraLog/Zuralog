// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/domain/time_range.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/features/today/domain/today_models.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Creates a [DashboardData] with a single category summary for [category].
DashboardData _dashboardWithCategory(HealthCategory category) {
  return DashboardData(
    categories: [
      CategorySummary(
        category: category,
        primaryValue: '42',
        unit: 'steps',
        lastUpdated: '2026-03-19T12:00:00Z',
      ),
    ],
    visibleOrder: [category.name],
  );
}

/// Creates a [DashboardData] with summaries for all 10 categories.
DashboardData _fullDashboard() {
  return DashboardData(
    categories: HealthCategory.values
        .map((c) => CategorySummary(
              category: c,
              primaryValue: '10',
              unit: 'units',
              lastUpdated: '2026-03-18T08:00:00Z',
            ))
        .toList(),
    visibleOrder: HealthCategory.values.map((c) => c.name).toList(),
  );
}

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

void main() {
  // ── combineBloodPressureForTest ─────────────────────────────────────────────

  group('combineBloodPressureForTest', () {
    test('returns null when both series are absent', () {
      expect(combineBloodPressureForTest({}), isNull);
    });

    test('combines sys and dia into "120/80" format', () {
      final map = {
        'blood_pressure_systolic': MetricSeries(
          metricId: 'blood_pressure_systolic',
          displayName: 'Systolic',
          unit: 'mmHg',
          dataPoints: [],
          currentValue: '120',
        ),
        'blood_pressure_diastolic': MetricSeries(
          metricId: 'blood_pressure_diastolic',
          displayName: 'Diastolic',
          unit: 'mmHg',
          dataPoints: [],
          currentValue: '80',
        ),
      };
      final result = combineBloodPressureForTest(map);
      expect(result, isNotNull);
      expect(result!.currentValue, '120/80');
      expect(result.unit, 'mmHg');
    });

    test('uses — for missing diastolic', () {
      final map = {
        'blood_pressure_systolic': MetricSeries(
          metricId: 'blood_pressure_systolic',
          displayName: 'Systolic',
          unit: 'mmHg',
          dataPoints: [],
          currentValue: '118',
        ),
      };
      final result = combineBloodPressureForTest(map);
      expect(result!.currentValue, '118/—');
    });
  });

  // ── TimeRange ───────────────────────────────────────────────────────────────

  group('TimeRange', () {
    test('has exactly 5 values', () {
      expect(TimeRange.values.length, 5);
    });

    test('apiKey returns correct strings', () {
      expect(TimeRange.today.apiKey, 'today');
      expect(TimeRange.sevenDays.apiKey, '7D');
      expect(TimeRange.thirtyDays.apiKey, '30D');
      expect(TimeRange.ninetyDays.apiKey, '90D');
      expect(TimeRange.custom.apiKey, 'custom');
    });

    test('label returns correct display strings', () {
      expect(TimeRange.today.label, 'Today');
      expect(TimeRange.sevenDays.label, '7D');
      expect(TimeRange.thirtyDays.label, '30D');
      expect(TimeRange.ninetyDays.label, '90D');
      expect(TimeRange.custom.label, 'Custom');
    });

    test('sevenDays is the default time range (dashboardTimeRangeProvider initial state)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(dashboardTimeRangeProvider), TimeRange.sevenDays);
    });
  });

  // ── tileFilterProvider ──────────────────────────────────────────────────────

  group('tileFilterProvider', () {
    test('initial state is null (no filter)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(tileFilterProvider), isNull);
    });

    test('can be set to a HealthCategory and read back', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(tileFilterProvider.notifier).state = HealthCategory.sleep;
      expect(container.read(tileFilterProvider), HealthCategory.sleep);
    });

    test('can be reset to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(tileFilterProvider.notifier).state = HealthCategory.heart;
      container.read(tileFilterProvider.notifier).state = null;
      expect(container.read(tileFilterProvider), isNull);
    });
  });

  // ── dashboardTimeRangeProvider ──────────────────────────────────────────────

  group('dashboardTimeRangeProvider', () {
    test('initial state is TimeRange.sevenDays', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(dashboardTimeRangeProvider), TimeRange.sevenDays);
    });

    test('can be changed to TimeRange.thirtyDays', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(dashboardTimeRangeProvider.notifier).state =
          TimeRange.thirtyDays;
      expect(container.read(dashboardTimeRangeProvider), TimeRange.thirtyDays);
    });
  });

  // ── customDateRangeProvider ─────────────────────────────────────────────────

  group('customDateRangeProvider', () {
    test('initial state is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(customDateRangeProvider), isNull);
    });

    test('can be set to a DateTimeRange and read back', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final range = DateTimeRange(
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 15),
      );
      container.read(customDateRangeProvider.notifier).state = range;
      expect(container.read(customDateRangeProvider), range);
    });

    test('is independent from dashboardTimeRangeProvider — changing time range does not clear custom range', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final range = DateTimeRange(
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 15),
      );
      container.read(customDateRangeProvider.notifier).state = range;
      // Change time range away from custom — custom range must NOT be auto-cleared.
      container.read(dashboardTimeRangeProvider.notifier).state = TimeRange.sevenDays;
      expect(container.read(customDateRangeProvider), range,
          reason: 'Custom range is session-only and cleared manually by the widget, not automatically');
    });
  });

  // ── tileOrderingProvider ────────────────────────────────────────────────────

  group('tileOrderingProvider with custom layout', () {
    test('when layout.tileOrder is non-empty, returns tiles in that order', () {
      final customOrder = [
        TileId.sleepDuration.name,
        TileId.steps.name,
        TileId.hrv.name,
      ];
      final layout = DashboardLayout.defaultLayout.copyWith(
        tileOrder: customOrder,
      );
      final container = ProviderContainer(
        overrides: [
          dashboardLayoutProvider.overrideWith((ref) => layout),
          dashboardTilesProvider.overrideWith(
            (ref) async => [],
          ),
        ],
      );
      addTearDown(container.dispose);

      final ordered = container.read(tileOrderingProvider);
      // The first 3 should be sleepDuration, steps, hrv in that order.
      expect(ordered[0], TileId.sleepDuration);
      expect(ordered[1], TileId.steps);
      expect(ordered[2], TileId.hrv);
    });

    test('unknown slugs in tileOrder are filtered out', () {
      final customOrder = [
        'unknownSlug',
        TileId.weight.name,
      ];
      final layout = DashboardLayout.defaultLayout.copyWith(
        tileOrder: customOrder,
      );
      final container = ProviderContainer(
        overrides: [
          dashboardLayoutProvider.overrideWith((ref) => layout),
          dashboardTilesProvider.overrideWith(
            (ref) async => [],
          ),
        ],
      );
      addTearDown(container.dispose);

      final ordered = container.read(tileOrderingProvider);
      // unknownSlug should be filtered, weight should be present.
      expect(ordered.contains(TileId.weight), isTrue);
      // Total count = 1 persisted (weight) + 19 new tiles appended.
      expect(ordered.length, TileId.values.length);
    });

    test('tiles not in persisted order are appended at end', () {
      // Only specify 3 tiles in the custom order.
      final customOrder = [
        TileId.steps.name,
        TileId.sleepDuration.name,
        TileId.hrv.name,
      ];
      final layout = DashboardLayout.defaultLayout.copyWith(
        tileOrder: customOrder,
      );
      final container = ProviderContainer(
        overrides: [
          dashboardLayoutProvider.overrideWith((ref) => layout),
          dashboardTilesProvider.overrideWith(
            (ref) async => [],
          ),
        ],
      );
      addTearDown(container.dispose);

      final ordered = container.read(tileOrderingProvider);
      // Total count should be all 20 TileIds.
      expect(ordered.length, TileId.values.length);
      // Persisted 3 are first.
      expect(ordered[0], TileId.steps);
      expect(ordered[1], TileId.sleepDuration);
      expect(ordered[2], TileId.hrv);
      // All remaining tiles exist somewhere in the list.
      for (final id in TileId.values) {
        expect(ordered.contains(id), isTrue, reason: '${id.name} should be in the ordered list');
      }
    });
  });

  group('tileOrderingProvider with empty layout (smart ordering)', () {
    test('tiles with lastUpdated sort before tiles without lastUpdated', () {
      // Give only one category (activity) a lastUpdated value.
      final tiles = [
        TileData(
          tileId: TileId.steps,
          dataState: TileDataState.loaded,
          lastUpdated: '2026-03-19T10:00:00Z',
        ),
        // All others will have null lastUpdated.
      ];
      final container = ProviderContainer(
        overrides: [
          dashboardLayoutProvider.overrideWith(
            (ref) => DashboardLayout.defaultLayout, // empty tileOrder
          ),
          dashboardTilesProvider.overrideWith(
            (ref) async => tiles,
          ),
        ],
      );
      addTearDown(container.dispose);

      final ordered = container.read(tileOrderingProvider);
      // steps should come first because it has the most recent lastUpdated.
      expect(ordered.first, TileId.steps);
    });

    test('among tiles with lastUpdated, more recent sorts first', () {
      final tiles = [
        TileData(
          tileId: TileId.weight,
          dataState: TileDataState.loaded,
          lastUpdated: '2026-03-17T08:00:00Z', // older
        ),
        TileData(
          tileId: TileId.steps,
          dataState: TileDataState.loaded,
          lastUpdated: '2026-03-19T10:00:00Z', // more recent
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          dashboardLayoutProvider.overrideWith(
            (ref) => DashboardLayout.defaultLayout,
          ),
          dashboardTilesProvider.overrideWith(
            (ref) async => tiles,
          ),
        ],
      );
      addTearDown(container.dispose);

      final ordered = container.read(tileOrderingProvider);
      final stepsIdx = ordered.indexOf(TileId.steps);
      final weightIdx = ordered.indexOf(TileId.weight);
      expect(stepsIdx, lessThan(weightIdx),
          reason: 'steps (more recent) should sort before weight (older)');
    });
  });

  // ── dashboardTilesProvider ──────────────────────────────────────────────────

  group('dashboardTilesProvider', () {
    test('returns a list with length == TileId.values.length (20)', () async {
      final container = _containerWithDashboard(
        DashboardData(categories: [], visibleOrder: []),
      );
      addTearDown(container.dispose);

      final tiles = await container.read(dashboardTilesProvider.future);
      expect(tiles.length, TileId.values.length);
    });

    test(
        'when dashboardProvider has data for a category, tiles in that category have dataState == loaded',
        () async {
      // Activity category has data.
      final container = _containerWithDashboard(
        _dashboardWithCategory(HealthCategory.activity),
      );
      addTearDown(container.dispose);

      final tiles = await container.read(dashboardTilesProvider.future);
      final activityTileIds = TileId.values
          .where((id) => id.category == HealthCategory.activity)
          .toList();

      for (final id in activityTileIds) {
        final tile = tiles.firstWhere((t) => t.tileId == id);
        expect(tile.dataState, TileDataState.loaded,
            reason: '${id.name} should be loaded because activity has data');
      }
    });

    test(
        'when dashboardProvider has no data (empty categories), tiles have dataState == noSource',
        () async {
      final container = _containerWithDashboard(
        DashboardData(categories: [], visibleOrder: []),
      );
      addTearDown(container.dispose);

      final tiles = await container.read(dashboardTilesProvider.future);
      for (final tile in tiles) {
        expect(tile.dataState, TileDataState.noSource,
            reason: '${tile.tileId.name} should be noSource when no categories');
      }
    });

    test('each tile has the correct tileId', () async {
      final container = _containerWithDashboard(
        DashboardData(categories: [], visibleOrder: []),
      );
      addTearDown(container.dispose);

      final tiles = await container.read(dashboardTilesProvider.future);
      final tileIds = tiles.map((t) => t.tileId).toSet();
      expect(tileIds.length, TileId.values.length,
          reason: 'all 20 TileIds should be represented');
      for (final id in TileId.values) {
        expect(tileIds.contains(id), isTrue,
            reason: '${id.name} should be present');
      }
    });

    test('loaded tiles have a non-null lastUpdated from the category summary',
        () async {
      final container = _containerWithDashboard(
        _fullDashboard(),
      );
      addTearDown(container.dispose);

      final tiles = await container.read(dashboardTilesProvider.future);
      for (final tile in tiles) {
        expect(tile.dataState, TileDataState.loaded);
        expect(tile.lastUpdated, isNotNull,
            reason: '${tile.tileId.name} should have lastUpdated');
      }
    });
  });

  // ── dashboardTilesProvider — stats population ───────────────────────────────

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

  // ── _buildTileViz produces correct config types ──────────────────────────────

  group('_buildTileViz produces correct config types', () {
    // Minimal summary with no trend data.
    CategorySummary emptySummary(HealthCategory category) => CategorySummary(
          category: category,
          primaryValue: '0',
        );

    test('steps → returns a TileVisualizationConfig', () {
      final config = buildTileVizForTest(
        TileId.steps,
        emptySummary(HealthCategory.activity),
        [],
        TileSize.square,
      );
      expect(config, isA<TileVisualizationConfig>());
    });

    test('steps square → BarChartConfig without showAvgLine', () {
      final config = buildTileVizForTest(
        TileId.steps,
        emptySummary(HealthCategory.activity),
        [],
        TileSize.square,
      );
      expect(config, isA<BarChartConfig>());
      expect((config as BarChartConfig).showAvgLine, isFalse);
    });

    test('steps tall → BarChartConfig with showAvgLine', () {
      final config = buildTileVizForTest(
        TileId.steps,
        emptySummary(HealthCategory.activity),
        [],
        TileSize.tall,
      );
      expect(config, isA<BarChartConfig>());
      expect((config as BarChartConfig).showAvgLine, isTrue);
    });

    test('bloodPressure → DualValueConfig when primaryValue has slash', () {
      final summary = CategorySummary(
        category: HealthCategory.vitals,
        primaryValue: '120/78',
      );
      final config = buildTileVizForTest(
        TileId.bloodPressure,
        summary,
        [],
        TileSize.square,
      );
      expect(config, isA<DualValueConfig>());
      final dual = config as DualValueConfig;
      expect(dual.value1, '120');
      expect(dual.value2, '78');
      expect(dual.label1, 'SYS');
      expect(dual.label2, 'DIA');
    });

    test('bloodPressure → StatCardConfig when primaryValue has no slash', () {
      final summary = CategorySummary(
        category: HealthCategory.vitals,
        primaryValue: '120',
        unit: 'mmHg',
      );
      final config = buildTileVizForTest(
        TileId.bloodPressure,
        summary,
        [],
        TileSize.square,
      );
      expect(config, isA<StatCardConfig>());
    });

    test('vo2Max → GaugeConfig', () {
      final summary = CategorySummary(
        category: HealthCategory.heart,
        primaryValue: '45',
      );
      final config = buildTileVizForTest(
        TileId.vo2Max,
        summary,
        [],
        TileSize.square,
      );
      expect(config, isA<GaugeConfig>());
      final gauge = config as GaugeConfig;
      expect(gauge.value, 45.0);
      expect(gauge.zones.length, 5);
    });

    test('restingHeartRate → LineChartConfig', () {
      final config = buildTileVizForTest(
        TileId.restingHeartRate,
        emptySummary(HealthCategory.heart),
        [],
        TileSize.square,
      );
      expect(config, isA<LineChartConfig>());
    });

    test('hrv → LineChartConfig with positiveIsUp true', () {
      final config = buildTileVizForTest(
        TileId.hrv,
        emptySummary(HealthCategory.heart),
        [],
        TileSize.square,
      );
      expect(config, isA<LineChartConfig>());
      expect((config as LineChartConfig).positiveIsUp, isTrue);
    });

    test('water → FillGaugeConfig', () {
      final config = buildTileVizForTest(
        TileId.water,
        emptySummary(HealthCategory.nutrition),
        [],
        TileSize.square,
      );
      expect(config, isA<FillGaugeConfig>());
    });

    test('stress → DotRowConfig with invertedScale true', () {
      final config = buildTileVizForTest(
        TileId.stress,
        emptySummary(HealthCategory.wellness),
        [],
        TileSize.square,
      );
      expect(config, isA<DotRowConfig>());
      expect((config as DotRowConfig).invertedScale, isTrue);
    });

    test('mood → DotRowConfig', () {
      final config = buildTileVizForTest(
        TileId.mood,
        emptySummary(HealthCategory.wellness),
        [],
        TileSize.square,
      );
      expect(config, isA<DotRowConfig>());
    });

    test('exerciseMinutes square → RingConfig', () {
      final summary = CategorySummary(
        category: HealthCategory.activity,
        primaryValue: '20',
      );
      final config = buildTileVizForTest(
        TileId.exerciseMinutes,
        summary,
        [],
        TileSize.square,
      );
      expect(config, isA<RingConfig>());
    });

    test('exerciseMinutes tall → BarChartConfig with goalValue 30', () {
      final summary = CategorySummary(
        category: HealthCategory.activity,
        primaryValue: '20',
      );
      final config = buildTileVizForTest(
        TileId.exerciseMinutes,
        summary,
        [],
        TileSize.tall,
      );
      expect(config, isA<BarChartConfig>());
      expect((config as BarChartConfig).goalValue, 30.0);
    });

    test('bloodGlucose square → GaugeConfig', () {
      final summary = CategorySummary(
        category: HealthCategory.vitals,
        primaryValue: '5.5',
      );
      final config = buildTileVizForTest(
        TileId.bloodGlucose,
        summary,
        [],
        TileSize.square,
      );
      expect(config, isA<GaugeConfig>());
    });

    test('bloodGlucose wide → LineChartConfig', () {
      final summary = CategorySummary(
        category: HealthCategory.vitals,
        primaryValue: '5.5',
      );
      final config = buildTileVizForTest(
        TileId.bloodGlucose,
        summary,
        [],
        TileSize.wide,
      );
      expect(config, isA<LineChartConfig>());
    });

    // New tile IDs all return a TileVisualizationConfig subtype.
    for (final id in [
      TileId.distance,
      TileId.floorsClimbed,
      TileId.walkingSpeed,
      TileId.runningPace,
      TileId.respiratoryRate,
      TileId.bodyTemperature,
      TileId.wristTemperature,
      TileId.macros,
      TileId.mindfulMinutes,
    ]) {
      test('$id returns a TileVisualizationConfig', () {
        final config = buildTileVizForTest(
          id,
          CategorySummary(
            category: id.category,
            primaryValue: '0',
          ),
          [],
          TileSize.square,
        );
        expect(config, isA<TileVisualizationConfig>());
      });
    }
  });
}
