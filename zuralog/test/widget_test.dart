// Zuralog Edge Agent — Smoke Test.
//
// Basic test to verify the app boots without errors.
// Phase 2.2: The app now uses GoRouter with MaterialApp.router.
// The initial route is /welcome (or /dashboard if auth token is present).
// We verify the app renders without throwing, and that the router
// initialises by finding a Scaffold (rendered by the placeholder screens).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/app.dart';

void main() {
  testWidgets('App should build without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ZuralogApp()));

    // Allow the post-frame callback (checkAuthStatus) and GoRouter to settle.
    await tester.pump();

    // The app renders a Scaffold (from GoRouter's initial /welcome placeholder
    // or whichever route the auth guard resolves to).
    expect(find.byType(Scaffold), findsWidgets);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
