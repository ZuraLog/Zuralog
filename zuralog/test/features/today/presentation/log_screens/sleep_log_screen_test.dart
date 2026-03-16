import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/presentation/log_screens/sleep_log_screen.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: child),
    );

void main() {
  group('SleepLogScreen', () {
    testWidgets('renders bedtime and wake time fields', (tester) async {
      await tester.pumpWidget(_wrap(const SleepLogScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Bedtime'), findsOneWidget);
      expect(find.text('Wake time'), findsOneWidget);
    });

    testWidgets('Save button is disabled before both times are set',
        (tester) async {
      await tester.pumpWidget(_wrap(const SleepLogScreen()));
      await tester.pumpAndSettle();
      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save Sleep'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('renders quality emoji picker', (tester) async {
      await tester.pumpWidget(_wrap(const SleepLogScreen()));
      await tester.pumpAndSettle();
      expect(find.text('😩'), findsOneWidget);
      expect(find.text('😄'), findsOneWidget);
    });

    testWidgets('renders factors chip row', (tester) async {
      await tester.pumpWidget(_wrap(const SleepLogScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Caffeine'), findsOneWidget);
      expect(find.text('Alcohol'), findsOneWidget);
    });
  });
}
