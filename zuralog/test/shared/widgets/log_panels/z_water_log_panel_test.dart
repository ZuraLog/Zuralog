import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/log_panels/z_water_log_panel.dart';

ProviderContainer _container({Map<String, dynamic> latestValues = const {}}) =>
    ProviderContainer(
      overrides: [
        todayLogSummaryProvider.overrideWith(
          (ref) async => TodayLogSummary(
            loggedTypes:
                latestValues.containsKey('water') ? const {'water'} : const {},
            latestValues: latestValues,
          ),
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
          body: ZWaterLogPanel(
            onSave: onSave ?? (_) {},
            onBack: onBack ?? () {},
          ),
        ),
      ),
    );

void main() {
  group('ZWaterLogPanel', () {
    testWidgets('Test 1: renders vessel chips', (tester) async {
      final container = _container();
      await tester.pumpWidget(_buildPanel(container: container));
      await tester.pumpAndSettle();

      expect(find.text('Small cup'), findsOneWidget);
      expect(find.text('Glass'), findsOneWidget);
      expect(find.text('Bottle'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets(
        'Test 2: Save button disabled when no vessel selected and no custom value',
        (tester) async {
      final container = _container();
      await tester.pumpWidget(_buildPanel(container: container));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets(
        'Test 3: selecting Glass sets 250ml and enables Save; tapping Save calls onSave(250.0)',
        (tester) async {
      final container = _container();
      double? savedAmount;
      await tester.pumpWidget(
        _buildPanel(
          container: container,
          onSave: (amount) => savedAmount = amount,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Glass'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(savedAmount, 250.0);
    });

    testWidgets(
        "Test 4: shows today total when water has been logged (latestValues['water'] = 750.0)",
        (tester) async {
      final container = _container(latestValues: {'water': 750.0});
      await tester.pumpWidget(_buildPanel(container: container));
      await tester.pumpAndSettle();

      expect(find.text('750 ml logged today'), findsOneWidget);
    });
  });
}
