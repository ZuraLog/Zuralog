/// Zuralog Settings — ThemeSelector Widget Tests.
///
/// Verifies that [ThemeSelector] renders all three mode pills, correctly
/// updates [themeModeProvider] when a pill is tapped, and applies a
/// visually distinct style to the selected pill.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/theme_provider.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/presentation/widgets/theme_selector.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';

// ── Stub ──────────────────────────────────────────────────────────────────────

/// Stub [UserPreferencesNotifier] that returns default preferences without
/// making any network calls. Overrides [save], [mutate], and [refresh] to
/// update state locally, preventing real API timers that would cause
/// `!timersPending` failures during `pumpAndSettle`.
class _StubPreferencesNotifier extends UserPreferencesNotifier {
  @override
  Future<UserPreferencesModel> build() async {
    return const UserPreferencesModel(id: 'test', userId: 'test');
  }

  @override
  Future<void> save(UserPreferencesModel updated) async {
    state = AsyncData(updated);
  }

  @override
  Future<void> mutate(
      UserPreferencesModel Function(UserPreferencesModel) fn) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(fn(current));
  }

  @override
  Future<void> refresh() async {}
}

// ── Harness ───────────────────────────────────────────────────────────────────

/// Renders [ThemeSelector] inside a minimal [UncontrolledProviderScope] +
/// [MaterialApp].
///
/// An optional [container] can be passed to access provider state after
/// pump for post-tap assertions. Containers passed in (or created by default)
/// include overrides for [userPreferencesProvider] and
/// [analyticsServiceProvider] to prevent real network calls and timers.
Widget _buildHarness({ProviderContainer? container}) {
  return UncontrolledProviderScope(
    container: container ??
        ProviderContainer(
          overrides: [
            userPreferencesProvider
                .overrideWith(() => _StubPreferencesNotifier()),
            analyticsServiceProvider.overrideWithValue(AnalyticsService()),
          ],
        ),
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
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildHarness());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders all three mode pills', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildHarness());
      await tester.pumpAndSettle();
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('tapping "Dark" updates themeModeProvider to ThemeMode.dark',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          userPreferencesProvider
              .overrideWith(() => _StubPreferencesNotifier()),
          analyticsServiceProvider.overrideWithValue(AnalyticsService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildHarness(container: container));
      // pumpAndSettle lets the AsyncNotifier resolve from SharedPreferences.
      await tester.pumpAndSettle();

      // themeModeProvider is an AsyncNotifierProvider — read the resolved value.
      // Initial value should be system (SharedPreferences empty → default).
      expect(container.read(themeModeProvider).valueOrNull, ThemeMode.system);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider).valueOrNull, ThemeMode.dark);
    });

    testWidgets('tapping "Light" updates themeModeProvider to ThemeMode.light',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          userPreferencesProvider
              .overrideWith(() => _StubPreferencesNotifier()),
          analyticsServiceProvider.overrideWithValue(AnalyticsService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildHarness(container: container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider).valueOrNull, ThemeMode.light);
    });

    testWidgets('tapping "System" keeps themeModeProvider as ThemeMode.system',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          userPreferencesProvider
              .overrideWith(() => _StubPreferencesNotifier()),
          analyticsServiceProvider.overrideWithValue(AnalyticsService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildHarness(container: container));
      await tester.pumpAndSettle();

      // Tap Dark first, then switch back to System.
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider).valueOrNull, ThemeMode.system);
    });

    testWidgets(
        'selected pill (System) has non-transparent background (visual treatment)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          userPreferencesProvider
              .overrideWith(() => _StubPreferencesNotifier()),
          analyticsServiceProvider.overrideWithValue(AnalyticsService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildHarness(container: container));
      await tester.pumpAndSettle();

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

      final animContainer = tester.widget<AnimatedContainer>(containerFinder);
      final decoration = animContainer.decoration as BoxDecoration?;
      expect(decoration?.color, AppColors.primary);
    });
  });
}
