library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_milestones_track.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';

Goal _g({double current = 60, double target = 100}) => Goal(
      id: 'g',
      userId: 'u',
      type: GoalType.custom,
      period: GoalPeriod.weekly,
      title: 'Test',
      targetValue: target,
      currentValue: current,
      unit: 'units',
      startDate: '2026-04-01',
      progressHistory: const <double>[10, 20, 30, 40, 50, 60],
    );

Widget _wrap(Widget c) => MaterialApp(
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: SingleChildScrollView(child: c)),
    );

void main() {
  testWidgets('renders a feature card with all 5 percentage labels',
      (tester) async {
    await tester.pumpWidget(_wrap(GoalMilestonesTrack(goal: _g())));
    expect(find.byType(ZFeatureCard), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });
}
