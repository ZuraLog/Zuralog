import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/log_panels/z_water_log_panel.dart';

Widget _wrap(Widget child, {
  UnitsSystem units = UnitsSystem.metric,
  List<DailyGoal> goals = const <DailyGoal>[],
}) {
  return ProviderScope(
    overrides: [
      todayLogSummaryProvider.overrideWith(
        (ref) async => TodayLogSummary.empty,
      ),
      dailyGoalsProvider.overrideWith((ref) async => goals),
      unitsSystemProvider.overrideWithValue(units),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// Pumps long enough for async FutureProvider overrides to resolve without
/// calling pumpAndSettle, which would hang on the continuous pattern overlay
/// animation inside ZButton.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('ZWaterLogPanel', () {
    testWidgets('Add Water button is absent before any selection', (tester) async {
      await tester.pumpWidget(_wrap(ZWaterLogPanel(
        onSave: (ml, {String? vesselKey}) async {},
        onBack: () {},
      )));
      await _settle(tester);
      expect(find.byType(ZButton), findsNothing);
    });

    testWidgets('Tapping Glass pill instant-saves 250 ml with vesselKey "glass"',
        (tester) async {
      double? savedAmount;
      String? savedVesselKey;
      await tester.pumpWidget(_wrap(ZWaterLogPanel(
        onSave: (ml, {String? vesselKey}) async {
          savedAmount = ml;
          savedVesselKey = vesselKey;
        },
        onBack: () {},
      )));
      await _settle(tester);

      await tester.tap(find.text('Glass'));
      await tester.pump();

      expect(savedAmount, closeTo(250.0, 0.01));
      expect(savedVesselKey, 'glass');
    });

    testWidgets('Tapping Small cup pill instant-saves 150 ml with vesselKey "small_cup"',
        (tester) async {
      double? savedAmount;
      String? savedVesselKey;
      await tester.pumpWidget(_wrap(ZWaterLogPanel(
        onSave: (ml, {String? vesselKey}) async {
          savedAmount = ml;
          savedVesselKey = vesselKey;
        },
        onBack: () {},
      )));
      await _settle(tester);

      await tester.tap(find.text('Small cup'));
      await tester.pump();

      expect(savedAmount, closeTo(150.0, 0.01));
      expect(savedVesselKey, 'small_cup');
    });

    testWidgets('Tapping Bottle pill instant-saves 500 ml with vesselKey "bottle"',
        (tester) async {
      double? savedAmount;
      String? savedVesselKey;
      await tester.pumpWidget(_wrap(ZWaterLogPanel(
        onSave: (ml, {String? vesselKey}) async {
          savedAmount = ml;
          savedVesselKey = vesselKey;
        },
        onBack: () {},
      )));
      await _settle(tester);

      await tester.tap(find.text('Bottle'));
      await tester.pump();

      expect(savedAmount, closeTo(500.0, 0.01));
      expect(savedVesselKey, 'bottle');
    });

    testWidgets('Custom flow saves entered amount with vesselKey null',
        (tester) async {
      double? savedAmount;
      String? savedVesselKey = 'sentinel';
      await tester.pumpWidget(_wrap(ZWaterLogPanel(
        onSave: (ml, {String? vesselKey}) async {
          savedAmount = ml;
          savedVesselKey = vesselKey;
        },
        onBack: () {},
      )));
      await _settle(tester);

      await tester.tap(find.text('Custom'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '300');
      await tester.pump();

      await tester.tap(find.byType(ZButton));
      await tester.pump();

      expect(savedAmount, closeTo(300.0, 0.01));
      expect(savedVesselKey, isNull);
    });

    testWidgets('In imperial mode vessel chips show oz labels', (tester) async {
      await tester.pumpWidget(_wrap(
        ZWaterLogPanel(
          onSave: (ml, {String? vesselKey}) async {},
          onBack: () {},
        ),
        units: UnitsSystem.imperial,
      ));
      await _settle(tester);

      expect(find.textContaining('oz'), findsWidgets);
    });

    testWidgets('Imperial Glass pill instant-saves 236.6 ml', (tester) async {
      double? savedAmount;
      String? savedVesselKey;
      await tester.pumpWidget(_wrap(
        ZWaterLogPanel(
          onSave: (ml, {String? vesselKey}) async {
            savedAmount = ml;
            savedVesselKey = vesselKey;
          },
          onBack: () {},
        ),
        units: UnitsSystem.imperial,
      ));
      await _settle(tester);

      await tester.tap(find.text('Glass'));
      await tester.pump();

      // 8 oz * 29.5735 = 236.588 ml
      expect(savedAmount, closeTo(236.6, 1.0));
      expect(savedVesselKey, 'glass');
    });

    testWidgets('No Add Water button is rendered for preset-only flow',
        (tester) async {
      await tester.pumpWidget(_wrap(ZWaterLogPanel(
        onSave: (ml, {String? vesselKey}) async {},
        onBack: () {},
      )));
      await _settle(tester);
      expect(find.widgetWithText(ZButton, 'Add Water'), findsNothing);
    });
  });
}
