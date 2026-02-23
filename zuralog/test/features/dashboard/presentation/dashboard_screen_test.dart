/// Zuralog Dashboard — Dashboard Screen Tests.
///
/// Smoke-tests [DashboardScreen] with mocked Riverpod providers so that
/// no real network requests are made. Verifies the greeting header, the
/// profile avatar, and that the screen renders without throwing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/state/side_panel_provider.dart';
import 'package:zuralog/features/analytics/domain/analytics_providers.dart';
import 'package:zuralog/features/analytics/domain/daily_summary.dart';
import 'package:zuralog/features/analytics/domain/dashboard_insight.dart';
import 'package:zuralog/features/analytics/domain/weekly_trends.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/user_profile.dart';
import 'package:zuralog/features/dashboard/presentation/dashboard_screen.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';

// ── Stub notifiers ────────────────────────────────────────────────────────────

/// Stub [UserProfileNotifier] that immediately exposes [_kProfile].
///
/// Overrides [userProfileProvider] in the test harness so that the
/// dashboard greeting header renders the expected name without making
/// any real network calls.
class _StubProfileNotifier extends UserProfileNotifier {
  @override
  UserProfile? build() => _kProfile;
}

/// Minimal stub [IntegrationsNotifier] that returns an empty integrations list
/// with no loading state, so [IntegrationsRail] renders the "Connected Apps"
/// section header immediately without depending on real repositories.
class _StubIntegrationsNotifier extends StateNotifier<IntegrationsState>
    implements IntegrationsNotifier {
  _StubIntegrationsNotifier() : super(const IntegrationsState());

  @override
  void loadIntegrations() {}

  @override
  Future<void> connect(String integrationId, BuildContext context) async {}

  @override
  void disconnect(String integrationId) {}

  @override
  Future<bool> requestHealthPermissions() async => false;
}

// ── Fixture data ───────────────────────────────────────────────────────────────

/// A stub [UserProfile] with the name "Alex" used by [userProfileProvider].
const _kProfile = UserProfile(
  id: 'test-user-id',
  email: 'alex@example.com',
  displayName: 'Alex',
  onboardingComplete: true,
);

/// A fully-populated [DailySummary] used by provider overrides.
const _kSummary = DailySummary(
  date: '2026-02-23',
  steps: 8432,
  caloriesConsumed: 2100,
  caloriesBurned: 480,
  workoutsCount: 1,
  sleepHours: 7.5,
);

/// A minimal [WeeklyTrends] with 7 data points per list.
final _kTrends = WeeklyTrends(
  dates: List.generate(7, (i) => '2026-02-${17 + i}'),
  steps: const [7200, 7800, 8100, 7500, 8200, 8000, 8432],
  caloriesIn: const [2000, 2100, 1950, 2200, 2050, 2100, 2100],
  caloriesOut: const [400, 430, 460, 420, 500, 480, 480],
  sleepHours: const [6.5, 7.0, 8.0, 7.5, 6.8, 7.2, 7.5],
);

/// An AI insight fixture.
const _kInsight = DashboardInsight(
  insight: 'Great work this week! You hit your step goal 5 days in a row.',
);

// ── Test harness ───────────────────────────────────────────────────────────────

