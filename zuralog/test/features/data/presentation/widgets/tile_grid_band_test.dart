import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
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
      // weight pulled up into masonry band before wide
      expect(bands[0].ids.length, 4);
      expect(bands[0].ids.last, TileId.weight);
      expect(bands[1].isWide, isTrue);
      expect(bands.length, 2);
    });

    test('even pending count before wide: no pull-up needed', () {
      final ids = [TileId.steps, TileId.activeCalories, TileId.sleepStages];
      final bands = buildBands(ids, sizeOf);
      expect(bands[0].ids.length, 2);
      expect(bands[1].isWide, isTrue);
    });

    test('odd pending, no non-wide tile after wide: inserts null spacer', () {
      final ids = [TileId.steps, TileId.sleepStages];
      final bands = buildBands(ids, sizeOf);
      // Spacer pulled in — masonry band has 2 items (steps + null spacer)
      expect(bands[0].ids.length, 2);
      expect(bands[0].ids.last, isNull); // null = transparent spacer
    });
  });

  group('buildBands tall tile handling', () {
    TileSize sizeOf(TileId id) => switch (id) {
      TileId.steps       => TileSize.tall,
      TileId.sleepStages => TileSize.wide,
      _                  => TileSize.square,
    };

    test('tall tile emits a 3-item band with two companions', () {
      final ids = [
        TileId.activeCalories,
        TileId.workouts,
        TileId.steps,
        TileId.hrv,
        TileId.vo2Max,
      ];
      final bands = buildBands(ids, sizeOf);
      expect(bands[0].isWide, isFalse);
      expect(bands[0].ids, [TileId.activeCalories, TileId.workouts]);
      expect(bands[1].isWide, isFalse);
      expect(bands[1].ids, [TileId.steps, TileId.hrv, TileId.vo2Max]);
      expect(bands.length, 2);
    });

    test('tall tile with odd pending: last pending square becomes first companion, no null spacer', () {
      // 1 pending square (activeCalories) before tall — it is popped and becomes
      // the first companion of the tall band instead of being padded with null.
      final ids = [
        TileId.activeCalories,
        TileId.steps,
        TileId.hrv,
        TileId.vo2Max,
      ];
      final bands = buildBands(ids, sizeOf);
      // No pre-flush band: the odd pending square is absorbed into the tall band.
      expect(bands[0].ids, [TileId.steps, TileId.activeCalories, TileId.hrv]);
      // vo2Max flushes at end — odd count, null spacer added (no more squares).
      expect(bands[1].ids, [TileId.vo2Max, null]);
      expect(bands.length, 2);
    });

    test('tall tile with zero companions gets null spacers', () {
      final ids = [TileId.steps];
      final bands = buildBands(ids, sizeOf);
      expect(bands[0].ids, [TileId.steps, null, null]);
    });

    test('tall tile with one companion gets one null spacer', () {
      final ids = [TileId.steps, TileId.hrv];
      final bands = buildBands(ids, sizeOf);
      expect(bands[0].ids, [TileId.steps, TileId.hrv, null]);
    });

    test('tall tile skips wide/tall tiles when pulling companions', () {
      final ids = [
        TileId.steps,
        TileId.sleepStages,
        TileId.hrv,
        TileId.vo2Max,
      ];
      final bands = buildBands(ids, sizeOf);
      expect(bands[0].ids, [TileId.steps, TileId.hrv, TileId.vo2Max]);
      expect(bands[1].isWide, isTrue);
      expect(bands[1].singleId, TileId.sleepStages);
      expect(bands.length, 2);
    });

    test('even pending flushed before tall: no null padding added to pre-flush band', () {
      final ids = [
        TileId.activeCalories,
        TileId.workouts,
        TileId.steps,
      ];
      final bands = buildBands(ids, sizeOf);
      expect(bands[0].ids, [TileId.activeCalories, TileId.workouts]);
      expect(bands[1].ids.length, 3);
      expect(bands[1].ids[0], TileId.steps);
    });

    test('two consecutive tall tiles each get their own 3-item band', () {
      // Helper that treats both steps AND distance as tall.
      TileSize sizeOfMultiTall(TileId id) => switch (id) {
        TileId.steps       => TileSize.tall,
        TileId.distance    => TileSize.tall,
        TileId.sleepStages => TileSize.wide,
        _                  => TileSize.square,
      };

      final ids = [TileId.steps, TileId.distance];
      final bands = buildBands(ids, sizeOfMultiTall);
      // steps is tall; distance is also tall so no square companions available.
      expect(bands[0].ids, [TileId.steps, null, null]);
      // distance is tall; no remaining square companions.
      expect(bands[1].ids, [TileId.distance, null, null]);
      expect(bands.length, 2);
    });
  });
}
