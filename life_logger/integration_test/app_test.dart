/// Life Logger Edge Agent — End-to-End Integration Test.
///
/// Validates that the application launches without crashing,
/// renders the developer test harness (HarnessScreen), and
/// displays interactive controls. Firebase initialization may
/// fail in the test environment; the app's try-catch in main.dart
/// ensures this is non-fatal.
///
/// Run with:
/// ```bash
/// flutter test integration_test/app_test.dart
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:life_logger/app.dart';

/// Entry point for the integration test suite.
///
/// Uses [IntegrationTestWidgetsFlutterBinding] to drive full
/// widget-tree rendering on a real or emulated device.
void main() {
  /// Ensure the integration test binding is initialized before
  /// any test frames are pumped.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Launch E2E', () {
    testWidgets(
      'app boots and displays the HarnessScreen scaffold',
      (WidgetTester tester) async {
        // Arrange — launch the app inside a ProviderScope so that
        // Riverpod providers resolve correctly. Firebase.initializeApp
        // is skipped here because it requires native platform config;
        // the production main() wraps it in try-catch for this reason.
        await tester.pumpWidget(
          const ProviderScope(child: LifeLoggerApp()),
        );

        // Allow any post-frame callbacks and animations to settle.
        await tester.pumpAndSettle();

        // Assert — a Scaffold should be present (HarnessScreen renders one).
        expect(
          find.byType(Scaffold),
          findsWidgets,
          reason: 'HarnessScreen must render at least one Scaffold.',
        );
      },
    );

    testWidgets(
      'harness displays the app title in the AppBar',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: LifeLoggerApp()),
        );
        await tester.pumpAndSettle();

        // The AppBar contains the text 'ZuraLog' as the app identity.
        expect(
          find.text('ZuraLog'),
          findsOneWidget,
          reason: 'AppBar should display the ZuraLog title.',
        );
      },
    );

    testWidgets(
      'harness contains interactive tap targets',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: LifeLoggerApp()),
        );
        await tester.pumpAndSettle();

        // The HarnessScreen uses InkWell-based _ActionChip and
        // _ActionButton widgets as its interactive controls. Verify
        // that at least one tappable InkWell is present.
        expect(
          find.byType(InkWell),
          findsWidgets,
          reason:
              'HarnessScreen must contain interactive InkWell tap targets.',
        );

        // Additionally verify that a ListView is present — the harness
        // sections are displayed in a scrollable list.
        expect(
          find.byType(ListView),
          findsOneWidget,
          reason: 'HarnessScreen must display its sections in a ListView.',
        );
      },
    );
  });
}