/// Builds a [ProviderScope] with all three analytics providers overridden to
/// return fixture data synchronously, and a [GoRouter] stub for navigation.
///
/// [navigatedPaths] is populated when GoRouter completes a navigation.
Widget _buildHarness({List<String>? navigatedPaths}) {
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (context, _) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, _) => _Stub(name: 'chat', paths: navigatedPaths),
      ),
      GoRoute(
        path: '/integrations',
        builder: (context, _) =>
            _Stub(name: 'integrations', paths: navigatedPaths),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, _) =>
            _Stub(name: 'settings', paths: navigatedPaths),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      // Provide a stub user profile so the greeting header shows "Alex".
      userProfileProvider.overrideWith(() => _StubProfileNotifier()),
      // Override async providers with immediate synchronous data.
      dailySummaryProvider.overrideWith((_) async => _kSummary),
      weeklyTrendsProvider.overrideWith((_) async => _kTrends),
      dashboardInsightProvider.overrideWith((_) async => _kInsight),
      // Stub integrations so the rail renders immediately without real
      // repositories or platform channels.
      integrationsProvider.overrideWith((_) => _StubIntegrationsNotifier()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// A minimal stub screen that records its name in [paths].
class _Stub extends StatelessWidget {
  const _Stub({required this.name, this.paths});
  final String name;
  final List<String>? paths;

  @override
  Widget build(BuildContext context) {
    paths?.add(name);
    return Text('stub:$name');
  }
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('DashboardScreen', () {
    testWidgets('smoke test — renders without throwing', (tester) async {
      await tester.pumpWidget(_buildHarness());
      // Initial frame may show loading indicators; pump again for data.
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows greeting header (Good Morning / Afternoon / Evening)',
        (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();

      // One of the three greetings must be present.
      final greetingFinder = find.byWidgetPredicate((widget) {
        if (widget is! Text) return false;
        final text = widget.data ?? '';
        return text == 'Good Morning' ||
            text == 'Good Afternoon' ||
            text == 'Good Evening';
      });
      expect(greetingFinder, findsOneWidget);
    });

    testWidgets('shows user name "Alex"', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(find.text('Alex'), findsOneWidget);
    });

    testWidgets('renders profile avatar (CircleAvatar)', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets(
        'tapping profile avatar sets sidePanelOpenProvider to true',
        (tester) async {
      // Capture the ProviderContainer so we can inspect provider state after
      // the tap.  The panel itself lives in AppShell (not in this isolated
      // harness) so we verify the *intent* — that the provider was set.
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(() => _StubProfileNotifier()),
            dailySummaryProvider.overrideWith((_) async => _kSummary),
            weeklyTrendsProvider.overrideWith((_) async => _kTrends),
            dashboardInsightProvider.overrideWith((_) async => _kInsight),
            integrationsProvider
                .overrideWith((_) => _StubIntegrationsNotifier()),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              // Capture the container so the test can read providers directly.
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: AppTheme.light,
                home: const DashboardScreen(),
              );
            },
          ),
        ),
      );

      await tester.pump();

      // Panel is initially closed.
      expect(container.read(sidePanelOpenProvider), isFalse);

      await tester.tap(find.byType(CircleAvatar));
      await tester.pump();

      // Tapping the avatar should have set the provider to true.
      expect(container.read(sidePanelOpenProvider), isTrue);
    });

    testWidgets('shows insight text once providers resolve', (tester) async {
      await tester.pumpWidget(_buildHarness());
      // Pump until all async futures complete.
      await tester.pumpAndSettle();

      expect(find.textContaining('step goal'), findsOneWidget);
    });

    testWidgets('shows activity rings section once summary resolves',
        (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pumpAndSettle();

      // ActivityRings renders a CustomPaint with the ring diameter.
      // Multiple CustomPaints may exist (fl_chart, nav bar etc.), so we
      // look for the one with the ring-specific size.
      final ringsPaints = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where(
            (cp) =>
                cp.size ==
                const Size(AppDimens.ringDiameter, AppDimens.ringDiameter),
          )
          .toList();
      expect(ringsPaints, isNotEmpty);
    });

    testWidgets('renders "Connected Apps" section header', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pumpAndSettle();

      // The IntegrationsRail is at the bottom of the SliverList; it may be
      // beyond the initial viewport and not yet built (lazy rendering).
      // Scroll down repeatedly until the text appears or we exhaust retries.
      const maxAttempts = 10;
      var found = false;
      for (var i = 0; i < maxAttempts && !found; i++) {
        if (find.text('Connected Apps').evaluate().isNotEmpty) {
          found = true;
          break;
        }
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
      }

      expect(find.text('Connected Apps'), findsOneWidget);
    });
  });
}
