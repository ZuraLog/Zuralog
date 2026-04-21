library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_activity_heatmap.dart';
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
      startDate: '2026-03-22',
      progressHistory: List.generate(30, (i) => 80.0 - i * 0.15),
    );

Widget _wrap(Widget c) => MaterialApp(
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: SingleChildScrollView(child: c)),
    );

void main() {
  testWidgets('renders feature card with DOW header and legend', (tester) async {
    await tester.pumpWidget(_wrap(GoalActivityHeatmap(goal: _g())));
    expect(find.byType(ZFeatureCard), findsOneWidget);
    expect(find.text('M'), findsAtLeast(1));
    expect(find.text('S'), findsAtLeast(2));
    expect(find.text('Less'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });
}
