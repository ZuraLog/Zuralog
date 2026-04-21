/// Widget tests for [ZHeroCard].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/shared/widgets/cards/z_hero_card.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('ZHeroCard', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(_wrap(const ZHeroCard(child: Text('hero'))));
      expect(find.text('hero'), findsOneWidget);
    });

    testWidgets('uses Surface color, LG radius, no border, no shadow',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const ZHeroCard(child: SizedBox(width: 100, height: 50))),
      );
      final container = tester.widgetList<Container>(find.byType(Container)).firstWhere(
        (c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).color != null,
      );
      final dec = container.decoration as BoxDecoration;
      expect(dec.color, AppColors.surface);
      expect(dec.border, isNull);
      expect(dec.boxShadow, isNull);
      expect(dec.borderRadius, BorderRadius.circular(AppDimens.shapeLg));
    });

    testWidgets('renders Original.PNG pattern at 10% opacity, animated',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const ZHeroCard(child: SizedBox(width: 100, height: 50))),
      );
      final overlay = tester.widget<ZPatternOverlay>(find.byType(ZPatternOverlay));
      expect(overlay.variant, ZPatternVariant.original);
      expect(overlay.opacity, 0.10);
      expect(overlay.animate, true);
    });

    testWidgets('passes the supplied variant to the overlay', (tester) async {
      await tester.pumpWidget(
        _wrap(const ZHeroCard(
          variant: ZPatternVariant.skyBlue,
          child: SizedBox(width: 100, height: 50),
        )),
      );
      final overlay = tester.widget<ZPatternOverlay>(find.byType(ZPatternOverlay));
      expect(overlay.variant, ZPatternVariant.skyBlue);
    });

    testWidgets('uses light-mode surface color when theme is light',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: Center(
              child: ZHeroCard(child: SizedBox(width: 100, height: 50)),
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
