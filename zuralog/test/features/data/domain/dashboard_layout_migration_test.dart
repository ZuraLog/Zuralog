import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';

void main() {
  // ── defaultLayout ──────────────────────────────────────────────────────────

  group('DashboardLayout.defaultLayout', () {
    test('has empty tileOrder', () {
      expect(DashboardLayout.defaultLayout.tileOrder, isEmpty);
    });

    test('has empty tileVisibility', () {
      expect(DashboardLayout.defaultLayout.tileVisibility, isEmpty);
    });

    test('has empty tileSizes', () {
      expect(DashboardLayout.defaultLayout.tileSizes, isEmpty);
    });

    test('has empty tileColorOverrides', () {
      expect(DashboardLayout.defaultLayout.tileColorOverrides, isEmpty);
    });
  });

  // ── toJson ─────────────────────────────────────────────────────────────────

  group('DashboardLayout.toJson', () {
    test('includes tile_order key', () {
      final json = DashboardLayout.defaultLayout.toJson();
      expect(json.containsKey('tile_order'), isTrue);
    });

    test('includes tile_visibility key', () {
      final json = DashboardLayout.defaultLayout.toJson();
      expect(json.containsKey('tile_visibility'), isTrue);
    });

    test('includes tile_sizes key', () {
      final json = DashboardLayout.defaultLayout.toJson();
      expect(json.containsKey('tile_sizes'), isTrue);
    });

    test('includes tile_color_overrides key', () {
      final json = DashboardLayout.defaultLayout.toJson();
      expect(json.containsKey('tile_color_overrides'), isTrue);
    });

    test('tile_sizes serialized as string names (not TileSize.tall)', () {
      final layout = DashboardLayout(
        orderedCategories: const [],
        hiddenCategories: const {},
        tileSizes: const {'steps': TileSize.tall},
      );
      final json = layout.toJson();
      final sizes = json['tile_sizes'] as Map<String, dynamic>;
      expect(sizes['steps'], 'tall');
    });
  });

  // ── fromJson new format ────────────────────────────────────────────────────

  group('DashboardLayout.fromJson (new format)', () {
    test('round-trips tileOrder, tileVisibility, tileSizes, tileColorOverrides',
        () {
      final original = DashboardLayout(
        orderedCategories: const ['activity', 'sleep'],
        hiddenCategories: const {'nutrition'},
        tileOrder: const ['steps', 'workouts'],
        tileVisibility: const {'mood': false},
        tileSizes: const {'steps': TileSize.tall, 'weight': TileSize.wide},
        tileColorOverrides: const {'steps': 0xFFFF0000},
      );
      final json = original.toJson();
      final restored = DashboardLayout.fromJson(json);

      expect(restored.tileOrder, ['steps', 'workouts']);
      expect(restored.tileVisibility, {'mood': false});
      expect(restored.tileSizes,
          {'steps': TileSize.tall, 'weight': TileSize.wide});
      expect(restored.tileColorOverrides, {'steps': 0xFFFF0000});
    });
  });

  // ── fromJson old format (migration) ───────────────────────────────────────

  group('DashboardLayout.fromJson (old format migration)', () {
    test('old JSON without tile_order key results in empty tileOrder', () {
      final oldJson = <String, dynamic>{
        'ordered_categories': ['activity', 'sleep'],
        'hidden_categories': <String>[],
        'category_color_overrides': <String, dynamic>{},
        'banner_dismissed': false,
      };
      final layout = DashboardLayout.fromJson(oldJson);
      expect(layout.tileOrder, isEmpty);
    });

    test('old JSON preserves orderedCategories', () {
      final oldJson = <String, dynamic>{
        'ordered_categories': ['activity', 'sleep', 'heart'],
        'hidden_categories': <String>[],
        'category_color_overrides': <String, dynamic>{},
        'banner_dismissed': false,
      };
      final layout = DashboardLayout.fromJson(oldJson);
      expect(layout.orderedCategories, ['activity', 'sleep', 'heart']);
    });
  });

  // ── copyWith ───────────────────────────────────────────────────────────────

  group('DashboardLayout.copyWith', () {
    test('replaces only specified new fields, leaves others unchanged', () {
      final original = DashboardLayout(
        orderedCategories: const ['activity'],
        hiddenCategories: const {'nutrition'},
        categoryColorOverrides: const {'activity': 0xFFFF0000},
        bannerDismissed: true,
        tileOrder: const ['steps'],
        tileVisibility: const {'mood': false},
        tileSizes: const {'steps': TileSize.tall},
        tileColorOverrides: const {'steps': 0xFF0000FF},
      );

      final updated = original.copyWith(tileOrder: ['steps', 'workouts']);

      // Changed field
      expect(updated.tileOrder, ['steps', 'workouts']);

      // Unchanged fields
      expect(updated.orderedCategories, ['activity']);
      expect(updated.hiddenCategories, {'nutrition'});
      expect(updated.categoryColorOverrides, {'activity': 0xFFFF0000});
      expect(updated.bannerDismissed, true);
      expect(updated.tileVisibility, {'mood': false});
      expect(updated.tileSizes, {'steps': TileSize.tall});
      expect(updated.tileColorOverrides, {'steps': 0xFF0000FF});
    });
  });

  // ── Existing fields round-trip ─────────────────────────────────────────────

  group('Existing DashboardLayout fields', () {
    test('orderedCategories, hiddenCategories, categoryColorOverrides, bannerDismissed still round-trip',
        () {
      final original = DashboardLayout(
        orderedCategories: const ['activity', 'sleep', 'heart'],
        hiddenCategories: const {'nutrition', 'cycle'},
        categoryColorOverrides: const {
          'activity': 0xFFFF5733,
          'sleep': 0xFF3399FF,
        },
        bannerDismissed: true,
      );

      final json = original.toJson();
      final restored = DashboardLayout.fromJson(json);

      expect(restored.orderedCategories, ['activity', 'sleep', 'heart']);
      expect(restored.hiddenCategories, {'nutrition', 'cycle'});
      expect(restored.categoryColorOverrides,
          {'activity': 0xFFFF5733, 'sleep': 0xFF3399FF});
      expect(restored.bannerDismissed, true);
    });
  });
}
