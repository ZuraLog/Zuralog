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
}
