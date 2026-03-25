/// Tests that the health dashboard shows a network error banner when:
/// - The API call failed (hasNetworkError == true)
/// - The user has connected sources (not all tiles show noSource)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/user_profile.dart';
import 'package:zuralog/features/data/data/data_repository.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/presentation/health_dashboard_screen.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/onboarding_tooltip_provider.dart';

// ── Stubs ─────────────────────────────────────────────────────────────────────

class _StubUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfile? build() => null;
}

class _StubTooltipsEnabledNotifier extends TooltipsEnabledNotifier {
  @override
  Future<bool> build() async => false;
}

class _MockDataRepository implements DataRepositoryInterface {
  @override
  Future<DashboardData> getDashboard({bool forceRefresh = false}) async =>
      const DashboardData(categories: [], visibleOrder: [], isNetworkError: true);

  @override
  Future<CategoryDetailData> getCategoryDetail({
    required String categoryId,
    required String timeRange,
  }) async =>
      CategoryDetailData(
        category: HealthCategory.activity,
        metrics: [],
        timeRange: timeRange,
      );

  @override
  Future<MetricDetailData> getMetricDetail({
    required String metricId,
    required String timeRange,
  }) async =>
      MetricDetailData(
        series: MetricSeries(
          metricId: metricId,
          displayName: metricId,
          unit: '',
          dataPoints: [],
        ),
        category: HealthCategory.activity,
      );

  @override
  Future<void> saveDashboardLayout(DashboardLayout layout) async {}

  @override
  Future<DashboardLayout?> getPersistedLayout() async => null;

  @override
  void invalidateAll() {}
}

// ── Router ────────────────────────────────────────────────────────────────────

GoRouter _makeRouter() => GoRouter(
      initialLocation: '/data',
      routes: [
        GoRoute(
          path: '/data',
          builder: (context, state) => const HealthDashboardScreen(),
        ),
        GoRoute(
          path: '/data/metric/:id',
          builder: (context, state) =>
              const Scaffold(body: Text('Metric Detail')),
        ),
        GoRoute(
          path: '/settings/integrations',
          builder: (context, state) =>
              const Scaffold(body: Text('Integrations')),
        ),
        GoRoute(
          path: '/today',
          builder: (context, state) => const Scaffold(body: Text('Today')),
        ),
        GoRoute(
          path: '/coach',
          builder: (context, state) => const Scaffold(body: Text('Coach')),
        ),
      ],
    );

Widget _buildApp(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: _makeRouter()),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Network error banner', () {
    testWidgets(
        'shows "Could not refresh" banner when network error AND some tiles are loaded',
        (tester) async {
      // Mix: some tiles loaded (user has connected sources), some noSource.
      final mixedTiles = [
        TileData(
          tileId: TileId.steps,
          dataState: TileDataState.loaded,
          lastUpdated: '2026-03-19T12:00:00Z',
          primaryValue: '8432',
        ),
        ...TileId.values
            .where((id) => id != TileId.steps)
            .map((id) => TileData(
                  tileId: id,
                  dataState: TileDataState.noSource,
                )),
      ];

      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith(() => _StubUserProfileNotifier()),
          tooltipsEnabledProvider
              .overrideWith(() => _StubTooltipsEnabledNotifier()),
          dataRepositoryProvider.overrideWith((ref) => _MockDataRepository()),
          // Dashboard fetch failed — network error.
          dashboardProvider.overrideWith(
            (_) async => const DashboardData(
              categories: [],
              visibleOrder: [],
              isNetworkError: true,
            ),
          ),
          // dashboardHasNetworkErrorProvider derives from dashboardProvider,
          // but override it directly to guarantee the test condition.
          dashboardHasNetworkErrorProvider.overrideWith((_) => true),
          // Tiles have at least one loaded tile — user has connected sources.
          dashboardTilesProvider.overrideWith((_) async => mixedTiles),
          dashboardLayoutLoaderProvider.overrideWith((_) async => null),
          healthScoreProvider.overrideWith(
            (_) async => const HealthScoreData(score: 0, trend: [], dataDays: 0),
          ),
          dailyGoalsProvider.overrideWith((_) async => const <DailyGoal>[]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // The banner must be visible with the expected text.
      expect(
        find.textContaining('Could not refresh'),
        findsOneWidget,
      );
    });

    testWidgets(
        'does NOT show banner when all tiles are noSource (onboarding empty state instead)',
        (tester) async {
      // All noSource — user hasn't connected any sources.
      final allNoSourceTiles = TileId.values
          .map((id) => TileData(tileId: id, dataState: TileDataState.noSource))
          .toList();

      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith(() => _StubUserProfileNotifier()),
          tooltipsEnabledProvider
              .overrideWith(() => _StubTooltipsEnabledNotifier()),
          dataRepositoryProvider.overrideWith((ref) => _MockDataRepository()),
          dashboardProvider.overrideWith(
            (_) async => const DashboardData(
              categories: [],
              visibleOrder: [],
              isNetworkError: true,
            ),
          ),
          dashboardHasNetworkErrorProvider.overrideWith((_) => true),
          dashboardTilesProvider.overrideWith((_) async => allNoSourceTiles),
          dashboardLayoutLoaderProvider.overrideWith((_) async => null),
          healthScoreProvider.overrideWith(
            (_) async => const HealthScoreData(score: 0, trend: [], dataDays: 0),
          ),
          dailyGoalsProvider.overrideWith((_) async => const <DailyGoal>[]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // Banner should NOT appear — the full "source unavailable" empty state
      // is shown instead (allNoSource && hasNetworkError branch).
      expect(find.textContaining('Could not refresh'), findsNothing);
    });

    testWidgets(
        'does NOT show banner when no network error even if tiles are loaded',
        (tester) async {
      final loadedTiles = TileId.values
          .map((id) => TileData(
                tileId: id,
                dataState: TileDataState.loaded,
                lastUpdated: '2026-03-19T12:00:00Z',
                primaryValue: '42',
              ))
          .toList();

      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith(() => _StubUserProfileNotifier()),
          tooltipsEnabledProvider
              .overrideWith(() => _StubTooltipsEnabledNotifier()),
          dataRepositoryProvider.overrideWith((ref) => _MockDataRepository()),
          dashboardProvider.overrideWith(
            (_) async => const DashboardData(
              categories: [],
              visibleOrder: [],
              isNetworkError: false,
            ),
          ),
          dashboardHasNetworkErrorProvider.overrideWith((_) => false),
          dashboardTilesProvider.overrideWith((_) async => loadedTiles),
          dashboardLayoutLoaderProvider.overrideWith((_) async => null),
          healthScoreProvider.overrideWith(
            (_) async => const HealthScoreData(score: 72, trend: [], dataDays: 10),
          ),
          dailyGoalsProvider.overrideWith((_) async => const <DailyGoal>[]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not refresh'), findsNothing);
    });
  });
}
