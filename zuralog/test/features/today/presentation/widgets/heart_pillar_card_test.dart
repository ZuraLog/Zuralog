library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/heart/domain/heart_models.dart';
import 'package:zuralog/features/today/presentation/widgets/heart_pillar_card.dart';

void main() {
  Widget buildCard(HeartDaySummary summary) {
    return MaterialApp(
      home: Scaffold(
        body: HeartPillarCard(summary: summary),
      ),
    );
  }

  group('HeartPillarCard — empty state', () {
    testWidgets('shows "No heart data yet" headline', (tester) async {
      await tester.pumpWidget(buildCard(HeartDaySummary.empty));
      expect(find.text('No heart data yet'), findsOneWidget);
    });

    testWidgets('shows "No data yet" context stat', (tester) async {
      await tester.pumpWidget(buildCard(HeartDaySummary.empty));
      expect(find.text('No data yet'), findsOneWidget);
    });

    testWidgets('shows HEART label', (tester) async {
      await tester.pumpWidget(buildCard(HeartDaySummary.empty));
      expect(find.text('HEART'), findsOneWidget);
    });

    testWidgets('does not show bpm unit', (tester) async {
      await tester.pumpWidget(buildCard(HeartDaySummary.empty));
      expect(find.text('bpm'), findsNothing);
    });
  });

  group('HeartPillarCard — data state', () {
    final dataState = HeartDaySummary(
      hasData: true,
      restingHr: 62,
      hrvMs: 45,
      restingHrVs7Day: -3,
    );

    testWidgets('shows resting HR, unit, HRV, and vs avg', (tester) async {
      await tester.pumpWidget(buildCard(dataState));
      expect(find.text('62'), findsOneWidget);
      expect(find.text('bpm'), findsOneWidget);
      // Secondary stats are rendered as RichText spans — use textContaining.
      expect(find.textContaining('45 ms'), findsOneWidget);
      expect(find.textContaining('-3'), findsOneWidget);
    });

    testWidgets('shows en-dash for null resting HR when hasData is true', (tester) async {
      final noHr = HeartDaySummary(hasData: true);
      await tester.pumpWidget(buildCard(noHr));
      expect(find.text('–'), findsWidgets); // at least one en-dash shown
    });
  });
}
