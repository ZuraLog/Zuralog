/// Tests for [ZProgressPill] — renders N segments, fills up to current index.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/shared/widgets/indicators/z_progress_pill.dart';

void main() {
  group('ZProgressPill', () {
    testWidgets('renders the correct number of segments', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ZProgressPill(totalSteps: 3, currentStep: 1),
        ),
      ));

      expect(find.byKey(const ValueKey('z_progress_segment_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('z_progress_segment_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('z_progress_segment_2')), findsOneWidget);
    });

    testWidgets('fills segments up to and including currentStep (0-indexed)',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ZProgressPill(totalSteps: 3, currentStep: 1),
        ),
      ));

      // Resolve theme-aware colors from the same context the widget sees, so
      // the expectation works in both light and dark default theme environments.
      final colors = AppColorsOf(tester.element(find.byType(ZProgressPill)));

      final seg0 = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('z_progress_segment_0')),
      );
      final seg1 = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('z_progress_segment_1')),
      );
      final seg2 = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('z_progress_segment_2')),
      );
      expect((seg0.decoration as BoxDecoration).color, colors.primary);
      expect((seg1.decoration as BoxDecoration).color, colors.primary);
      expect((seg2.decoration as BoxDecoration).color, isNot(colors.primary));
    });
  });
}
