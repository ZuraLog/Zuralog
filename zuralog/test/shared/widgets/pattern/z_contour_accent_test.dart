/// Tests for [ZContourAccent] — single drifting sage line used as brand signature.
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
  });
}
