import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/presentation/log_screens/run_log_screen.dart';

Widget _wrap(Widget child) => ProviderScope(child: MaterialApp(home: child));

void main() {
  group('RunLogScreen', () {
    testWidgets('shows mode picker with 3 options', (tester) async {
      await tester.pumpWidget(_wrap(const RunLogScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Open Strava'), findsOneWidget);
      expect(find.text('Log a past run'), findsOneWidget);
      expect(find.text('Record live session'), findsOneWidget);
    });

    testWidgets('tapping Log a past run shows the manual form', (tester) async {
      await tester.pumpWidget(_wrap(const RunLogScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log a past run'));
      await tester.pumpAndSettle();
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
    });

    testWidgets('Save button disabled until activity, distance, duration filled', (tester) async {
      await tester.pumpWidget(_wrap(const RunLogScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log a past run'));
      await tester.pumpAndSettle();
      final btn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save Run'));
      expect(btn.onPressed, isNull);
    });

    testWidgets('pace is auto-calculated and shown (not editable)', (tester) async {
      await tester.pumpWidget(_wrap(const RunLogScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log a past run'));
      await tester.pumpAndSettle();
      expect(find.text('Avg pace'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Avg pace'), findsNothing);
    });
  });

  group('calculatePaceSecondsPerKm', () {
    test('5 km in 25 minutes (1500 s) → 300 s/km (5:00/km)', () {
      expect(calculatePaceSecondsPerKm(5.0, 1500), equals(300));
    });

    test('10 km in 60 minutes (3600 s) → 360 s/km (6:00/km)', () {
      expect(calculatePaceSecondsPerKm(10.0, 3600), equals(360));
    });

    test('1 km in 4 min 30 s (270 s) → 270 s/km (4:30/km)', () {
      expect(calculatePaceSecondsPerKm(1.0, 270), equals(270));
    });

    test('0 km distance → null (division by zero guard)', () {
      expect(calculatePaceSecondsPerKm(0.0, 1500), isNull);
    });

    test('negative distance → null', () {
      expect(calculatePaceSecondsPerKm(-1.0, 1500), isNull);
    });

    test('0 duration → null', () {
      expect(calculatePaceSecondsPerKm(5.0, 0), isNull);
    });
  });
}
