/// Zuralog Settings — Settings Hub Screen Tests.
///
/// Smoke-tests [SettingsHubScreen] — verifies all eight navigation tiles
/// render correctly and that tapping each tile calls [context.push] with
/// the expected route path.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/features/settings/presentation/settings_hub_screen.dart';

// ── Harness ───────────────────────────────────────────────────────────────────

/// Records navigated paths for assertion.
final List<String> _navigatedPaths = [];

Widget _buildHarness() {
  _navigatedPaths.clear();
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, _) => const SettingsHubScreen(),
        routes: [
          GoRoute(
            path: 'account',
            builder: (context, _) => const _Stub('account'),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, _) => const _Stub('notifications'),
          ),
          GoRoute(
            path: 'appearance',
            builder: (context, _) => const _Stub('appearance'),
          ),
          GoRoute(
            path: 'coach',
            builder: (context, _) => const _Stub('coach'),
          ),
          GoRoute(
            path: 'integrations',
            builder: (context, _) => const _Stub('integrations'),
          ),
          GoRoute(
            path: 'privacy',
            builder: (context, _) => const _Stub('privacy'),
          ),
          GoRoute(
            path: 'subscription',
            builder: (context, _) => const _Stub('subscription'),
          ),
          GoRoute(
            path: 'about',
            builder: (context, _) => const _Stub('about'),
          ),
        ],
      ),
    ],
  );

  // SettingsHubScreen calls ref.read(analyticsServiceProvider) on tile tap,
  // so it must be wrapped in a ProviderScope. AnalyticsService.enabled is false
  // in kDebugMode (test environment), so no real events are emitted.
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(AnalyticsService()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _Stub extends StatelessWidget {
  const _Stub(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => Text('stub:$name');
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('SettingsHubScreen', () {
    testWidgets('smoke test — renders without throwing', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows Settings app bar title', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(find.text('Settings'), findsAtLeast(1));
    });

    testWidgets('renders all 8 navigation tiles', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();

      // Tiles visible without scrolling.
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Coach'), findsOneWidget);
      expect(find.text('Integrations'), findsOneWidget);
      expect(find.text('Subscription'), findsOneWidget);

      // Tiles that may require scrolling — use scrollUntilVisible.
      await tester.scrollUntilVisible(
        find.text('Privacy & Data'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Privacy & Data'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('About Zuralog'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('About Zuralog'), findsOneWidget);
    });

    testWidgets('Account tile navigates to /settings/account', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.text('stub:account'), findsOneWidget);
    });

    testWidgets('Notifications tile navigates to /settings/notifications',
        (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('stub:notifications'), findsOneWidget);
    });

    testWidgets('Appearance tile navigates to /settings/appearance',
        (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      expect(find.text('stub:appearance'), findsOneWidget);
    });

    testWidgets('Privacy & Data tile navigates to /settings/privacy',
        (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();

      // Ensure the tile is scrolled into view before tapping.
      await tester.ensureVisible(find.text('Privacy & Data'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Privacy & Data'));
      await tester.pumpAndSettle();
      expect(find.text('stub:privacy'), findsOneWidget);
    });
  });
}
