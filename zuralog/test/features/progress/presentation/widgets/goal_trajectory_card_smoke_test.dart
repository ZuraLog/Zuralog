/// Render-without-throw smoke test for [GoalTrajectoryCard] post-redesign.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_trajectory_card.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';
import 'package:zuralog/shared/widgets/feedback/z_progress_bar.dart';
import 'package:zuralog/shared/widgets/indicators/z_category_icon_tile.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders ZFeatureCard, ZCategoryIconTile, and ZProgressBar',
      (tester) async {
    const goal = Goal(
      id: 'g1',
      userId: 'u1',
      type: GoalType.stepCount,
      period: GoalPeriod.daily,
      title: 'Daily steps',
      targetValue: 10000,
      currentValue: 8000,
      unit: 'steps',
      startDate: '2026-01-01',
      progressHistory: [],
      trendDirection: 'on_track',
    );
    await tester.pumpWidget(_wrap(GoalTrajectoryCard(
      goal: goal,
      onTap: () {},
    )));
    expect(find.byType(ZFeatureCard), findsOneWidget);
    expect(find.byType(ZCategoryIconTile), findsOneWidget);
    expect(find.byType(ZProgressBar), findsOneWidget);
  });
}
