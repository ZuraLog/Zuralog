import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/health_score_building_state.dart';

void main() {
  group('HealthScoreBuildingState', () {
    testWidgets('shows day counter and "X more days" for dataDays: 4',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HealthScoreBuildingState(dataDays: 4),
          ),
        ),
      );
      expect(find.text('4/7'), findsOneWidget);
      expect(find.text('3 more days'), findsOneWidget);
      expect(find.text('Health Score'), findsOneWidget);
    });

    testWidgets('shows singular "day" when remaining is 1 (dataDays: 6)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HealthScoreBuildingState(dataDays: 6),
          ),
        ),
      );
      expect(find.text('6/7'), findsOneWidget);
      expect(find.text('1 more day'), findsOneWidget);
    });

    testWidgets('shows "6 more days" for dataDays: 1', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HealthScoreBuildingState(dataDays: 1),
          ),
        ),
      );
      expect(find.text('1/7'), findsOneWidget);
      expect(find.text('6 more days'), findsOneWidget);
    });

    testWidgets('supports custom targetDays', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HealthScoreBuildingState(dataDays: 3, targetDays: 10),
          ),
        ),
      );
      expect(find.text('3/10'), findsOneWidget);
      expect(find.text('7 more days'), findsOneWidget);
    });
  });
}
