/// Smoke test for [GoalCoachTakeCard].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_coach_take_card.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';

Widget _wrap(Widget c) => MaterialApp(
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: c),
    );

void main() {
  testWidgets('renders nothing when commentary is null', (tester) async {
    await tester.pumpWidget(_wrap(const GoalCoachTakeCard(
      commentary: null,
      isPremium: true,
    )));
    expect(find.byType(ZFeatureCard), findsNothing);
  });

  testWidgets('renders feature card and commentary text when present',
      (tester) async {
    await tester.pumpWidget(_wrap(const GoalCoachTakeCard(
      commentary: 'You are doing great. Keep it up.',
      isPremium: true,
    )));
    expect(find.byType(ZFeatureCard), findsOneWidget);
    expect(find.textContaining('You are doing great'), findsOneWidget);
    expect(find.text('Coach'), findsOneWidget);
  });

  testWidgets('splits "→ Next milestone:" into a recommendation pill',
      (tester) async {
    const text =
        'Strong downward trend.\n→ Next milestone: hit 76 lbs by April 30.';
    await tester.pumpWidget(_wrap(const GoalCoachTakeCard(
      commentary: text,
      isPremium: true,
    )));
    expect(find.textContaining('Strong downward trend'), findsOneWidget);
    expect(find.textContaining('Next milestone'), findsOneWidget);
  });
}
