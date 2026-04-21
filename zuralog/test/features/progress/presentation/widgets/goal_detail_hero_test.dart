/// Smoke test for [GoalDetailHero].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_detail_hero.dart';
import 'package:zuralog/shared/widgets/cards/z_hero_card.dart';

Goal _weightGoal() => Goal(
      id: 'g',
      userId: 'u',
      type: GoalType.custom,
      period: GoalPeriod.weekly,
      title: 'Weight',
      targetValue: 76,
      currentValue: 75.4,
      unit: 'lbs',
      startDate: '2026-04-01',
      progressHistory: const <double>[80, 79, 78, 77.5, 77, 76.5, 76, 75.4],
    );

Widget _wrap(Widget c) => MaterialApp(
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: SingleChildScrollView(child: c)),
    );

void main() {
  testWidgets('renders ZHeroCard, % label, value, target', (tester) async {
    await tester.pumpWidget(_wrap(GoalDetailHero(goal: _weightGoal())));
    expect(find.byType(ZHeroCard), findsOneWidget);
    expect(find.text('99%'), findsOneWidget);
    expect(find.text('75.4'), findsOneWidget);
    expect(find.textContaining('76'), findsWidgets);
  });

  testWidgets('renders the 3-stat footer (REMAINING / DAYS LEFT / STREAK)',
      (tester) async {
    await tester.pumpWidget(_wrap(GoalDetailHero(goal: _weightGoal())));
    expect(find.text('REMAINING'), findsOneWidget);
    expect(find.text('DAYS LEFT'), findsOneWidget);
    expect(find.text('STREAK'), findsOneWidget);
  });
}
