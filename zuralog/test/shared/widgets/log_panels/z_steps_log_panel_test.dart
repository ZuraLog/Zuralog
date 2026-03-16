import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/log_panels/z_steps_log_panel.dart';

ProviderContainer _container() => ProviderContainer(
      overrides: [
        todayLogSummaryProvider.overrideWith(
          (ref) async => TodayLogSummary.empty,
        ),
      ],
    );

Widget _buildPanel({
  required ProviderContainer container,
  Future<void> Function(int, String)? onSave,
  VoidCallback? onBack,
}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: ZStepsLogPanel(
            onSave: onSave ?? (steps, mode) async {},
            onBack: onBack ?? () {},
          ),
        ),
      ),
    );

void main() {
  group('ZStepsLogPanel', () {
    testWidgets('Test 1: Save disabled initially (steps = 0)', (tester) async {
      final container = _container();
      await tester.pumpWidget(_buildPanel(container: container));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets(
        'Test 2: entering a value enables Save and calls onSave with correct int',
        (tester) async {
      final container = _container();
      int? savedSteps;
      await tester.pumpWidget(
        _buildPanel(
          container: container,
          onSave: (steps, mode) async { savedSteps = steps; },
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), '8500');
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(savedSteps, 8500);
    });

    testWidgets('Test 3: renders numeric input field', (tester) async {
      final container = _container();
      await tester.pumpWidget(_buildPanel(container: container));
      await tester.pump();

      expect(find.byType(TextField), findsWidgets);
      // Should find the step count input field by hint text.
      expect(find.text('Enter step count'), findsOneWidget);
    });
  });
}
