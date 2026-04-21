/// Widget tests for [ZFeatureCard].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('ZFeatureCard', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        _wrap(const ZFeatureCard(child: Text('hello'))),
      );
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('uses Surface color and LG radius (no border, no shadow)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const ZFeatureCard(child: SizedBox(width: 100, height: 50))),
      );
      // First decorated container is the surface.
      final container = tester.widgetList<Container>(find.byType(Container)).firstWhere(
        (c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).color != null,
      );
      final dec = container.decoration as BoxDecoration;
      expect(dec.color, AppColors.surface);
      expect(dec.border, isNull);
      expect(dec.boxShadow, isNull);
      expect(
        dec.borderRadius,
        BorderRadius.circular(AppDimens.shapeLg),
      );
    });

    testWidgets('lays a ZPatternOverlay at 7% opacity by default with the Original variant',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const ZFeatureCard(child: SizedBox(width: 100, height: 50))),
      );
      final overlay = tester.widget<ZPatternOverlay>(find.byType(ZPatternOverlay));
      expect(overlay.opacity, 0.07);
      expect(overlay.variant, ZPatternVariant.original);
      expect(overlay.animate, true);
    });

    testWidgets('passes the requested variant to the overlay', (tester) async {
      await tester.pumpWidget(
        _wrap(const ZFeatureCard(
          variant: ZPatternVariant.green,
          child: SizedBox(width: 100, height: 50),
        )),
      );
      final overlay = tester.widget<ZPatternOverlay>(find.byType(ZPatternOverlay));
      expect(overlay.variant, ZPatternVariant.green);
    });

    testWidgets('uses light-mode surface color when theme is light',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: Center(
              child: ZFeatureCard(child: SizedBox(width: 100, height: 50)),
            ),
          ),
        ),
      );
      final container = tester.widgetList<Container>(find.byType(Container)).firstWhere(
        (c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).color != null,
      );
      final dec = container.decoration as BoxDecoration;
      expect(dec.color, AppColors.surfaceLightNew);
    });
  });
}
