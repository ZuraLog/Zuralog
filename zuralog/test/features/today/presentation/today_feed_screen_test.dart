import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/presentation/today_feed_screen.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/cards/z_daily_goals_card.dart';
import 'package:zuralog/shared/widgets/health/z_log_ring_widget.dart';

GoRouter _router() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const TodayFeedScreen(),
        ),
      ],
    );

ProviderContainer _container() => ProviderContainer(
      overrides: [
        healthScoreProvider.overrideWith(
          (ref) async =>
              const HealthScoreData(score: 78, trend: [], dataDays: 5),
        ),
        todayFeedProvider.overrideWith(
          (ref) async => TodayFeedData(insights: [], streak: null),
        ),
        todayLogSummaryProvider.overrideWith(
          (ref) async => TodayLogSummary.empty,
        ),
        logRingProvider.overrideWith(
          (ref) async => const LogRingState(loggedCount: 0, totalCount: 0),
        ),
        snapshotProvider.overrideWith(
          (ref) async => const <SnapshotCardData>[],
        ),
        userLoggedTypesProvider.overrideWith(
          (ref) async => const <String>{},
        ),
      ],
    );

void main() {
  group('TodayFeedScreen', () {
    testWidgets('renders without error', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TodayFeedScreen), findsOneWidget);
    });

    testWidgets('does NOT render Quick Actions section', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Quick Actions'), findsNothing);
    });

    testWidgets('does NOT render Wellness Check-in card', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('How are you feeling today?'), findsNothing);
    });

    testWidgets('renders ZLogRingWidget', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ZLogRingWidget), findsOneWidget);
    });

    testWidgets('renders ZDailyGoalsCard with setup prompt', (tester) async {
      // ZDailyGoalsCard is a pure display component — data is passed via
      // goals: const [] hardcoded stub. No provider needed.
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ZDailyGoalsCard), findsOneWidget);
      expect(find.text('Set a daily goal'), findsOneWidget);
    });
  });
}
