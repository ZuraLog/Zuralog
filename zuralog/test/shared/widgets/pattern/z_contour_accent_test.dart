/// Tests for [ZContourAccent] — drifting three-line sage contour band used as a brand signature.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/shared/widgets/pattern/z_contour_accent.dart';

void main() {
  group('ZContourAccent', () {
    testWidgets('renders with a bounded parent', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 90,
            child: ZContourAccent(),
          ),
        ),
      ));

      expect(find.byType(ZContourAccent), findsOneWidget);
    });

    testWidgets('respects animate: false without throwing', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 90,
            child: ZContourAccent(animate: false),
          ),
        ),
      ));

      // Pump well beyond the animation duration to confirm no unhandled
      // timers remain.
      await tester.pump(const Duration(seconds: 30));

      expect(find.byType(ZContourAccent), findsOneWidget);
    });

    testWidgets('respects MediaQuery reduced-motion', (tester) async {
      await tester.pumpWidget(const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 90,
              child: ZContourAccent(),
            ),
          ),
        ),
      ));

      // Pump well past the duration — with reduced-motion enforced the
      // controller should be stopped, so no orphan timers should remain.
      await tester.pump(const Duration(seconds: 30));

      expect(find.byType(ZContourAccent), findsOneWidget);
    });
  });
}
