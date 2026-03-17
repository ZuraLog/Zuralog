/// Integration tests for the Today log flow.
///
/// Covers three end-to-end paths:
///   1. Water log flow: open grid → tap Water → tap Glass → Save →
///      verify provider invalidated (loggedTypes contains 'water').
///   2. Network failure: logWater throws → error snackbar shown →
///      provider NOT invalidated (sheet stays open).
///   3. Meal full-mode flow: tap Meal → navigate to MealLogScreen →
///      select Dinner → fill description → Save → verify logMeal called.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/data/today_repository.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/presentation/log_screens/meal_log_screen.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/sheets/z_log_grid_sheet.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class MockTodayRepo extends Mock implements TodayRepositoryInterface {}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// A host scaffold that opens [ZLogGridSheet] when the "Open" button is tapped.
///
/// [onFullScreenRoute] is forwarded to the sheet so full-screen tiles can
/// navigate to the correct screen during tests.
Widget _sheetHost({
  required ProviderContainer container,
  ValueChanged<String>? onFullScreenRoute,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: ctx,
              isScrollControlled: true,
              builder: (_) => ZLogGridSheet(
                parentMessenger: ScaffoldMessenger.of(ctx),
                onFullScreenRoute: onFullScreenRoute,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // Register fallback values for mocktail named-parameter matchers.
  setUpAll(() {
    registerFallbackValue(0.0);
  });

  // ── Test 1: Water log happy path ─────────────────────────────────────────

  testWidgets(
    'water log flow: Glass → Save → provider reflects water in loggedTypes',
    (tester) async {
      final repo = MockTodayRepo();

      // logWater succeeds silently.
      when(() => repo.logWater(
            amountMl: any(named: 'amountMl'),
            vesselKey: any(named: 'vesselKey'),
          )).thenAnswer((_) async {});

      // The first call returns an empty summary (before saving).
      // After invalidation, the provider returns a summary with 'water'.
      int summaryCallCount = 0;
      final container = ProviderContainer(
        overrides: [
          todayRepositoryProvider.overrideWithValue(repo),
          todayLogSummaryProvider.overrideWith((ref) async {
            summaryCallCount++;
            if (summaryCallCount == 1) {
              return TodayLogSummary.empty;
            }
            return const TodayLogSummary(
              loggedTypes: {'water'},
              latestValues: {'water': 250.0},
            );
          }),
          unitsSystemProvider.overrideWithValue(UnitsSystem.metric),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_sheetHost(container: container));

      // Open the sheet.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap the Water tile to enter the inline panel.
      await tester.tap(find.text('Water'));
      await tester.pumpAndSettle();

      // Tap the "Glass" chip (250 ml).
      await tester.tap(find.textContaining('Glass'));
      await tester.pumpAndSettle();

      // Tap "Add Water" to save.
      await tester.tap(find.text('Add Water'));
      await tester.pumpAndSettle();

      // logWater must have been called once.
      verify(() => repo.logWater(amountMl: 250.0)).called(1);

      // The sheet should have closed (Navigator.pop was called from onSaved).
      expect(find.text('Add Water'), findsNothing);

      // The provider was invalidated — summaryCallCount > 1 confirms a
      // second fetch was triggered.
      expect(summaryCallCount, greaterThan(1));
    },
  );

  // ── Test 2: Network failure path ─────────────────────────────────────────

  testWidgets(
    'network failure: logWater throws → error snackbar shown → provider NOT invalidated',
    (tester) async {
      final repo = MockTodayRepo();

      // logWater always throws.
      when(() => repo.logWater(
            amountMl: any(named: 'amountMl'),
            vesselKey: any(named: 'vesselKey'),
          )).thenThrow(Exception('network error'));

      int summaryCallCount = 0;
      final container = ProviderContainer(
        overrides: [
          todayRepositoryProvider.overrideWithValue(repo),
          todayLogSummaryProvider.overrideWith((ref) async {
            summaryCallCount++;
            return TodayLogSummary.empty;
          }),
          unitsSystemProvider.overrideWithValue(UnitsSystem.metric),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_sheetHost(container: container));

      // Open the sheet.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Snapshot the call count after initial render (1 fetch on build).
      final countBeforeSave = summaryCallCount;

      // Navigate into the Water panel.
      await tester.tap(find.text('Water'));
      await tester.pumpAndSettle();

      // Select Glass chip and attempt to save.
      await tester.tap(find.textContaining('Glass'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Water'));
      await tester.pumpAndSettle();

      // The error snackbar must appear.
      expect(
        find.text('Could not save water. Please try again.'),
        findsOneWidget,
      );

      // The sheet must still be open (water panel still visible).
      expect(find.text('Add Water'), findsOneWidget);

      // The summary provider must NOT have been invalidated — call count
      // unchanged since before the failed save.
      expect(summaryCallCount, equals(countBeforeSave));
    },
  );

  // ── Test 3: Meal full-mode flow ───────────────────────────────────────────

  testWidgets(
    'meal full-mode flow: tap Meal → navigate → select Dinner → fill description → Save → logMeal called',
    (tester) async {
      final repo = MockTodayRepo();

      // logMeal succeeds silently.
      when(() => repo.logMeal(
            mealType: any(named: 'mealType'),
            quickMode: any(named: 'quickMode'),
            description: any(named: 'description'),
            caloriesKcal: any(named: 'caloriesKcal'),
            feelChips: any(named: 'feelChips'),
            tags: any(named: 'tags'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async {});

      // getTodayLogSummary: return a summary with 'meal' after save.
      int summaryCallCount = 0;
      final container = ProviderContainer(
        overrides: [
          todayRepositoryProvider.overrideWithValue(repo),
          todayLogSummaryProvider.overrideWith((ref) async {
            summaryCallCount++;
            if (summaryCallCount == 1) return TodayLogSummary.empty;
            return const TodayLogSummary(
              loggedTypes: {'meal'},
              latestValues: {'meal': 0.0},
            );
          }),
          // Start in full mode (quickMode = false).
          mealLogModeProvider.overrideWith(() => _FixedMealLogModeNotifier(false)),
          unitsSystemProvider.overrideWithValue(UnitsSystem.metric),
        ],
      );
      addTearDown(container.dispose);

      // The sheet host intercepts the "meal" route and pushes MealLogScreen
      // directly via Navigator — no GoRouter needed.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => ZLogGridSheet(
                      parentMessenger: ScaffoldMessenger.of(ctx),
                      onFullScreenRoute: (_) {
                        // Close the sheet then push MealLogScreen.
                        Navigator.of(ctx).pop();
                        Navigator.of(ctx).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MealLogScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the grid sheet.
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap the Meal tile — this fires onFullScreenRoute.
      await tester.tap(find.text('Meal'));
      await tester.pumpAndSettle();

      // We should now be on MealLogScreen.
      expect(find.text('Log Meal'), findsOneWidget);

      // Select "Dinner" meal type chip (may already be selected from auto-suggest,
      // but tapping ensures it regardless).
      await tester.tap(find.text('Dinner'));
      await tester.pumpAndSettle();

      // Fill in the description (full mode shows 'What did you eat?' section).
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && (w.decoration?.hintText?.contains('ate') ?? false),
        ),
        'Grilled chicken with salad',
      );
      await tester.pumpAndSettle();

      // Tap "Save Meal".
      await tester.tap(find.text('Save Meal'));
      await tester.pumpAndSettle();

      // logMeal must have been called once with mealType 'dinner' and a
      // non-empty description.
      final captured = verify(() => repo.logMeal(
            mealType: captureAny(named: 'mealType'),
            quickMode: any(named: 'quickMode'),
            description: captureAny(named: 'description'),
            caloriesKcal: any(named: 'caloriesKcal'),
            feelChips: any(named: 'feelChips'),
            tags: any(named: 'tags'),
            notes: any(named: 'notes'),
          )).captured;

      // captured list order matches the captureAny declarations:
      // [0] = mealType, [1] = description
      expect(captured[0] as String, contains('dinner'));
      expect(captured[1] as String?, isNotNull);
      expect((captured[1] as String).isNotEmpty, isTrue);
    },
  );
}

// ── Stub notifier for mealLogModeProvider ─────────────────────────────────────

/// A [MealLogModeNotifier] subclass that returns a fixed value in tests,
/// bypassing SharedPreferences completely.
class _FixedMealLogModeNotifier extends MealLogModeNotifier {
  _FixedMealLogModeNotifier(this._fixedValue);
  final bool _fixedValue;

  @override
  Future<bool> build() async => _fixedValue;
}
