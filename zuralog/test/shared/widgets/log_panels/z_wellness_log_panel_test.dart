import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/log_panels/z_wellness_log_panel.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('ZWellnessLogPanel', () {
    testWidgets('Save button disabled before any slider is touched', (tester) async {
      await tester.pumpWidget(_wrap(ZWellnessLogPanel(
        onSave: (_) async {},
        onBack: () {},
      )));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Moving Mood slider enables Save and sets mood non-null', (tester) async {
      WellnessLogData? saved;
      await tester.pumpWidget(_wrap(ZWellnessLogPanel(
        onSave: (data) async => saved = data,
        onBack: () {},
      )));
      await tester.pump();

      final sliderFinder = find.byType(Slider).first;
      await tester.drag(sliderFinder, const Offset(20.0, 0.0));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
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

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'A' * 600);
      await tester.pump();

      final tf = tester.widget<TextField>(textField);
      expect(tf.maxLength, 500);
    });
  });
}
