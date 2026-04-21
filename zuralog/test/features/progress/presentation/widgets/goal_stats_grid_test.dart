library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_stats_grid.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';

Goal _g() => Goal(
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
      deadline: '2026-04-30',
    );

Widget _wrap(Widget c) => MaterialApp(
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: SingleChildScrollView(child: c)),
    );

void main() {
  testWidgets('renders 4 ZFeatureCard tiles in a 2x2 grid', (tester) async {
    await tester.pumpWidget(_wrap(GoalStatsGrid(goal: _g())));
    expect(find.byType(ZFeatureCard), findsNWidgets(4));
  });

  testWidgets('shows the four stat labels', (tester) async {
    await tester.pumpWidget(_wrap(GoalStatsGrid(goal: _g())));
    expect(find.text('VELOCITY'), findsOneWidget);
    expect(find.text('PROJECTED END'), findsOneWidget);
    expect(find.text('TIME LEFT'), findsOneWidget);
    expect(find.text('LOG STREAK'), findsOneWidget);
  });
}
