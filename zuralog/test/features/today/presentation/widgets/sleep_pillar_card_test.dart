library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/sleep/domain/sleep_models.dart';
import 'package:zuralog/features/sleep/providers/sleep_providers.dart';
import 'package:zuralog/features/today/presentation/widgets/sleep_pillar_card.dart';

void main() {
  Widget buildCard({required SleepDaySummary summary}) {
    return ProviderScope(
      overrides: [
        sleepDaySummaryProvider.overrideWith((ref) async => summary),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SleepPillarCard()),
      ),
    );
  }

  group('SleepPillarCard — empty state', () {
    testWidgets('shows "No sleep yet" headline', (tester) async {
      await tester.pumpWidget(buildCard(summary: SleepDaySummary.empty));
      await tester.pump(); // let FutureProvider resolve
      expect(find.text('No sleep yet'), findsOneWidget);
    });

    testWidgets('shows "No data yet" context stat', (tester) async {
      await tester.pumpWidget(buildCard(summary: SleepDaySummary.empty));
      await tester.pump();
      expect(find.text('No data yet'), findsOneWidget);
    });

    testWidgets('shows SLEEP label', (tester) async {
      await tester.pumpWidget(buildCard(summary: SleepDaySummary.empty));
      await tester.pump();
      expect(find.text('SLEEP'), findsOneWidget);
    });
  });

  group('SleepPillarCard — data state', () {
    testWidgets('shows formatted duration', (tester) async {
      const summary = SleepDaySummary(
        hasData: true,
        durationMinutes: 450,
      );
      await tester.pumpWidget(buildCard(summary: summary));
      await tester.pump();
      expect(find.text('7h 30m'), findsOneWidget);
    });
  });
}
