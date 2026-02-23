/// Zuralog Edge Agent — Onboarding Page View Tests.
///
/// Verifies rendering, Skip navigation, page-dot indicator changes, Next
/// button label transitions, and last-page → Get Started → /welcome
/// navigation for [OnboardingPageView].
///
/// Uses a lightweight [GoRouter] test harness. Riverpod providers are
/// required because [OnboardingPageView] calls [markOnboardingComplete]
/// and [ref.invalidate] on finish/skip.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/presentation/onboarding/onboarding_page_view.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

/// A minimal destination widget that records its [name] to [routes] when built.
///
/// Used to verify that a GoRouter navigation actually occurred.
class _DestinationStub extends StatefulWidget {
  /// Creates a [_DestinationStub].
  const _DestinationStub({required this.name, required this.routes});

  /// Short identifier for this destination (e.g., `'register'`).
  final String name;

  /// Mutable list appended to in [initState] to signal navigation completion.
  final List<String> routes;

  @override
  State<_DestinationStub> createState() => _DestinationStubState();
}

class _DestinationStubState extends State<_DestinationStub> {
  @override
  void initState() {
    super.initState();
    widget.routes.add(widget.name);
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(widget.name));
}

/// Builds a minimal test harness wrapping [OnboardingPageView] inside a
/// [GoRouter] and [ProviderScope] so the widget can be pumped in isolation.
///
/// [navigatedRoutes] is a mutable list appended to whenever GoRouter renders
/// a destination stub — enabling post-tap navigation assertions.
///
/// The harness registers `/welcome` as a stub destination because both
/// Skip and the "Get Started" CTA navigate to [RouteNames.welcomePath].
///
/// SharedPreferences is seeded with `has_seen_onboarding = false` so
/// [markOnboardingComplete] can write without hitting a missing platform
/// channel. [hasSeenOnboardingProvider] is overridden to always return
/// `true` after the write so the router does not redirect back to
/// `/onboarding` in an infinite loop during `pumpAndSettle`.
Widget _buildHarness({required List<String> navigatedRoutes}) {
  // Seed SharedPreferences so markOnboardingComplete() can write the flag.
  SharedPreferences.setMockInitialValues({'has_seen_onboarding': false});

  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, _) => const OnboardingPageView(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, _) =>
            _DestinationStub(name: 'welcome', routes: navigatedRoutes),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      // Override so that after invalidation the router sees onboarding as
      // complete and does not redirect back to /onboarding.
      hasSeenOnboardingProvider.overrideWith((ref) async => true),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('OnboardingPageView rendering', () {
    testWidgets('renders first page headline "Connect Everything"',
        (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(find.text('Connect Everything'), findsOneWidget);
    });

    testWidgets('renders "Skip" link', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('renders "Next" button on first page', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Next'), findsOneWidget);
    });

    testWidgets('renders two page-dot indicators', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      // Two AnimatedContainers are used as dot indicators — one per page.
      expect(find.byType(AnimatedContainer), findsNWidgets(2));
    });
  });

  group('OnboardingPageView navigation', () {
    testWidgets('tapping "Skip" navigates to /welcome', (tester) async {
      final navigatedRoutes = <String>[];
      await tester.pumpWidget(_buildHarness(navigatedRoutes: navigatedRoutes));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(navigatedRoutes, contains('welcome'));
    });

    testWidgets(
        'tapping "Next" on first page advances to second page headline',
        (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('Intelligence, Not Data'), findsOneWidget);
    });

    testWidgets(
        '"Next" button label changes to "Get Started" on last page',
        (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      // Advance to last page.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ElevatedButton, 'Get Started'),
        findsOneWidget,
      );
    });

    testWidgets(
        'tapping "Get Started" on last page navigates to /welcome',
        (tester) async {
      final navigatedRoutes = <String>[];
      await tester.pumpWidget(_buildHarness(navigatedRoutes: navigatedRoutes));
      await tester.pumpAndSettle();

      // Advance to last page.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pumpAndSettle();

      // Tap the final CTA.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Get Started'));
      await tester.pumpAndSettle();

      expect(navigatedRoutes, contains('welcome'));
    });
  });
}
