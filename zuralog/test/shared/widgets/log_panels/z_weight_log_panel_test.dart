import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/log_panels/z_weight_log_panel.dart';

Widget _wrap(
  Widget child, {
  Map<String, dynamic> latestWeight = const {},
}) {
  return ProviderScope(
    overrides: [
      todayLogSummaryProvider.overrideWith(
        (ref) async => TodayLogSummary.empty,
      ),
      latestLogValuesProvider(latestLogValuesKey(const {'weight'})).overrideWith(
        (ref) async => latestWeight.isEmpty
            ? const <String, dynamic>{}
            : {'weight': latestWeight},
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('ZWeightLogPanel', () {
    testWidgets('Shows default 70.0 kg and dash when no previous log', (tester) async {
      await tester.pumpWidget(_wrap(ZWeightLogPanel(
        onSave: (_) async {},
        onBack: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('70'), findsOneWidget);
      expect(find.textContaining('Last logged: —'), findsOneWidget);
    });

    testWidgets('Pre-fills with latest logged weight from cloud brain', (tester) async {
      await tester.pumpWidget(_wrap(
        ZWeightLogPanel(onSave: (_) async {}, onBack: () {}),
        latestWeight: {
          'value_kg': 78.4,
          'logged_at': '2026-03-15T08:22:00Z',
          'source': 'apple_health',
        },
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('78.4'), findsOneWidget);
      expect(find.textContaining('Apple Health'), findsOneWidget);
    });

    testWidgets('Delta indicator shows positive delta after increment', (tester) async {
      await tester.pumpWidget(_wrap(
        ZWeightLogPanel(onSave: (_) async {}, onBack: () {}),
        latestWeight: {
          'value_kg': 78.0,
          'logged_at': '2026-03-15T08:22:00Z',
          'source': 'manual',
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect(find.textContaining('+0.1'), findsOneWidget);
    });

    testWidgets('Save calls onSave with current value in kg', (tester) async {
      double? savedKg;
      await tester.pumpWidget(_wrap(ZWeightLogPanel(
        onSave: (kg) async => savedKg = kg,
        onBack: () {},
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(savedKg, isNotNull);
      expect(savedKg, closeTo(70.0, 0.1));
    });

    testWidgets('Last logged omits source for manual entries', (tester) async {
      await tester.pumpWidget(_wrap(
        ZWeightLogPanel(onSave: (_) async {}, onBack: () {}),
        latestWeight: {
          'value_kg': 75.0,
          'logged_at': '2026-03-10T09:00:00Z',
          'source': 'manual',
        },
      ));
      await tester.pumpAndSettle();

      // The source text should not appear for manual entries
      expect(find.textContaining('manual'), findsNothing);
      expect(find.textContaining('Manual'), findsNothing);
      // The date should still appear
      expect(find.textContaining('Last logged:'), findsOneWidget);
    });
  });

  group('formatWeightDelta', () {
    test('gain: 80.0 → 80.5 kg shows "+0.5 kg"', () {
      expect(formatWeightDelta(80.0, 80.5), equals('+0.5 kg'));
    });

    test('loss: 80.0 → 79.3 kg shows "-0.7 kg"', () {
      expect(formatWeightDelta(80.0, 79.3), equals('-0.7 kg'));
    });

    test('no previous entry → null', () {
      expect(formatWeightDelta(null, 80.0), isNull);
    });

    test('negligible change (< 0.05 kg) → null', () {
      expect(formatWeightDelta(80.0, 80.02), isNull);
    });
  });
}
