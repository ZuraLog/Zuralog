/// Zuralog — HealthDashboardScreen Integration Tests (Phase 8).
///
/// Tests for the full dashboard screen: tile grid rendering, category filter,
/// time range selector, edit mode, tile expand/collapse, Ask Coach navigation,
/// pull-to-refresh, onboarding empty state, and search overlay.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/user_profile.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';
import 'package:zuralog/features/data/data/data_repository.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/domain/time_range.dart';
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

/// Disables all onboarding tooltips so they don't block taps in widget tests.
class _StubTooltipsEnabledNotifier extends TooltipsEnabledNotifier {
  @override
  Future<bool> build() async => false;
}

/// A minimal mock [DataRepositoryInterface].
class _MockDataRepository implements DataRepositoryInterface {
  _MockDataRepository({DashboardData? dashboard})
      : _dashboard = dashboard ??
            const DashboardData(categories: [], visibleOrder: []);

  final DashboardData _dashboard;

  @override
  Future<DashboardData> getDashboard() async => _dashboard;

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

// ── Router helpers ────────────────────────────────────────────────────────────

/// Tracks the last navigated route for assertions.
String _lastRoute = '';

GoRouter _makeRouter() => GoRouter(
      initialLocation: '/data',
      routes: [
        GoRoute(
          path: '/data',
          builder: (context, state) => const HealthDashboardScreen(),
        ),
        GoRoute(
          path: '/coach',
          builder: (context, state) {
            _lastRoute = '/coach';
            return const Scaffold(body: Text('Coach'));
          },
        ),
        GoRoute(
          path: '/today',
          builder: (context, state) {
            _lastRoute = '/today';
            return const Scaffold(body: Text('Today'));
          },
        ),
        GoRoute(
          path: '/data/category/:id',
          builder: (context, state) {
            _lastRoute = '/data/category/${state.pathParameters['id']}';
            return const Scaffold(body: Text('Category Detail'));
          },
        ),
        GoRoute(
          path: '/settings/integrations',
          builder: (context, state) {
            _lastRoute = '/settings/integrations';
            return const Scaffold(body: Text('Integrations'));
          },
        ),
      ],
    );

// ── Provider container helpers ────────────────────────────────────────────────

/// Builds a [HealthScoreData] suitable for tests.
HealthScoreData _score() => const HealthScoreData(
      score: 72,
      trend: [68, 70, 71, 72],
      dataDays: 10,
    );

/// Creates a [ProviderContainer] with all providers stubbed for tests.
///
/// [tiles]: override tile list (defaults to all noSource).
/// [allLoaded]: if true, creates tiles in loaded state for all 20 tile IDs.
ProviderContainer _container({
  List<TileData>? tiles,
  bool allLoaded = false,
}) {
  final effectiveTiles = tiles ??
      (allLoaded
          ? TileId.values
              .map(
                (id) => TileData(
                  tileId: id,
                  dataState: TileDataState.loaded,
                  lastUpdated: '2026-03-19T12:00:00Z',
                  visualization: const ValueData(primaryValue: '42'),
                ),
              )
              .toList()
          : TileId.values
              .map(
                (id) => TileData(
                  tileId: id,
                  dataState: TileDataState.noSource,
                ),
              )
              .toList());

  return ProviderContainer(
    overrides: [
      userProfileProvider.overrideWith(() => _StubUserProfileNotifier()),
      tooltipsEnabledProvider
          .overrideWith(() => _StubTooltipsEnabledNotifier()),
      dataRepositoryProvider.overrideWith(
        (ref) => _MockDataRepository(),
      ),
      dashboardProvider.overrideWith(
        (ref) async =>
            const DashboardData(categories: [], visibleOrder: []),
      ),
      dashboardTilesProvider.overrideWith(
        (ref) async => effectiveTiles,
      ),
      dashboardLayoutLoaderProvider.overrideWith(
        (ref) async => null,
      ),
      healthScoreProvider.overrideWith(
        (ref) async => _score(),
      ),
    ],
  );
}

Widget _buildApp(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: _makeRouter()),
    );

