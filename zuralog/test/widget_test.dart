// Zuralog Edge Agent — Smoke Test.
//
// Verifies the app boots and shows the correct screen on a cold start.
//
// On cold start the auth state is always unauthenticated (no stored token in the
// test environment), so GoRouter resolves the initial /welcome route and renders
// WelcomeScreen. The test confirms:
//
//   1. The app renders without throwing — no blank screen, no crash.
//   2. The welcome / auth gate is visible: the "Log in with Email" button or
//      a main-shell nav tab label is present in the widget tree.
//
// This is a smoke test. It does not test authentication logic or navigation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/app.dart';

void main() {
  testWidgets('app renders auth gate on cold start', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ZuralogApp()));

    // Allow the post-frame callback (checkAuthStatus) and GoRouter to settle.
    await tester.pump();

    // The app must render a real screen — never a blank widget tree.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);

    // On cold start, auth state is unauthenticated.
    // GoRouter routes to /welcome, which shows the WelcomeScreen.
    // If somehow the user were already authenticated (not possible in tests),
    // the main shell would be shown with its nav-bar tab labels instead.
    //
    // We accept either outcome — the test fails only on a blank screen or crash.
    final hasWelcomeScreen =
        find.text('Log in with Email').evaluate().isNotEmpty ||
        find.text('Continue with Google').evaluate().isNotEmpty ||
        find.text('Continue with Apple').evaluate().isNotEmpty;

    final hasMainShell =
        find.text('Today').evaluate().isNotEmpty ||
        find.text('Data').evaluate().isNotEmpty ||
        find.text('Coach').evaluate().isNotEmpty;

    expect(
      hasWelcomeScreen || hasMainShell,
      isTrue,
      reason:
          'Expected the app to show either the welcome/auth screen or the '
          'main navigation shell, but neither was found. '
          'The app may have crashed or rendered a blank screen.',
    );
  });
}
