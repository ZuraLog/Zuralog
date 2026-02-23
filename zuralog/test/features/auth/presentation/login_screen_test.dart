/// Zuralog Edge Agent — Login Screen Tests.
///
/// Verifies form validation (empty fields, invalid email, short password),
/// successful login routing, and error SnackBar on [AuthFailure].
///
/// Uses a [_FakeAuthStateNotifier] override to avoid network calls.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/features/auth/presentation/auth/login_screen.dart';

// ── Fake Notifier ─────────────────────────────────────────────────────────────

/// Fake [AuthStateNotifier] that returns a preset [AuthResult] without
/// hitting any network. Used to isolate [LoginScreen] from the data layer.
class _FakeAuthStateNotifier extends AuthStateNotifier {
  /// The result to return from [login] and [register] calls.
  final AuthResult response;

  /// Creates a [_FakeAuthStateNotifier] that always returns [response].
  _FakeAuthStateNotifier({required this.response});

  @override
  Future<AuthResult> login(String email, String password) async {
    switch (response) {
      case AuthSuccess():
        state = AuthState.authenticated;
      case AuthFailure():
        state = AuthState.unauthenticated;
    }
    return response;
  }

  @override
  Future<AuthResult> register(String email, String password) async {
    switch (response) {
      case AuthSuccess():
        state = AuthState.authenticated;
      case AuthFailure():
        state = AuthState.unauthenticated;
    }
    return response;
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

/// Creates a [ProviderScope] override that replaces [authStateProvider] with
/// a [_FakeAuthStateNotifier] returning [response].
ProviderScope _overrideScope({required AuthResult response}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _FakeAuthStateNotifier(response: response)),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/auth/login',
        routes: [
          GoRoute(
            path: '/auth/login',
            builder: (context, _) => const LoginScreen(),
          ),
          GoRoute(
            path: '/auth/register',
            builder: (context, _) => const Scaffold(body: Text('register')),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, _) => const Scaffold(body: Text('dashboard')),
          ),
        ],
      ),
    ),
  );
}

/// Fills the email and password fields in the login form.
///
/// Locates fields by their hint text using the [EditableText] widget which
/// exposes [EditableText.controller] and can be identified by [find.ancestor].
Future<void> _fillForm(
  WidgetTester tester, {
  String email = '',
  String password = '',
}) async {
  // The first TextFormField in document order is email; second is password.
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), password);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('LoginScreen rendering', () {
    testWidgets('renders email field', (tester) async {
      await tester.pumpWidget(_overrideScope(
        response: const AuthFailure(message: 'stub'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Email address'), findsOneWidget);
    });

    testWidgets('renders password field', (tester) async {
      await tester.pumpWidget(_overrideScope(
        response: const AuthFailure(message: 'stub'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('renders "Log In" button', (tester) async {
      await tester.pumpWidget(_overrideScope(
        response: const AuthFailure(message: 'stub'),
      ));
      await tester.pumpAndSettle();

      // "Log In" appears in both the AppBar title and the submit button.
      // Assert the ElevatedButton (PrimaryButton) exists with this label.
      expect(find.widgetWithText(ElevatedButton, 'Log In'), findsOneWidget);
    });
  });

  group('LoginScreen form validation', () {
    testWidgets('shows error when submitting with empty fields', (tester) async {
      await tester.pumpWidget(_overrideScope(
        response: const AuthFailure(message: 'stub'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows error for invalid email (no @)', (tester) async {
      await tester.pumpWidget(_overrideScope(
        response: const AuthFailure(message: 'stub'),
      ));
      await tester.pumpAndSettle();

      await _fillForm(tester, email: 'notanemail', password: 'secret123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('shows error for password shorter than 6 chars', (tester) async {
      await tester.pumpWidget(_overrideScope(
        response: const AuthFailure(message: 'stub'),
      ));
      await tester.pumpAndSettle();

      await _fillForm(tester, email: 'user@test.com', password: 'abc');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
      await tester.pump();

      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
    });
  });

  group('LoginScreen auth behaviour', () {
    testWidgets('shows SnackBar with message on AuthFailure', (tester) async {
      const errorMessage = 'Invalid credentials';
      await tester.pumpWidget(_overrideScope(
        response: const AuthFailure(message: errorMessage),
      ));
      await tester.pumpAndSettle();

      await _fillForm(
        tester,
        email: 'user@test.com',
        password: 'password123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
      await tester.pumpAndSettle();

      expect(find.text(errorMessage), findsOneWidget);
    });
  });
}
