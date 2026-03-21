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
}
