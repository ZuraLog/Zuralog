library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_trend_chart_card.dart';
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
    );

Widget _wrap(Widget c) => MaterialApp(
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: SingleChildScrollView(child: c)),
    );

void main() {
  testWidgets('renders inside ZFeatureCard with title and 3 tabs',
      (tester) async {
    await tester.pumpWidget(_wrap(GoalTrendChartCard(goal: _g())));
    expect(find.byType(ZFeatureCard), findsOneWidget);
    expect(find.textContaining('Weight'), findsWidgets);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('switches active tab on tap without throwing', (tester) async {
    await tester.pumpWidget(_wrap(GoalTrendChartCard(goal: _g())));
    await tester.tap(find.text('Week'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
