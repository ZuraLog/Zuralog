/// Zuralog Edge Agent — Auth Selection Screen Tests.
///
/// Verifies that [AuthSelectionScreen]:
/// - renders all expected UI elements,
/// - shows a "coming soon" [SnackBar] when Apple Sign In is tapped,
/// - shows a "coming soon" [SnackBar] when Google Sign In is tapped,
/// - navigates to [RegisterScreen] when "Sign up with Email" is tapped.
///
/// No Riverpod overrides are required — [AuthSelectionScreen] is a pure
/// [StatelessWidget] that has no provider dependencies.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/features/auth/presentation/auth/auth_selection_screen.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

/// A minimal destination widget that records its [name] to [routes] when built.
class _DestinationStub extends StatefulWidget {
  /// Creates a [_DestinationStub].
  const _DestinationStub({required this.name, required this.routes});

  /// Short identifier for this destination.
  final String name;

  /// Mutable list appended to in [initState] to signal navigation.
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

/// Builds a minimal test harness for [AuthSelectionScreen].
///
/// Mounts the screen at `/auth/select` so that `context.push('/auth/register')`
/// can navigate forward. [navigatedRoutes] is a mutable list appended to
/// whenever a destination stub is rendered, enabling post-tap assertions.
Widget _buildHarnessForEmailPath({required List<String> navigatedRoutes}) {
  final router = GoRouter(
    initialLocation: '/auth/select',
    routes: [
      GoRoute(
        path: '/auth/select',
        builder: (context, _) => const AuthSelectionScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, _) =>
            _DestinationStub(name: 'register', routes: navigatedRoutes),
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

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('AuthSelectionScreen rendering', () {
    testWidgets('renders "Create your account" heading', (tester) async {
      await tester.pumpWidget(
          _buildHarnessForEmailPath(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(find.text('Create your account'), findsOneWidget);
    });

    testWidgets('renders "Continue with Apple" button', (tester) async {
      await tester.pumpWidget(
          _buildHarnessForEmailPath(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ElevatedButton, 'Continue with Apple'),
        findsOneWidget,
      );
    });

    testWidgets('renders "Continue with Google" button', (tester) async {
      await tester.pumpWidget(
          _buildHarnessForEmailPath(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'Continue with Google'),
        findsOneWidget,
      );
    });

    testWidgets('renders "Sign up with Email" button', (tester) async {
      await tester.pumpWidget(
          _buildHarnessForEmailPath(navigatedRoutes: []));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ElevatedButton, 'Sign up with Email'),
        findsOneWidget,
      );
    });
  });

  group('AuthSelectionScreen social auth stubs', () {
    testWidgets('tapping "Continue with Apple" shows SnackBar',
        (tester) async {
      await tester.pumpWidget(
          _buildHarnessForEmailPath(navigatedRoutes: []));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue with Apple'));
      await tester.pumpAndSettle();

      expect(find.text('Apple Sign In coming soon'), findsOneWidget);
    });

    testWidgets('tapping "Continue with Google" shows SnackBar',
        (tester) async {
      await tester.pumpWidget(
          _buildHarnessForEmailPath(navigatedRoutes: []));
      await tester.pumpAndSettle();

      await tester.tap(
          find.widgetWithText(OutlinedButton, 'Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Google Sign In coming soon'), findsOneWidget);
    });
  });

  group('AuthSelectionScreen email path', () {
    testWidgets('tapping "Sign up with Email" navigates to /auth/register',
        (tester) async {
      final navigatedRoutes = <String>[];
      await tester.pumpWidget(
          _buildHarnessForEmailPath(navigatedRoutes: navigatedRoutes));
      await tester.pumpAndSettle();

      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Sign up with Email'));
      await tester.pumpAndSettle();

      expect(navigatedRoutes, contains('register'));
    });

    testWidgets('tapping "Log in" link navigates to /auth/login',
        (tester) async {
      final navigatedRoutes = <String>[];
      await tester.pumpWidget(
          _buildHarnessForEmailPath(navigatedRoutes: navigatedRoutes));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(navigatedRoutes, contains('login'));
    });
  });
}
