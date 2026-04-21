/// Widget tests for [ZMiniRing].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/shared/widgets/charts/z_mini_ring.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('ZMiniRing', () {
    testWidgets('renders at the default 36×36 size', (tester) async {
      await tester.pumpWidget(_wrap(const ZMiniRing(
        value: 0.5,
        color: AppColors.categoryActivity,
      )));
      final size = tester.getSize(find.byType(ZMiniRing));
      expect(size.width, 36);
      expect(size.height, 36);
    });

    testWidgets('honors a custom size', (tester) async {
      await tester.pumpWidget(_wrap(const ZMiniRing(
        value: 0.5,
        color: AppColors.categoryActivity,
        size: 48,
      )));
      final size = tester.getSize(find.byType(ZMiniRing));
      expect(size.width, 48);
      expect(size.height, 48);
    });

    testWidgets('clamps value to 0..1', (tester) async {
      await tester.pumpWidget(_wrap(const ZMiniRing(
        value: 1.5,
        color: AppColors.categoryActivity,
      )));
      expect(tester.takeException(), isNull);
    });

    testWidgets('value of 0 renders empty (no fill arc)', (tester) async {
      await tester.pumpWidget(_wrap(const ZMiniRing(
        value: 0,
        color: AppColors.categoryActivity,
      )));
      expect(tester.takeException(), isNull);
    });
  });
}
