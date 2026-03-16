import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/log_panels/z_wellness_log_panel.dart';

Widget _buildPanel({
  void Function(WellnessLogData)? onSave,
  VoidCallback? onBack,
}) =>
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ZWellnessLogPanel(
            onSave: onSave ?? (_) {},
            onBack: onBack ?? () {},
          ),
        ),
      ),
    );

void main() {
  group('ZWellnessLogPanel', () {
    testWidgets('Test 1: Save disabled initially (no sliders touched)',
        (tester) async {
      await tester.pumpWidget(_buildPanel());
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Test 2: Save enabled after moving Mood slider',
        (tester) async {
      await tester.pumpWidget(_buildPanel());
      await tester.pump();

      // Drag the first slider (Mood) to simulate user interaction.
      await tester.drag(find.byType(Slider).first, const Offset(50, 0));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Test 3: notes field has 500-char limit enforced',
        (tester) async {
      await tester.pumpWidget(_buildPanel());
      await tester.pump();

      // The notes TextField should have maxLength of 500.
      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      final notesField = textFields.firstWhere(
        (tf) =>
            tf.maxLength == 500 ||
            (tf.inputFormatters?.any((f) => f.toString().contains('500')) ??
                false),
        orElse: () => textFields.first,
      );
      // Verify either maxLength is 500 or a LengthLimitingTextInputFormatter
      // is present with maxLength 500.
      final hasLimit = notesField.maxLength == 500 ||
          (notesField.inputFormatters?.any(
                (f) =>
                    f is LengthLimitingTextInputFormatter &&
                    f.maxLength == 500,
              ) ??
              false);
      expect(hasLimit, isTrue);
    });
  });
}
