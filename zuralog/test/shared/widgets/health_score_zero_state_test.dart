// zuralog/test/shared/widgets/health_score_zero_state_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/health_score_zero_state.dart';

void main() {
  group('HealthScoreZeroState', () {
    testWidgets('shows sad face emoji', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HealthScoreZeroState())),
      );
      expect(find.text('😔'), findsOneWidget);
    });

    testWidgets('shows Health Score label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HealthScoreZeroState())),
      );
      expect(find.text('Health Score'), findsOneWidget);
    });

    testWidgets('shows Log to unlock subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HealthScoreZeroState())),
      );
      expect(find.text('Log to unlock'), findsOneWidget);
    });

    testWidgets('does not show old muted ring or heart icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HealthScoreZeroState())),
      );
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    });
  });
}
