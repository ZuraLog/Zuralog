/// Zuralog Edge Agent — Welcome Screen Tests.
///
/// Verifies that [WelcomeScreen] renders all required UI elements and that
/// the navigation callbacks are wired correctly using a lightweight
/// [GoRouter] test configuration.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/features/auth/presentation/onboarding/welcome_screen.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

/// Builds a minimal test harness wrapping [WelcomeScreen] inside a [GoRouter]
/// and a [ProviderScope] so the widget can be pumped in isolation.
///
/// [navigatedRoutes] is a mutable list that will be appended to whenever
/// [GoRouter] completes a navigation — enabling post-tap assertions.
Widget _buildHarness({required List<String> navigatedRoutes}) {
  final router = GoRouter(
    initialLocation: '/welcome',
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, _) => const WelcomeScreen(),
      ),
      // Stub destination routes so GoRouter does not throw.
      GoRoute(
        path: '/onboarding',
        builder: (context, _) =>
            _DestinationStub(name: 'onboarding', routes: navigatedRoutes),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, _) =>
            _DestinationStub(name: 'login', routes: navigatedRoutes),
      ),
    ],
  );

  return ProviderScope(
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
    testWidgets('renders Zuralog logo asset image', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      // The _LogoArea now uses Image.asset with the Zuralog brand PNG.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/zuralog_logo.png',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders "Zuralog" app name', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(find.text('Zuralog'), findsOneWidget);
    });

    testWidgets('renders tagline text', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(find.text('Your AI Health Coach'), findsOneWidget);
    });

    testWidgets('renders "Get Started" button', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('renders "I already have an account" link', (tester) async {
      await tester.pumpWidget(_buildHarness(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(find.text('I already have an account'), findsOneWidget);
    });

    testWidgets('tapping "Get Started" navigates to /onboarding', (tester) async {
      final navigatedRoutes = <String>[];
      await tester.pumpWidget(_buildHarness(navigatedRoutes: navigatedRoutes));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(navigatedRoutes, contains('onboarding'));
    });

    testWidgets('tapping "I already have an account" navigates to /auth/login',
        (tester) async {
      final navigatedRoutes = <String>[];
      await tester.pumpWidget(_buildHarness(navigatedRoutes: navigatedRoutes));
      await tester.pumpAndSettle();

      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();

      expect(navigatedRoutes, contains('login'));
    });
  });
}
