import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/sheets/z_log_grid_cell.dart';
import 'package:zuralog/shared/widgets/sheets/z_log_grid_sheet.dart';

ProviderContainer _container({Set<String> loggedTypes = const {}}) =>
    ProviderContainer(
      overrides: [
        todayLogSummaryProvider.overrideWith(
          (ref) async => TodayLogSummary(
            loggedTypes: loggedTypes,
            latestValues: const {},
          ),
        ),
      ],
    );

void main() {
  group('ZLogGridSheet', () {
    testWidgets('renders all 10 tiles', (tester) async {
      final container = _container();
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
                    builder: (_) => const ZLogGridSheet(),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(ZLogGridCell), findsNWidgets(10));
    });

    testWidgets('renders title text', (tester) async {
      final container = _container();
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
                    builder: (_) => const ZLogGridSheet(),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('What do you want to log?'), findsOneWidget);
    });

    testWidgets('Workout tile shows snackbar on tap', (tester) async {
      final container = _container();
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
                    builder: (_) => const ZLogGridSheet(),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workout'));
      await tester.pumpAndSettle();
      expect(
        find.text('Workout tracking is coming soon — stay tuned!'),
        findsOneWidget,
      );
    });

    testWidgets('tapping an inline tile shows panel view and back button',
        (tester) async {
      final container = _container();
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
                    builder: (_) => const ZLogGridSheet(),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // Tap an inline tile (Water).
      await tester.tap(find.text('Water'));
      await tester.pumpAndSettle();
      // Grid should be gone, back button should appear.
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      // The title should change to the panel title.
      expect(find.textContaining('Water'), findsWidgets);
    });

    testWidgets('shows checkmark on tiles in todayLogSummaryProvider',
        (tester) async {
      final container = _container(loggedTypes: {'water', 'mood'});
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
                    builder: (_) => const ZLogGridSheet(),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // Two checkmarks should be visible (water + mood/wellness).
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    });
  });
}