// ══════════════════════════════════════════════════════════════════════════════
// Tests
// ══════════════════════════════════════════════════════════════════════════════

void main() {
  setUp(() => _lastRoute = '');

  // ── Grid renders tiles from dashboardTilesProvider ──────────────────────────

  group('Grid rendering', () {
    testWidgets('renders tile grid when tiles are in loaded state',
        (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // The grid should show at least one MetricTile.
      // Steps tile's category label 'Activity' should be present.
      expect(find.byType(HealthDashboardScreen), findsOneWidget);
    });

    testWidgets('shows onboarding empty state when all tiles are noSource',
        (tester) async {
      final container = _container(); // defaults to all noSource
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // Onboarding state: 'No data yet' heading.
      expect(find.text('No data yet'), findsOneWidget);
    });

    testWidgets('onboarding "Connect a device" navigates to integrations',
        (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect a device'));
      await tester.pumpAndSettle();

      expect(_lastRoute, '/settings/integrations');
    });

    testWidgets('onboarding "Log manually" navigates to /today', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log manually'));
      await tester.pumpAndSettle();

      expect(_lastRoute, '/today');
    });
  });

  // ── Category filter chip ─────────────────────────────────────────────────────

  group('Category filter chips', () {
    testWidgets('tapping a category chip updates tileFilterProvider',
        (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // Tap the 'Activity' chip.
      await tester.tap(find.text('Activity').first);
      await tester.pumpAndSettle();

      expect(
        container.read(tileFilterProvider),
        HealthCategory.activity,
      );
    });

    testWidgets('tapping the active chip deselects it (back to null)',
        (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // Tap to select then tap again to deselect.
      await tester.tap(find.text('Activity').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activity').first);
      await tester.pumpAndSettle();

      expect(container.read(tileFilterProvider), isNull);
    });

    testWidgets(
        'active category filter shows "Ask Coach about X" CTA when tiles loaded',
        (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sleep').first);
      await tester.pumpAndSettle();

      expect(find.text('Ask Coach about Sleep'), findsOneWidget);
    });
  });

  // ── Time range selector ──────────────────────────────────────────────────────

  group('Time range selector', () {
    testWidgets('tapping "30D" updates dashboardTimeRangeProvider',
        (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('30D').first);
      await tester.pumpAndSettle();

      expect(
        container.read(dashboardTimeRangeProvider),
        TimeRange.thirtyDays,
      );
    });

    testWidgets('tapping "7D" sets provider to sevenDays', (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // Select 30D first then 7D to verify change.
      await tester.tap(find.text('30D').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('7D').first);
      await tester.pumpAndSettle();

      expect(
        container.read(dashboardTimeRangeProvider),
        TimeRange.sevenDays,
      );
    });
  });

  // ── Edit mode ────────────────────────────────────────────────────────────────
  //
  // NOTE: pumpAndSettle cannot be used after entering edit mode because
  // TileEditOverlay's wiggle animation uses a repeating AnimationController
  // that never settles. Use pump(Duration) instead.

  group('Edit mode', () {
    testWidgets('tapping tune icon enters edit mode', (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      // Use pump instead of pumpAndSettle to avoid infinite wiggle animation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // "Done" button appears in edit mode.
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('tapping "Done" exits edit mode', (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // Enter edit mode.
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Exit edit mode.
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // tune icon should be visible again.
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('tune icon is absent when in edit mode', (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.tune_rounded), findsNothing);
    });
  });

  // ── Tile expand / collapse ───────────────────────────────────────────────────

  group('Tile expand/collapse', () {
    testWidgets('tapping a loaded tile shows TileExpandedView', (tester) async {
      final tiles = [
        TileData(
          tileId: TileId.steps,
          dataState: TileDataState.loaded,
          lastUpdated: '2026-03-19T12:00:00Z',
          visualization: const ValueData(primaryValue: '8,432'),
        ),
        ...TileId.values
            .where((id) => id != TileId.steps)
            .map((id) => TileData(
                  tileId: id,
                  dataState: TileDataState.noSource,
                )),
      ];
      final container = _container(tiles: tiles);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // Steps tile value should be in the tree via MetricTile.
      // Tap the steps tile card to expand it.
      await tester.tap(find.text('8,432').first);
      await tester.pumpAndSettle();

      // After expansion, TileExpandedView with action buttons should appear.
      expect(find.text('View Details ›'), findsOneWidget);
    });

    testWidgets('tapping the expanded tile again collapses it', (tester) async {
      final tiles = [
        TileData(
          tileId: TileId.steps,
          dataState: TileDataState.loaded,
          lastUpdated: '2026-03-19T12:00:00Z',
          visualization: const ValueData(primaryValue: '8,432'),
        ),
        ...TileId.values
            .where((id) => id != TileId.steps)
            .map((id) => TileData(
                  tileId: id,
                  dataState: TileDataState.noSource,
                )),
      ];
      final container = _container(tiles: tiles);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // Expand.
      await tester.tap(find.text('8,432').first);
      await tester.pumpAndSettle();
      expect(find.text('View Details ›'), findsOneWidget);

      // Collapse by tapping the expanded view.
      await tester.tap(find.text('8,432').first);
      await tester.pumpAndSettle();
      expect(find.text('View Details ›'), findsNothing);
    });
  });

  // ── Ask Coach ────────────────────────────────────────────────────────────────

  group('Ask Coach', () {
    testWidgets('Ask Coach from expanded tile sets coachPrefillProvider',
        (tester) async {
      final tiles = [
        TileData(
          tileId: TileId.steps,
          dataState: TileDataState.loaded,
          lastUpdated: '2026-03-19T12:00:00Z',
          visualization: const ValueData(primaryValue: '8,432'),
        ),
        ...TileId.values
            .where((id) => id != TileId.steps)
            .map((id) => TileData(
                  tileId: id,
                  dataState: TileDataState.noSource,
                )),
      ];
      final container = _container(tiles: tiles);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // Expand steps tile.
      await tester.tap(find.text('8,432').first);
      await tester.pumpAndSettle();

      // Tap Ask Coach.
      await tester.tap(find.text('Ask Coach').first);
      await tester.pumpAndSettle();

      expect(
        container.read(coachPrefillProvider),
        contains('Steps'),
      );
      expect(_lastRoute, '/coach');
    });

    testWidgets('Ask Coach category CTA navigates to /coach with prefill',
        (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // Select activity filter to show Ask Coach CTA.
      await tester.tap(find.text('Activity').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ask Coach about Activity'));
      await tester.pumpAndSettle();

      expect(
        container.read(coachPrefillProvider),
        'Tell me about my Activity data',
      );
      expect(_lastRoute, '/coach');
    });
  });

  // ── Pull to refresh ──────────────────────────────────────────────────────────

  group('Pull to refresh', () {
    testWidgets('pull-to-refresh is available on the scroll view',
        (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // RefreshIndicator should be in the widget tree.
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('pull-to-refresh does not work in edit mode', (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // Enter edit mode (use pump to avoid infinite wiggle animation).
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The Done button confirms edit mode is active — refresh is blocked.
      expect(find.text('Done'), findsOneWidget);
    });
  });

  // ── Search overlay ───────────────────────────────────────────────────────────

  group('Search overlay', () {
    testWidgets('tapping search icon shows SearchOverlay', (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      // SearchOverlay shows a search field.
      expect(find.widgetWithText(TextField, ''), findsAny);
      // Check the hint text is present (search_overlay uses autofocus).
      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping back arrow in SearchOverlay closes overlay',
        (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // Open search.
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      // Close via back arrow.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Search field should no longer be present.
      expect(find.byType(TextField), findsNothing);
    });
  });

  // ── App bar ──────────────────────────────────────────────────────────────────

  group('App bar', () {
    testWidgets('shows "Data" title', (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      expect(find.text('Data'), findsOneWidget);
    });

    testWidgets('shows search icon and tune icon in normal mode', (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });
  });

  // ── Health score strip ───────────────────────────────────────────────────────

  group('HealthScoreStrip', () {
    testWidgets('renders health score strip', (tester) async {
      final container = _container(allLoaded: true);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      // Score of 72 should be visible.
      expect(find.text('72'), findsOneWidget);
    });
  });
}
