// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';

void main() {
  // ── TileId ─────────────────────────────────────────────────────────────────

  group('TileId', () {
    test('has exactly 31 values', () {
      expect(TileId.values.length, 31);
    });

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

    test('fromString round-trips all 31 slugs', () {
      for (final id in TileId.values) {
        expect(TileId.fromString(id.name), id,
            reason: 'slug "${id.name}" should round-trip');
      }
    });

    test('fromString returns null for null', () {
      expect(TileId.fromString(null), isNull);
    });

    test('fromString returns null for empty string', () {
      expect(TileId.fromString(''), isNull);
    });

    test('fromString returns null for unknown slug', () {
      expect(TileId.fromString('unknown'), isNull);
    });
  });

  // ── TileSize ────────────────────────────────────────────────────────────────

  group('TileSize', () {
    test('has exactly 3 values', () {
      expect(TileSize.values.length, 3);
    });
  });

  // ── TileConfig extension ───────────────────────────────────────────────────

  group('TileConfig.displayName', () {
    test('every TileId has a non-empty displayName', () {
      for (final id in TileId.values) {
        expect(id.displayName.isNotEmpty, isTrue,
            reason: '${id.name} should have a non-empty displayName');
      }
    });
  });

  group('TileConfig.category', () {
    test('category mapping matches spec', () {
      // Activity
      for (final id in [TileId.steps, TileId.activeCalories, TileId.workouts]) {
        expect(id.category, HealthCategory.activity, reason: '$id should be activity');
      }
      // Sleep
      for (final id in [TileId.sleepDuration, TileId.sleepStages]) {
        expect(id.category, HealthCategory.sleep, reason: '$id should be sleep');
      }
      // Heart
      for (final id in [TileId.restingHeartRate, TileId.hrv, TileId.vo2Max]) {
        expect(id.category, HealthCategory.heart, reason: '$id should be heart');
      }
      // Body
      for (final id in [TileId.weight, TileId.bodyFat]) {
        expect(id.category, HealthCategory.body, reason: '$id should be body');
      }
      // Vitals
      for (final id in [TileId.bloodPressure, TileId.spo2]) {
        expect(id.category, HealthCategory.vitals, reason: '$id should be vitals');
      }
      // Nutrition
      for (final id in [TileId.calories, TileId.water]) {
        expect(id.category, HealthCategory.nutrition, reason: '$id should be nutrition');
      }
      // Wellness
      for (final id in [TileId.mood, TileId.energy, TileId.stress]) {
        expect(id.category, HealthCategory.wellness, reason: '$id should be wellness');
      }
      // Single-tile categories
      expect(TileId.cycle.category, HealthCategory.cycle);
      expect(TileId.environment.category, HealthCategory.environment);
      expect(TileId.mobility.category, HealthCategory.mobility);
    });
  });

  group('TileConfig.allowedSizes', () {
    test('every TileId has at least one allowedSize', () {
      for (final id in TileId.values) {
        expect(id.allowedSizes.isNotEmpty, isTrue,
            reason: '${id.name} should have at least one allowed size');
      }
    });

    test('defaultSize is always in allowedSizes for every TileId', () {
      for (final id in TileId.values) {
        expect(id.allowedSizes.contains(id.defaultSize), isTrue,
            reason:
                '${id.name}: defaultSize ${id.defaultSize} must be in allowedSizes');
      }
    });

    test('steps.defaultSize is tall', () {
      expect(TileId.steps.defaultSize, TileSize.tall);
    });

    test('sleepStages.defaultSize is wide', () {
      expect(TileId.sleepStages.defaultSize, TileSize.wide);
    });

    test('weight.defaultSize is wide', () {
      expect(TileId.weight.defaultSize, TileSize.wide);
    });

    test('steps.allowedSizes does NOT contain wide', () {
      expect(TileId.steps.allowedSizes.contains(TileSize.wide), isFalse);
    });

    test('mood.allowedSizes contains both square and wide', () {
      expect(TileId.mood.allowedSizes.contains(TileSize.square), isTrue);
      expect(TileId.mood.allowedSizes.contains(TileSize.wide), isTrue);
    });
  });

  group('TileConfig.nextSize', () {
    test('steps cycles square→tall→square', () {
      expect(TileId.steps.nextSize(TileSize.square), TileSize.tall);
      expect(TileId.steps.nextSize(TileSize.tall), TileSize.square);
    });

    test('nextSize cycles through all sizes for sleepStages (wide→tall→wide)', () {
      expect(TileId.sleepStages.nextSize(TileSize.wide), TileSize.tall);
      expect(TileId.sleepStages.nextSize(TileSize.tall), TileSize.wide);
    });

    test('nextSize returns first allowed size when current is not in allowedSizes', () {
      // steps.allowedSizes = [square, tall]. Passing wide (not allowed) should return square.
      expect(TileId.steps.nextSize(TileSize.wide), TileSize.square);
    });
  });

  // ── TileDataState ──────────────────────────────────────────────────────────

  group('TileDataState', () {
    test('has exactly 5 values', () {
      expect(TileDataState.values.length, 5);
    });
  });

  // ── TileVisualizationData subtypes ─────────────────────────────────────────

  group('BarChartData', () {
    test('stores dailyValues and dayLabels correctly', () {
      final data = BarChartData(
        dailyValues: [100.0, 200.0, 300.0],
        dayLabels: ['Mon', 'Tue', 'Wed'],
      );
      expect(data.dailyValues, [100.0, 200.0, 300.0]);
      expect(data.dayLabels, ['Mon', 'Tue', 'Wed']);
    });
  });

  group('RingData', () {
    test('stores value and max', () {
      const data = RingData(value: 0.75, max: 1.0);
      expect(data.value, 0.75);
      expect(data.max, 1.0);
    });
  });

  group('DotsData', () {
    test('stores 7 values', () {
      final data = DotsData(values: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]);
      expect(data.values.length, 7);
      expect(data.values.first, 1.0);
      expect(data.values.last, 7.0);
    });
  });

  // ── TileData stats fields ──────────────────────────────────────────────────

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
}
