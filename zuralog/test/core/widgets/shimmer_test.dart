/// Zuralog — AppShimmer + ShimmerBox widget tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/core/widgets/shimmer.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: ThemeData.light(), home: Scaffold(body: child));

void main() {
  group('AppShimmer', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        _wrap(SizedBox(
          width: 200, height: 100,
          child: AppShimmer(
            child: ShimmerBox(height: 20, width: 80),
          ),
        )),
      );
      await tester.pump();
      expect(find.byType(AppShimmer), findsOneWidget);
    });

    testWidgets('wraps child in ShaderMask with srcIn blend mode', (tester) async {
      await tester.pumpWidget(
        _wrap(AppShimmer(child: ShimmerBox(height: 20, width: 80))),
      );
      await tester.pump();
      final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
      expect(mask.blendMode, BlendMode.srcIn);
    });

    testWidgets('animation progresses — pumping frames does not throw',
        (tester) async {
      await tester.pumpWidget(
        _wrap(SizedBox(
          width: 200, height: 100,
          child: AppShimmer(child: ShimmerBox(height: 20, width: 80)),
        )),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      // Verify widget still present after animation frames — no ticker error
      expect(find.byType(AppShimmer), findsOneWidget);
    });
  });

  group('ShimmerBox', () {
    testWidgets('renders with fixed height and width', (tester) async {
      await tester.pumpWidget(
        _wrap(AppShimmer(child: ShimmerBox(height: 20, width: 80))),
      );
      await tester.pump();
      expect(find.byType(ShimmerBox), findsOneWidget);
    });

    testWidgets('renders as circle when isCircle is true', (tester) async {
      await tester.pumpWidget(
        _wrap(AppShimmer(child: ShimmerBox(height: 24, isCircle: true))),
      );
      await tester.pump();
      final container =
          tester.widget<Container>(find.descendant(
            of: find.byType(ShimmerBox),
            matching: find.byType(Container),
          ).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('fills parent when no dimensions provided (inside Expanded)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(AppShimmer(
          child: SizedBox(
            width: 100, height: 50,
            child: Column(
              children: [
                Expanded(child: ShimmerBox()),
              ],
            ),
          ),
        )),
      );
      await tester.pump();
      expect(find.byType(ShimmerBox), findsOneWidget);
    });
  });
}
