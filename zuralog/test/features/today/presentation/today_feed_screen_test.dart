import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/user_profile.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/presentation/today_feed_screen.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/cards/z_daily_goals_card.dart';
import 'package:zuralog/shared/widgets/health/z_log_ring_widget.dart';

// ── Stub notifiers ────────────────────────────────────────────────────────────

/// Returns a fixed [LogRingState] without hitting real data sources.
class _StubLogRingNotifier extends LogRingNotifier {
  _StubLogRingNotifier(this._value);
  final LogRingState _value;
  @override
  Future<LogRingState> build() async => _value;
}

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

ProviderContainer _container() => ProviderContainer(
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
        logRingProvider.overrideWith(
          () => _StubLogRingNotifier(const LogRingState(loggedCount: 0, totalCount: 0)),
        ),
        snapshotProvider.overrideWith(
          () => _StubSnapshotNotifier(const []),
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
