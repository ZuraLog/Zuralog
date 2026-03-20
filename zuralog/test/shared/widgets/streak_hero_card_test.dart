// zuralog/test/shared/widgets/streak_hero_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

void main() {
  group('StreakHeroCard — zero state', () {
    testWidgets('shows ghost flame at low opacity when streak is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StreakHeroCard(streakDays: 0))),
      );
      // Ghost flame is present (rendered as text emoji inside an Opacity widget)
      final opacityFinder = find.byType(Opacity);
      expect(opacityFinder, findsAtLeastNWidgets(1));
      final opacity = tester.widget<Opacity>(opacityFinder.first);
      expect(opacity.opacity, lessThan(0.5));
    });

    testWidgets('shows inviting label when streak is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StreakHeroCard(streakDays: 0))),
      );
      expect(find.text('Start your streak today'), findsOneWidget);
    });

    testWidgets('shows sub-label when streak is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StreakHeroCard(streakDays: 0))),
      );
      expect(find.text('Log anything to begin'), findsOneWidget);
    });
  });

  group('StreakHeroCard — active state', () {
    testWidgets('shows streak number when streak > 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StreakHeroCard(streakDays: 7))),
      );
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('shows "day streak" label when streak > 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StreakHeroCard(streakDays: 7))),
      );
      expect(find.text('day streak'), findsOneWidget);
    });

    testWidgets('shows personal best label when isPersonalBest is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakHeroCard(streakDays: 28, isPersonalBest: true),
          ),
        ),
      );
      expect(find.textContaining('Personal best'), findsOneWidget);
    });

    testWidgets('shows keep it up label when not personal best', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakHeroCard(streakDays: 5, isPersonalBest: false),
          ),
        ),
      );
      expect(find.text('Keep it up!'), findsOneWidget);
    });
  });

  group('StreakHeroCard — frozen state', () {
    testWidgets('shows "Streak frozen" when isFrozen is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakHeroCard(streakDays: 10, isFrozen: true),
          ),
        ),
      );
      expect(find.text('Streak frozen'), findsOneWidget);
      expect(find.text('Keep it up!'), findsNothing);
      expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
    });

    testWidgets('frozen takes priority over personal best', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakHeroCard(
              streakDays: 10,
              isFrozen: true,
              isPersonalBest: true,
            ),
          ),
        ),
      );
      expect(find.text('Streak frozen'), findsOneWidget);
      expect(find.textContaining('Personal best'), findsNothing);
    });

    testWidgets('isFrozen is ignored when streakDays is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakHeroCard(streakDays: 0, isFrozen: true),
          ),
        ),
      );
      // Zero state renders regardless of isFrozen
      expect(find.text('Start your streak today'), findsOneWidget);
      expect(find.text('Streak frozen'), findsNothing);
    });
  });
}
