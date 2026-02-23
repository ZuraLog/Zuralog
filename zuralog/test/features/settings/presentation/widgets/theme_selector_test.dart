/// Zuralog Settings — ThemeSelector Widget Tests.
///
/// Verifies that [ThemeSelector] renders all three mode pills, correctly
/// updates [themeModeProvider] when a pill is tapped, and applies a
/// visually distinct style to the selected pill.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/theme_provider.dart';
import 'package:zuralog/features/settings/presentation/widgets/theme_selector.dart';

// ── Harness ───────────────────────────────────────────────────────────────────

/// Renders [ThemeSelector] inside a minimal [ProviderScope] + [MaterialApp].
///
/// An optional [container] can be passed to access provider state after
/// pump for post-tap assertions.
Widget _buildHarness({ProviderContainer? container}) {
  return UncontrolledProviderScope(
    container: container ?? ProviderContainer(),
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: const Scaffold(
        body: Center(child: ThemeSelector()),
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('ThemeSelector', () {
    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders all three mode pills', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('tapping "Dark" updates themeModeProvider to ThemeMode.dark',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildHarness(container: container));
      await tester.pump();

      // Initial value should be system.
      expect(container.read(themeModeProvider), ThemeMode.system);

      // Tap the Dark pill.
      await tester.tap(find.text('Dark'));
      await tester.pump();

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    testWidgets('tapping "Light" updates themeModeProvider to ThemeMode.light',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildHarness(container: container));
      await tester.pump();

      await tester.tap(find.text('Light'));
      await tester.pump();

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    testWidgets('tapping "System" keeps themeModeProvider as ThemeMode.system',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildHarness(container: container));
      await tester.pump();

      // Tap Dark first, then switch back to System.
      await tester.tap(find.text('Dark'));
      await tester.pump();
      await tester.tap(find.text('System'));
      await tester.pump();

      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    testWidgets(
        'selected pill (System) has non-transparent background (visual treatment)',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildHarness(container: container));
      await tester.pump();

      // The selected pill (System by default) should be rendered with the
      // primary color background. Verify by checking the AnimatedContainer
      // that wraps the "System" text has primary fill.
      final systemText = find.text('System');
      expect(systemText, findsOneWidget);

      // The parent AnimatedContainer of the selected pill has a BoxDecoration
      // with AppColors.primary. We confirm this via the widget tree.
      final containerFinder = find.ancestor(
        of: systemText,
        matching: find.byType(AnimatedContainer),
      );
      expect(containerFinder, findsOneWidget);

      final animContainer =
          tester.widget<AnimatedContainer>(containerFinder);
      final decoration = animContainer.decoration as BoxDecoration?;
      expect(decoration?.color, AppColors.primary);
    });
  });
}
