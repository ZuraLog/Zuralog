import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/log_panels/z_wellness_log_panel.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// Navigates to the quick check-in state by tapping "Quick check-in".
Future<void> _goToQuickCheckin(WidgetTester tester) async {
  await tester.tap(find.text('Quick check-in'));
  await tester.pump();
}

void main() {
  group('ZWellnessLogPanel', () {
    testWidgets('Save button disabled before any face is tapped', (tester) async {
      await tester.pumpWidget(_wrap(ZWellnessLogPanel(
        onSave: (_) async {},
        onBack: () {},
      )));
      await tester.pump();

      // Navigate to quick check-in (offline-capable path, no sliders)
      await _goToQuickCheckin(tester);

      // ZButton renders disabled when onPressed is null — check by finding the
      // ZButton whose label is 'Save check-in' and verifying its onPressed is null.
      final saveButton = tester.widget<ZButton>(
        find.widgetWithText(ZButton, 'Save check-in'),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('Tapping Mood face enables Save and sets mood non-null', (tester) async {
      WellnessLogData? saved;
      await tester.pumpWidget(_wrap(ZWellnessLogPanel(
        onSave: (data) async => saved = data,
        onBack: () {},
      )));
      await tester.pump();

      // Navigate to quick check-in
      await _goToQuickCheckin(tester);

      // Tap the first icon in the Mood sentiment selector (the leftmost face)
      await tester.tap(find.byIcon(Icons.sentiment_very_dissatisfied_rounded).first);
      await tester.pump();

      // Save button should now be enabled
      final saveButton = tester.widget<ZButton>(
        find.widgetWithText(ZButton, 'Save check-in'),
      );
      expect(saveButton.onPressed, isNotNull);

      // Tap save
      await tester.tap(find.widgetWithText(ZButton, 'Save check-in'));
      await tester.pump();
      expect(saved, isNotNull);
      expect(saved!.mood, isNotNull);
      expect(saved!.energy, isNull);
      expect(saved!.stress, isNull);
    });

    testWidgets('Notes field enforces 500 char limit', (tester) async {
      await tester.pumpWidget(_wrap(ZWellnessLogPanel(
        onSave: (_) async {},
        onBack: () {},
      )));
      await tester.pump();

      // Navigate to quick check-in where the notes field lives
      await _goToQuickCheckin(tester);

      // The notes AppTextField renders a TextField internally
      final textField = find.byType(TextField).last;
      final tf = tester.widget<TextField>(textField);
      expect(tf.maxLength, 500);
    });
  });
}
