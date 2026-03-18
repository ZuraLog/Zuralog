import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/user_profile.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/presentation/today_feed_screen.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/cards/z_daily_goals_card.dart';
import 'package:zuralog/shared/widgets/streak_hero_card.dart';

// ── Stub notifiers ────────────────────────────────────────────────────────────

/// Returns a fixed snapshot card list without hitting real data sources.
class _StubSnapshotNotifier extends SnapshotNotifier {
  _StubSnapshotNotifier(this._value);
  final List<SnapshotCardData> _value;
  @override
  Future<List<SnapshotCardData>> build() async => _value;
}

/// Returns null profile without making any network calls.
class _StubUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfile? build() => null;
}

/// Returns safe default preferences without making any network calls.
class _StubUserPreferencesNotifier extends UserPreferencesNotifier {
  @override
  Future<UserPreferencesModel> build() async {
    return const UserPreferencesModel(id: 'test', userId: 'test');
  }

  @override
  Future<void> save(UserPreferencesModel updated) async {
    state = AsyncData(updated);
  }

  @override
  Future<void> mutate(
      UserPreferencesModel Function(UserPreferencesModel) fn) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(fn(current));
  }

  @override
  Future<void> refresh() async {}
}

GoRouter _router() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const TodayFeedScreen(),
        ),
      ],
    );

ProviderContainer _container({
  List<DailyGoal> dailyGoals = const [],
}) =>
    ProviderContainer(
      overrides: [
        userProfileProvider.overrideWith(() => _StubUserProfileNotifier()),
        userPreferencesProvider
            .overrideWith(() => _StubUserPreferencesNotifier()),
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
        snapshotProvider.overrideWith(
          () => _StubSnapshotNotifier(const []),
        ),
        userLoggedTypesProvider.overrideWith(
          (ref) async => const <String>{},
        ),
        goalsProvider.overrideWith(
          (ref) async => const GoalList(goals: []),
        ),
        dailyGoalsProvider.overrideWith(
          (ref) async => dailyGoals,
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

    testWidgets('renders StreakHeroCard', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StreakHeroCard), findsOneWidget);
    });

    testWidgets('renders ZDailyGoalsCard with setup prompt', (tester) async {
      // dailyGoalsProvider returns empty list → card shows setup prompt.
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

    testWidgets('renders ZDailyGoalsCard with goal progress bars when data is present',
        (tester) async {
      final container = _container(
        dailyGoals: const [
          DailyGoal(
            id: 'g1',
            label: 'Steps',
            current: 6240,
            target: 8000,
            unit: 'steps',
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ZDailyGoalsCard), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('Set a daily goal'), findsNothing);
    });

    testWidgets('invalidates dailyGoalsProvider when goalsProvider emits new data',
        (tester) async {
      // Track how many times dailyGoalsProvider was called (i.e. built/re-fetched).
      var dailyGoalsFetchCount = 0;

      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith(() => _StubUserProfileNotifier()),
          userPreferencesProvider
              .overrideWith(() => _StubUserPreferencesNotifier()),
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
          snapshotProvider.overrideWith(
            () => _StubSnapshotNotifier(const []),
          ),
          userLoggedTypesProvider.overrideWith(
            (ref) async => const <String>{},
          ),
          goalsProvider.overrideWith(
            (ref) async => const GoalList(goals: []),
          ),
          dailyGoalsProvider.overrideWith((ref) async {
            dailyGoalsFetchCount++;
            return const <DailyGoal>[];
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await tester.pumpAndSettle();

      final initialFetchCount = dailyGoalsFetchCount;

      // Simulate the Progress tab invalidating goalsProvider after a goal change.
      container.invalidate(goalsProvider);
      await tester.pumpAndSettle();

      // The ref.listen in TodayFeedScreen should have re-fetched dailyGoalsProvider.
      expect(dailyGoalsFetchCount, greaterThan(initialFetchCount));
    });
  });
}
