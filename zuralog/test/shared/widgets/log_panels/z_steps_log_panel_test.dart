// zuralog/test/shared/widgets/log_panels/z_steps_log_panel_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/shared/widgets/log_panels/z_steps_log_panel.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildPanel({Future<void> Function(int, String)? onSave}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          // onSave signature: Future<void> Function(int steps, String mode)
          body: ZStepsLogPanel(
            onBack: () {},
            onSave: onSave ?? (steps, mode) async {},
          ),
        ),
      ),
    );
  }

  group('ZStepsLogPanel mode toggle', () {
    testWidgets('toggle is visible', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('starts in add mode by default', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pumpAndSettle();
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isTrue); // add mode = toggle ON
    });

    testWidgets('tapping toggle changes to override mode', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse); // override mode = toggle OFF
    });

    testWidgets('mode persists — override mode loaded from prefs', (tester) async {
      SharedPreferences.setMockInitialValues({'steps_log_mode': 'override'});
      await tester.pumpWidget(buildPanel());
      await tester.pumpAndSettle();
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse); // override mode = toggle OFF
    });
  });

  group('ZStepsLogPanel save callback', () {
    testWidgets('save button disabled when no steps entered', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pumpAndSettle();
      // Find the Save button — it should be disabled (onPressed is null)
      final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('save passes add mode string when in default mode', (tester) async {
      String? capturedMode;
      await tester.pumpWidget(buildPanel(
        onSave: (steps, mode) async {
          capturedMode = mode;
        },
      ));
      await tester.pumpAndSettle();

      // Enter a step count
      await tester.enterText(find.byType(TextField), '5000');
      await tester.pumpAndSettle();

      // Tap save
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Default mode is add
      expect(capturedMode, isNotNull, reason: 'onSave was never called — check if the save button was tappable');
      expect(capturedMode, equals('add'));
    });

    testWidgets('save passes override mode when toggled off', (tester) async {
      String? capturedMode;
      await tester.pumpWidget(buildPanel(
        onSave: (steps, mode) async {
          capturedMode = mode;
        },
      ));
      await tester.pumpAndSettle();

      // Toggle to override mode
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Enter a step count
      await tester.enterText(find.byType(TextField), '10000');
      await tester.pumpAndSettle();

      // Tap save
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(capturedMode, isNotNull, reason: 'onSave was never called — check if the save button was tappable');
      expect(capturedMode, equals('override'));
    });
  });
}
