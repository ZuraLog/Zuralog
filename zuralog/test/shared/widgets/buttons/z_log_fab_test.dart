import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/buttons/z_log_fab.dart';

void main() {
  group('ZLogFab', () {
    testWidgets('renders a FloatingActionButton with + icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: ZLogFab(onPressed: () {}),
          ),
        ),
      );
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: ZLogFab(onPressed: () => tapCount++),
          ),
        ),
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(tapCount, 1);
    });

    testWidgets('does not absorb taps — caller controls debounce',
        (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: ZLogFab(onPressed: () => tapCount++),
          ),
        ),
      );
      // Two rapid taps — ZLogFab itself does NOT debounce.
      // The caller is responsible for debouncing.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(tapCount, 2);
    });
  });
}
