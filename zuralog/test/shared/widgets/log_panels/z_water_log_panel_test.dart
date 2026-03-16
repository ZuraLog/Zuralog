import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/log_panels/z_water_log_panel.dart';

Widget _wrap(Widget child, {UnitsSystem units = UnitsSystem.metric}) {
  return ProviderScope(
    overrides: [
      todayLogSummaryProvider.overrideWith(
        (ref) async => TodayLogSummary.empty,
      ),
      unitsSystemProvider.overrideWithValue(units),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('ZWaterLogPanel', () {
    testWidgets('Save button disabled before vessel selection', (tester) async {
      double? savedAmount;
      await tester.pumpWidget(_wrap(ZWaterLogPanel(
        onSave: (ml) async => savedAmount = ml,
        onBack: () {},
      )));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(savedAmount, isNull);
    });

    testWidgets('Selecting Glass chip sets 250 ml and enables Save', (tester) async {
      double? savedAmount;
      await tester.pumpWidget(_wrap(ZWaterLogPanel(
        onSave: (ml) async => savedAmount = ml,
        onBack: () {},
      )));
      await tester.pump();

      await tester.tap(find.textContaining('Glass'));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(savedAmount, closeTo(250.0, 0.01));
    });

    testWidgets('Custom chip shows text field; numeric input accepted', (tester) async {
      double? savedAmount;
      await tester.pumpWidget(_wrap(ZWaterLogPanel(
        onSave: (ml) async => savedAmount = ml,
        onBack: () {},
      )));
      await tester.pump();

      await tester.tap(find.text('Custom'));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '300');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(savedAmount, closeTo(300.0, 0.01));
    });

    testWidgets('In imperial mode vessel chips show oz labels', (tester) async {
      await tester.pumpWidget(_wrap(
        ZWaterLogPanel(onSave: (_) async {}, onBack: () {}),
        units: UnitsSystem.imperial,
      ));
      await tester.pump();

      expect(find.textContaining('oz'), findsWidgets);
    });

    testWidgets('In imperial mode Glass save converts oz to ml', (tester) async {
      double? savedAmount;
      await tester.pumpWidget(_wrap(
        ZWaterLogPanel(onSave: (ml) async => savedAmount = ml, onBack: () {}),
        units: UnitsSystem.imperial,
      ));
      await tester.pump();

      await tester.tap(find.textContaining('8 oz'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      // 8 oz * 29.5735 = 236.588 ml
      expect(savedAmount, closeTo(236.6, 1.0));
    });
  });
}
