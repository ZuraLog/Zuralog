import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuralog/features/today/data/today_repository.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/presentation/log_screens/meal_log_screen.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

class _MockTodayRepository extends Mock implements TodayRepositoryInterface {}

ProviderContainer _quickModeContainer() {
  final mock = _MockTodayRepository();
  return ProviderContainer(overrides: [
    mealLogModeProvider.overrideWith(() => _QuickModeTrueNotifier()),
    todayLogSummaryProvider.overrideWith((ref) async => TodayLogSummary.empty),
    todayRepositoryProvider.overrideWithValue(mock),
  ]);
}

/// A minimal notifier that immediately returns `true` (quick mode on).
class _QuickModeTrueNotifier extends MealLogModeNotifier {
  @override
  Future<bool> build() async => true;
}

Widget _wrap(Widget child, ProviderContainer container) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: child),
    );

void main() {
  group('MealLogScreen', () {
    testWidgets('renders quick mode toggle', (tester) async {
      await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: const MealLogScreen())));
      await tester.pumpAndSettle();
      expect(find.text('Quick calorie entry'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('renders meal type chips', (tester) async {
      await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: const MealLogScreen())));
      await tester.pumpAndSettle();
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
    });

    testWidgets('full mode shows description field', (tester) async {
      await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: const MealLogScreen())));
      await tester.pumpAndSettle();
      expect(find.text('What did you eat?'), findsOneWidget);
    });

    testWidgets('quick mode shows calorie preset chips', (tester) async {
      await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: const MealLogScreen())));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('~200'), findsOneWidget);
      expect(find.text('~600'), findsOneWidget);
    });

    testWidgets('Save disabled in quick mode when no calories entered',
        (tester) async {
      final container = _quickModeContainer();
      await tester.pumpWidget(_wrap(const MealLogScreen(), container));
      await tester.pumpAndSettle();

      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('Save enabled in quick mode after entering calories',
        (tester) async {
      final container = _quickModeContainer();
      await tester.pumpWidget(_wrap(const MealLogScreen(), container));
      await tester.pumpAndSettle();

      // Enter calories into the calories text field (hint text: 'Enter calories')
      final caloriesField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Enter calories',
      );
      await tester.enterText(caloriesField, '500');
      await tester.pump();

      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(btn.onPressed, isNotNull);
    });
  });
}
