/// Zuralog Edge Agent — Register Screen Tests.
///
/// Verifies form validation (empty fields, invalid email, short password),
/// error SnackBar on [AuthFailure], and that the form calls [register] (not
/// [login]).
///
/// Mirrors [login_screen_test.dart] coverage for the registration flow.
/// Uses a [_FakeAuthStateNotifier] override to avoid network calls.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/features/auth/presentation/auth/register_screen.dart';

// ── Fake Notifier ─────────────────────────────────────────────────────────────

/// Fake [AuthStateNotifier] that returns a preset [AuthResult] without
/// hitting any network. Used to isolate [RegisterScreen] from the data layer.
///
/// Tracks which auth method was last called via [lastCalledMethod] so tests
/// can verify the correct code path (register, not login) is exercised.
class _FakeAuthStateNotifier extends AuthStateNotifier {
  /// The result to return from [register] calls.
  final AuthResult response;

  /// The name of the last method called: `'login'` or `'register'`.
  ///
  /// Starts as `null` before any call is made.
  String? lastCalledMethod;

  /// Creates a [_FakeAuthStateNotifier] that always returns [response].
  _FakeAuthStateNotifier({required this.response});

  @override
  Future<AuthResult> login(String email, String password) async {
    lastCalledMethod = 'login';
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
    lastCalledMethod = 'register';
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
///
/// The [notifier] out-parameter is set to the fake notifier instance so
/// callers can inspect [_FakeAuthStateNotifier.lastCalledMethod] after a tap.
ProviderScope _overrideScope({
  required AuthResult response,
  _FakeAuthStateNotifier? notifier,
}) {
  final fake = notifier ?? _FakeAuthStateNotifier(response: response);
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => fake),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/auth/register',
        routes: [
          GoRoute(
            path: '/auth/register',
            builder: (context, _) => const RegisterScreen(),
          ),
          GoRoute(
            path: '/auth/login',
            builder: (context, _) => const Scaffold(body: Text('login')),
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

/// Fills the email and password fields in the register form.
///
/// Locates the first two [TextFormField] widgets in document order
/// (email field first, password field second).
Future<void> _fillForm(
  WidgetTester tester, {
  String email = '',
  String password = '',
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), password);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('RegisterScreen rendering', () {
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

    testWidgets('renders "Create Account" button', (tester) async {
      await tester.pumpWidget(_overrideScope(
        response: const AuthFailure(message: 'stub'),
      ));
      await tester.pumpAndSettle();

      // "Create Account" appears in both the AppBar title and the submit button.
      // Assert the ElevatedButton (PrimaryButton) exists with this label.
      expect(
        find.widgetWithText(ElevatedButton, 'Create Account'),
        findsOneWidget,
      );
    });
  });

  group('RegisterScreen form validation', () {
    testWidgets('shows error when submitting with empty fields', (tester) async {
      await tester.pumpWidget(_overrideScope(
        response: const AuthFailure(message: 'stub'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
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
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('shows error for password shorter than 6 chars', (tester) async {
      await tester.pumpWidget(_overrideScope(
        response: const AuthFailure(message: 'stub'),
      ));
      await tester.pumpAndSettle();

      await _fillForm(tester, email: 'user@test.com', password: 'abc');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
    });
  });

  group('RegisterScreen auth behaviour', () {
    testWidgets('shows SnackBar with message on AuthFailure', (tester) async {
      const errorMessage = 'Email already in use';
      await tester.pumpWidget(_overrideScope(
        response: const AuthFailure(message: errorMessage),
      ));
      await tester.pumpAndSettle();

      await _fillForm(
        tester,
        email: 'user@test.com',
        password: 'password123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets('calls register() — not login() — on form submission',
        (tester) async {
      final fake = _FakeAuthStateNotifier(
        response: const AuthFailure(message: 'stub'),
      );
      await tester.pumpWidget(_overrideScope(
        response: const AuthFailure(message: 'stub'),
        notifier: fake,
      ));
      await tester.pumpAndSettle();

      await _fillForm(
        tester,
        email: 'user@test.com',
        password: 'password123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      expect(fake.lastCalledMethod, equals('register'),
          reason: 'RegisterScreen must call register(), not login()');
    });
  });
}
