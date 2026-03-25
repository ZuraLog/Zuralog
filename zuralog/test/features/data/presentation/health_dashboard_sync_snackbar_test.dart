/// Tests that a SnackBar with "Sync failed" text is shown when pull-to-refresh
/// triggers syncToCloud() and it returns false.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/health/health_bridge.dart';
import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/user_profile.dart';
import 'package:zuralog/features/data/data/data_repository.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/presentation/health_dashboard_screen.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/features/health/data/health_repository.dart';
import 'package:zuralog/features/health/data/health_sync_service.dart';
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
      const DashboardData(categories: [], visibleOrder: []);

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

/// A [HealthSyncService] stub that always returns [false] from [syncToCloud].
///
/// Constructed with lightweight real dependencies so the super constructor
/// doesn't crash (none of the fields are accessed because [syncToCloud]
/// is fully overridden).
class _FailingHealthSyncService extends HealthSyncService {
  _FailingHealthSyncService()
      : super(
          healthRepository: HealthRepository(bridge: HealthBridge()),
          apiClient: ApiClient(),
        );

  @override
  Future<bool> syncToCloud({int days = 7}) async => false;
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
  setUp(() {
    // Simulate that the Apple Health integration is connected so the
    // pull-to-refresh actually calls syncToCloud().
    SharedPreferences.setMockInitialValues({
      'integration_connected_apple_health': true,
    });
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Pull-to-refresh sync failure snackbar', () {
    testWidgets(
        'shows "Sync failed" SnackBar when syncToCloud returns false',
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
          healthSyncServiceProvider
              .overrideWith((ref) => _FailingHealthSyncService()),
          dashboardProvider.overrideWith(
            (_) async => const DashboardData(categories: [], visibleOrder: []),
          ),
          dashboardHasNetworkErrorProvider.overrideWith((_) => false),
          dashboardTilesProvider.overrideWith((_) async => loadedTiles),
          dashboardLayoutLoaderProvider.overrideWith((_) async => null),
          healthScoreProvider.overrideWith(
            (_) async =>
                const HealthScoreData(score: 72, trend: [], dataDays: 10),
          ),
          dailyGoalsProvider.overrideWith((_) async => const <DailyGoal>[]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // Trigger pull-to-refresh by dragging from the top of the scroll view.
      await tester.fling(
        find.byType(CustomScrollView).first,
        const Offset(0, 400),
        800,
      );
      // Allow the refresh indicator to show and the async callback to complete.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // SnackBar with "Sync failed" must be visible.
      expect(find.textContaining('Sync failed'), findsOneWidget);
    });
  });
}
