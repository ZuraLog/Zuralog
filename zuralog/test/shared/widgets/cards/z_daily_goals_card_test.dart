import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/cards/z_daily_goals_card.dart';

void main() {
  group('ZDailyGoalsCard', () {
    testWidgets('shows setup prompt when goals list is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZDailyGoalsCard(
              goals: const [],
              onSetupTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('Set a daily goal'), findsOneWidget);
    });

    testWidgets('renders goal labels when goals exist', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZDailyGoalsCard(
              goals: const [
                DailyGoalDisplay(
                  label: 'Water',
                  current: '4',
                  target: '8',
                  unit: 'glasses',
                  fraction: 0.5,
                ),
              ],
              onSetupTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('4 / 8 glasses'), findsOneWidget);
    });

    testWidgets('calls onSetupTap when setup prompt tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZDailyGoalsCard(
              goals: const [],
              onSetupTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Set a daily goal'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('shows at most 4 goals without scrolling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZDailyGoalsCard(
              goals: List.generate(
                6,
                (i) => DailyGoalDisplay(
                  label: 'Goal ${i + 1}',
                  current: '0',
                  target: '10',
                  unit: 'units',
                  fraction: 0.0,
                ),
              ),
              onSetupTap: () {},
            ),
          ),
        ),
      );
      // Only 4 of 6 goals rendered
      expect(find.textContaining('Goal 1'), findsOneWidget);
      expect(find.textContaining('Goal 4'), findsOneWidget);
      expect(find.textContaining('Goal 5'), findsNothing);
    });
  });
}
