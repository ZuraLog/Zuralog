/// Widget tests for [ZCategoryIconTile].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/shared/widgets/indicators/z_category_icon_tile.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('ZCategoryIconTile', () {
    testWidgets('renders the icon glyph', (tester) async {
      await tester.pumpWidget(_wrap(const ZCategoryIconTile(
        color: AppColors.categoryActivity,
        icon: Icons.directions_walk_rounded,
      )));
      expect(find.byIcon(Icons.directions_walk_rounded), findsOneWidget);
    });

    testWidgets('paints the category color as the tile fill', (tester) async {
      await tester.pumpWidget(_wrap(const ZCategoryIconTile(
        color: AppColors.categoryActivity,
        icon: Icons.directions_walk_rounded,
      )));
      final container = tester.widget<Container>(
        find.byKey(const ValueKey('z-category-icon-tile-fill')),
      );
      final dec = container.decoration as BoxDecoration;
      expect(dec.color, AppColors.categoryActivity);
    });

    testWidgets('overlays the matching pattern variant at 15% opacity',
        (tester) async {
      await tester.pumpWidget(_wrap(const ZCategoryIconTile(
        color: AppColors.categoryActivity,
        icon: Icons.directions_walk_rounded,
      )));
      final overlay = tester.widget<ZPatternOverlay>(find.byType(ZPatternOverlay));
      expect(overlay.variant, ZPatternVariant.green);
      expect(overlay.opacity, 0.15);
      expect(overlay.animate, true);
    });

    testWidgets('uses Sage variant when color is Sage', (tester) async {
      await tester.pumpWidget(_wrap(const ZCategoryIconTile(
        color: AppColors.primary, // Sage
        icon: Icons.edit_rounded,
      )));
      final overlay = tester.widget<ZPatternOverlay>(find.byType(ZPatternOverlay));
      expect(overlay.variant, ZPatternVariant.sage);
    });

    testWidgets('uses Amber variant when color is Streak Warm', (tester) async {
      await tester.pumpWidget(_wrap(const ZCategoryIconTile(
        color: AppColors.streakWarm,
        icon: Icons.local_fire_department_rounded,
      )));
      final overlay = tester.widget<ZPatternOverlay>(find.byType(ZPatternOverlay));
      expect(overlay.variant, ZPatternVariant.amber);
    });

    testWidgets('renders at the requested size (default 44x44)',
        (tester) async {
      await tester.pumpWidget(_wrap(const ZCategoryIconTile(
        color: AppColors.categoryActivity,
        icon: Icons.directions_walk_rounded,
      )));
      final box = tester.getSize(find.byKey(const ValueKey('z-category-icon-tile-fill')));
      expect(box.width, 44);
      expect(box.height, 44);
    });

    testWidgets('honors a custom size', (tester) async {
      await tester.pumpWidget(_wrap(const ZCategoryIconTile(
        color: AppColors.categoryActivity,
        icon: Icons.directions_walk_rounded,
        size: 56,
      )));
      final box = tester.getSize(find.byKey(const ValueKey('z-category-icon-tile-fill')));
      expect(box.width, 56);
      expect(box.height, 56);
    });
  });
}
