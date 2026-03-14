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
  // OnboardingPageView is a full-bleed layout that requires a realistic phone
  // viewport. The headless test surface defaults to 800×600 which is too small
  // and causes a RenderFlex overflow that breaks every test in this file.
  // setSurfaceSize is async and must be awaited. The tearDown resets the size
  // after each test so other test files are unaffected.
  Future<void> setPhoneViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('OnboardingPageView rendering', () {
    testWidgets('renders first page headline "Your health, complete."',
        (tester) async {
      await setPhoneViewport(tester);
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      // The headline is a multi-line string rendered as-is.
      expect(find.text('Your health,\ncomplete.'), findsOneWidget);
    });

    testWidgets('renders "Skip" link', (tester) async {
      await setPhoneViewport(tester);
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('renders "Next" button on first page', (tester) async {
      await setPhoneViewport(tester);
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      // The CTA uses FilledButton (not ElevatedButton) per the design system.
      expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
    });

    testWidgets('renders three page-dot indicators', (tester) async {
      await setPhoneViewport(tester);
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      // Three AnimatedContainers are used as dot indicators — one per slide.
      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });
  });

  group('OnboardingPageView navigation', () {
    testWidgets('tapping "Skip" navigates to /welcome', (tester) async {
      await setPhoneViewport(tester);
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
      await setPhoneViewport(tester);
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      expect(find.text('AI that\ngets you.'), findsOneWidget);
    });

    testWidgets(
        '"Next" button label changes to "Get Started" on last page',
        (tester) async {
      await setPhoneViewport(tester);
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      // Advance through the first two pages to reach the last page.
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(FilledButton, 'Get Started'),
        findsOneWidget,
      );
    });

    testWidgets(
        'tapping "Get Started" on last page navigates to /welcome',
        (tester) async {
      await setPhoneViewport(tester);
      final navigatedRoutes = <String>[];
      await tester.pumpWidget(_buildHarness(navigatedRoutes: navigatedRoutes));
      await tester.pumpAndSettle();

      // Advance through slides to the last page.
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      // Tap the final CTA.
      await tester.tap(find.widgetWithText(FilledButton, 'Get Started'));
      await tester.pumpAndSettle();

      expect(navigatedRoutes, contains('welcome'));
    });
  });
}
