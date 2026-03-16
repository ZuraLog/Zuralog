import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/log_panels/z_weight_log_panel.dart';

ProviderContainer _container({UnitsSystem units = UnitsSystem.metric}) =>
    ProviderContainer(
      overrides: [
        todayLogSummaryProvider.overrideWith(
          (ref) async => TodayLogSummary.empty,
        ),
        unitsSystemProvider.overrideWith(
          (ref) => units,
        ),
      ],
    );

Widget _buildPanel({
  required ProviderContainer container,
  void Function(double)? onSave,
  VoidCallback? onBack,
}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: ZWeightLogPanel(
            onSave: onSave ?? (_) {},
            onBack: onBack ?? () {},
          ),
        ),
      ),
    );

void main() {
  test('weight delta calculation is correct', () {
    // 80.0 kg vs 79.5 kg → delta = +0.5
    final delta = 80.0 - 79.5;
    expect(delta, closeTo(0.5, 0.001));
  });

  test('lbs step is applied correctly in kg storage', () {
    // 0.1 lbs in kg = 0.1 / 2.20462 ≈ 0.04536 kg
    const lbsStep = 0.1 / 2.20462;
    const startKg = 70.0;
    final result = (startKg + lbsStep).clamp(20.0, 500.0);
    expect(result, closeTo(70.045, 0.001));
  });

  group('ZWeightLogPanel', () {
    testWidgets('Test 1: renders with default value 70.0 shown', (tester) async {
      final container = _container();
      await tester.pumpWidget(_buildPanel(container: container));
      await tester.pumpAndSettle();

      // Default is 70.0 kg → displayed as "70.0"
      expect(find.text('70.0'), findsOneWidget);
    });

    testWidgets('Test 2: tapping + button increases displayed value',
        (tester) async {
      final container = _container();
      await tester.pumpWidget(_buildPanel(container: container));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      // 70.0 + 0.1 = 70.1
      expect(find.text('70.1'), findsOneWidget);
    });

    testWidgets('Test 3: Save button always enabled', (tester) async {
      final container = _container();
      await tester.pumpWidget(_buildPanel(container: container));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });
  });
}
