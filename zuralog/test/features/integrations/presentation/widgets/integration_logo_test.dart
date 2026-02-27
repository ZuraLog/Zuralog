/// Zuralog — IntegrationLogo Widget Tests.
///
/// Verifies icon resolution priority:
///   1. Hardcoded brand icon (strava, garmin, fitbit, apple_health,
///      google_health_connect) — unchanged behaviour.
///   2. Dynamic [simpleIconSlug] lookup via [_kSimpleIconsBySlug].
///   3. Asset image (not tested here — requires real asset bundle).
///   4. Initials circle fallback with optional [brandColorValue].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/integrations/presentation/widgets/integration_logo.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  group('IntegrationLogo', () {
    // ── simpleIconSlug lookup ────────────────────────────────────────────────

    testWidgets('renders Icon for known simpleIconSlug', (tester) async {
      await tester.pumpWidget(
        wrap(
          const IntegrationLogo(
            id: 'nike_run_club',
            name: 'Nike Run Club',
            simpleIconSlug: 'nike',
            brandColorValue: 0xFF111111,
          ),
        ),
      );
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets(
      'unknown simpleIconSlug falls through to initials fallback',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const IntegrationLogo(
              id: 'unknown_app',
              name: 'Unknown App',
              simpleIconSlug: 'not_a_real_slug',
            ),
          ),
        );
        // Should show initials UA
        expect(find.text('UA'), findsOneWidget);
      },
    );

    // ── Initials fallback ────────────────────────────────────────────────────

    testWidgets('renders initials fallback when no slug or icon', (
      tester,
    ) async {
      // 'My Fitness Pal' (with spaces) → multi-word → 'MF'.
      // 'MyFitnessPal' (single token) → single-word → first 2 chars → 'MY'.
      // Use two-word name to get the 'MF' initials the spec describes.
      await tester.pumpWidget(
        wrap(
          const IntegrationLogo(
            id: 'myfitnesspal',
            name: 'My FitnessPal',
          ),
        ),
      );
      expect(find.text('MF'), findsOneWidget);
    });

    testWidgets('uses brandColorValue as initials background', (tester) async {
      await tester.pumpWidget(
        wrap(
          const IntegrationLogo(
            id: 'oura',
            name: 'Oura Ring',
            brandColorValue: 0xFF514689,
          ),
        ),
      );
      // Should find a Container with the brand color
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasColor = containers.any((c) {
        final d = c.decoration;
        if (d is BoxDecoration) {
          return d.color == const Color(0xFF514689);
        }
        return false;
      });
      expect(hasColor, isTrue);
    });

    // ── Hardcoded brand icons (unchanged) ────────────────────────────────────

    testWidgets('renders strava icon via hardcoded path (unchanged)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const IntegrationLogo(
            id: 'strava',
            name: 'Strava',
          ),
        ),
      );
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('renders garmin icon via hardcoded path', (tester) async {
      await tester.pumpWidget(
        wrap(
          const IntegrationLogo(
            id: 'garmin',
            name: 'Garmin',
          ),
        ),
      );
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('renders fitbit icon via hardcoded path', (tester) async {
      await tester.pumpWidget(
        wrap(
          const IntegrationLogo(
            id: 'fitbit',
            name: 'Fitbit',
          ),
        ),
      );
      expect(find.byType(Icon), findsOneWidget);
    });

    // ── Single-word initials ─────────────────────────────────────────────────

    testWidgets('single-word name produces two-char initials', (tester) async {
      await tester.pumpWidget(
        wrap(
          const IntegrationLogo(
            id: 'whoop',
            name: 'Whoop',
          ),
        ),
      );
      expect(find.text('WH'), findsOneWidget);
    });
  });
}
