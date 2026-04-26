import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/charts/z_mini_ring.dart';
import 'package:zuralog/shared/widgets/log_panels/z_water_log_panel.dart';

Future<Widget> _wrap(
  Widget child, {
  UnitsSystem units = UnitsSystem.metric,
  List<DailyGoal> goals = const <DailyGoal>[],
  Map<String, dynamic> lastWater = const <String, dynamic>{},
  TodayLogSummary summary = TodayLogSummary.empty,
}) async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      todayLogSummaryProvider.overrideWith((ref) async => summary),
      dailyGoalsProvider.overrideWith((ref) async => goals),
      latestLogValuesProvider(latestLogValuesKey(const {'water'}))
          .overrideWith((ref) async => lastWater),
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
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Add Water button is absent before any selection', (tester) async {
      await tester.pumpWidget(await _wrap(ZWaterLogPanel(
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
      await tester.pumpWidget(await _wrap(ZWaterLogPanel(
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
      // Drain animation controller (400ms) + badge dismiss timer (800ms).
      await tester.pump(const Duration(milliseconds: 1500));
    });

    testWidgets('Tapping Small cup pill instant-saves 150 ml with vesselKey "small_cup"',
        (tester) async {
      double? savedAmount;
      String? savedVesselKey;
      await tester.pumpWidget(await _wrap(ZWaterLogPanel(
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
      await tester.pump(const Duration(milliseconds: 1500));
    });

    testWidgets('Tapping Bottle pill instant-saves 500 ml with vesselKey "bottle"',
        (tester) async {
      double? savedAmount;
      String? savedVesselKey;
      await tester.pumpWidget(await _wrap(ZWaterLogPanel(
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
      await tester.pump(const Duration(milliseconds: 1500));
    });

    testWidgets('Tapping Large bottle pill instant-saves 750 ml with vesselKey "large"',
        (tester) async {
      double? savedAmount;
      String? savedVesselKey;
      await tester.pumpWidget(await _wrap(ZWaterLogPanel(
        onSave: (ml, {String? vesselKey}) async {
          savedAmount = ml;
          savedVesselKey = vesselKey;
        },
        onBack: () {},
      )));
      await _settle(tester);

      await tester.tap(find.text('Large bottle'));
      await tester.pump();

      expect(savedAmount, closeTo(750.0, 0.01));
      expect(savedVesselKey, 'large');
      await tester.pump(const Duration(milliseconds: 1500));
    });

    testWidgets('Custom flow saves entered amount with vesselKey null',
        (tester) async {
      double? savedAmount;
      String? savedVesselKey = 'sentinel';
      await tester.pumpWidget(await _wrap(ZWaterLogPanel(
        onSave: (ml, {String? vesselKey}) async {
          savedAmount = ml;
          savedVesselKey = vesselKey;
        },
        onBack: () {},
      )));
      await _settle(tester);

      await tester.tap(find.text('Custom amount'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '300');
      await tester.pump();

      await tester.tap(find.widgetWithText(ZButton, 'Add Water'));
      await tester.pump();

      expect(savedAmount, closeTo(300.0, 0.01));
      expect(savedVesselKey, isNull);
      await tester.pump(const Duration(milliseconds: 1500));
    });

    testWidgets('In imperial mode vessel chips show oz labels', (tester) async {
      await tester.pumpWidget(await _wrap(
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
      await tester.pumpWidget(await _wrap(
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
      await tester.pump(const Duration(milliseconds: 1500));
    });

    testWidgets('No Add Water button is rendered for preset-only flow',
        (tester) async {
      await tester.pumpWidget(await _wrap(ZWaterLogPanel(
        onSave: (ml, {String? vesselKey}) async {},
        onBack: () {},
      )));
      await _settle(tester);
      expect(find.widgetWithText(ZButton, 'Add Water'), findsNothing);
    });

    testWidgets('Smart default: persisted vessel renders the indicator dot',
        (tester) async {
      SharedPreferences.setMockInitialValues({'water_log_last_vessel': 'glass'});
      await tester.pumpWidget(await _wrap(ZWaterLogPanel(
        onSave: (ml, {String? vesselKey}) async {},
        onBack: () {},
      )));
      await tester.pump(); // first frame
      await tester.pump(const Duration(milliseconds: 50)); // SharedPreferences load

      // The Glass pill should now contain a 4×4 circle Container (the dot).
      final glassPillFinder = find.ancestor(
        of: find.text('Glass'),
        matching: find.byType(GestureDetector),
      );
      expect(glassPillFinder, findsOneWidget);

      final dot = find.descendant(
        of: glassPillFinder,
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            (w.decoration is BoxDecoration) &&
            ((w.decoration as BoxDecoration).shape == BoxShape.circle)),
      );
      expect(dot, findsOneWidget);
    });

    testWidgets('Last drink hint reads "Last drink: today" when date == today',
        (tester) async {
      final today = DateTime.now();
      final iso = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      await tester.pumpWidget(await _wrap(
        ZWaterLogPanel(
          onSave: (ml, {String? vesselKey}) async {},
          onBack: () {},
        ),
        lastWater: {
          'water': {'value': 250.0, 'unit': 'mL', 'date': iso},
        },
      ));
      await tester.pump();
      expect(find.text('Last drink: today'), findsOneWidget);
    });

    testWidgets('Last drink hint reads "Last drink: yesterday"', (tester) async {
      final y = DateTime.now().subtract(const Duration(days: 1));
      final iso = '${y.year.toString().padLeft(4, '0')}-'
          '${y.month.toString().padLeft(2, '0')}-'
          '${y.day.toString().padLeft(2, '0')}';
      await tester.pumpWidget(await _wrap(
        ZWaterLogPanel(
          onSave: (ml, {String? vesselKey}) async {},
          onBack: () {},
        ),
        lastWater: {
          'water': {'value': 250.0, 'unit': 'mL', 'date': iso},
        },
      ));
      await tester.pump();
      expect(find.text('Last drink: yesterday'), findsOneWidget);
    });

    testWidgets('Last drink hint shows empty state when no log exists',
        (tester) async {
      await tester.pumpWidget(await _wrap(ZWaterLogPanel(
        onSave: (ml, {String? vesselKey}) async {},
        onBack: () {},
      )));
      await tester.pump();
      expect(find.text('No drinks yet today'), findsOneWidget);
    });

    testWidgets('Ring colour switches to success when goal is reached',
        (tester) async {
      await tester.pumpWidget(await _wrap(
        ZWaterLogPanel(
          onSave: (ml, {String? vesselKey}) async {},
          onBack: () {},
        ),
        summary: const TodayLogSummary(
          loggedTypes: <String>{'water'},
          latestValues: <String, dynamic>{'water': 2000.0},
        ),
        goals: [
          const DailyGoal(
            id: 'g1',
            label: 'Water',
            current: 2000.0,
            target: 2000.0,
            unit: 'mL',
          ),
        ],
      ));
      await tester.pump();
      final ring = tester.widget<ZMiniRing>(find.byType(ZMiniRing));
      expect(ring.color, AppColors.success);
      // The goal-completion animation schedules a 400ms timer inside
      // _WaterRingHeaderState.didUpdateWidget. Drain it so the widget tree
      // can be disposed cleanly without a "pending timers" assertion.
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('Ring colour is categoryBody mid-progress', (tester) async {
      await tester.pumpWidget(await _wrap(
        ZWaterLogPanel(
          onSave: (ml, {String? vesselKey}) async {},
          onBack: () {},
        ),
        summary: const TodayLogSummary(
          loggedTypes: <String>{'water'},
          latestValues: <String, dynamic>{'water': 1000.0},
        ),
        goals: [
          const DailyGoal(
            id: 'g1',
            label: 'Water',
            current: 1000.0,
            target: 2000.0,
            unit: 'mL',
          ),
        ],
      ));
      await tester.pump();
      final ring = tester.widget<ZMiniRing>(find.byType(ZMiniRing));
      expect(ring.color, AppColors.categoryBody);
    });
  });
}
