/// Zuralog Edge Agent — Welcome Screen Tests.
///
/// Verifies that [WelcomeScreen] (the auth home) renders all required UI
/// elements matching the "Clean Gate" reference design:
///   - Zuralog app name
///   - Tagline
///   - "Continue with Apple" button
///   - "Continue with Google" button
///   - "Log in with Email" link
///   - Legal footer
///
/// Also verifies that the email CTA navigates to [/auth/login].
///
/// [SvgPicture] from the logo card is not asserted directly because SVG
/// rendering requires the real file system in widget tests; the logo card
/// container is asserted by its background color instead.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/presentation/onboarding/welcome_screen.dart';
import 'package:zuralog/core/theme/app_colors.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

/// Builds a minimal test harness wrapping [WelcomeScreen] inside a [GoRouter]
/// and a [ProviderScope] so the widget can be pumped in isolation.
///
/// [navigatedRoutes] is a mutable list that will be appended to whenever
/// GoRouter navigates to a stub destination screen.
Widget _buildHarness({required List<String> navigatedRoutes}) {
  // Mark onboarding as seen so the router does not redirect to /onboarding.
  SharedPreferences.setMockInitialValues({
    'has_seen_onboarding': true,
  });

  final router = GoRouter(
    initialLocation: '/welcome',
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, _) => const WelcomeScreen(),
      ),
      // Stub destination routes so GoRouter does not throw on navigation.
      GoRoute(
        path: '/auth/login',
        builder: (context, _) =>
            _DestinationStub(name: 'login', routes: navigatedRoutes),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      // Override hasSeenOnboardingProvider to avoid async SharedPreferences
      // in the router redirect during tests.
      hasSeenOnboardingProvider.overrideWith((ref) async => true),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// A minimal destination widget that records its name to [routes] when built.
class _DestinationStub extends StatefulWidget {
  const _DestinationStub({required this.name, required this.routes});
  final String name;
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

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('WelcomeScreen', () {
    testWidgets('renders the Zuralog SVG logo card', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      // The _LogoCard contains an SvgPicture.
      expect(find.byType(SvgPicture), findsWidgets);
    });

    testWidgets('renders "Zuralog" app name', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(find.text('Zuralog'), findsOneWidget);
    });

    testWidgets('renders tagline text', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(
        find.text('Your journey to better health starts here.'),
        findsOneWidget,
      );
    });

    testWidgets('renders "Continue with Apple" button', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Apple'), findsOneWidget);
    });

    testWidgets('renders "Continue with Google" button', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('renders "Log in with Email" link', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(find.text('Log in with Email'), findsOneWidget);
    });

    testWidgets('renders legal footer text', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      // The legal footer is a RichText — check for its presence by substring.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('By continuing'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders the sage green logo card container', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      // The _LogoCard is a Container with AppColors.primary background.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == AppColors.primary,
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping "Log in with Email" navigates to /auth/login',
        (tester) async {
      final navigatedRoutes = <String>[];
      await tester.pumpWidget(_buildHarness(navigatedRoutes: navigatedRoutes));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log in with Email'));
      await tester.pumpAndSettle();

      expect(navigatedRoutes, contains('login'));
    });

    testWidgets(
        'tapping "Continue with Apple" shows coming-soon AlertDialog',
        (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Apple'));
      await tester.pumpAndSettle();

      // Apple Sign In is stubbed — an AlertDialog is shown explaining that
      // an Apple Developer Program membership is required.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Apple Sign In'), findsOneWidget);
    });

    testWidgets(
        '"Continue with Google" button is present and enabled',
        (tester) async {
      // Google Sign In triggers native OAuth — we cannot assert UI side-effects
      // without mocking SocialAuthService. This test verifies the button is
      // rendered and enabled so it can be tapped (functional smoke test).
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      final googleButton = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Continue with Google'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(googleButton.onPressed, isNotNull);
    });
  });
}
