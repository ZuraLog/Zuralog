import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/presentation/log_screens/symptom_log_screen.dart';

Widget _wrap(Widget child) => ProviderScope(child: MaterialApp(home: child));

void main() {
  group('SymptomLogScreen', () {
    testWidgets('renders body area chips', (tester) async {
      await tester.pumpWidget(_wrap(const SymptomLogScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Head'), findsOneWidget);
      expect(find.text('Stomach'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
    });

    testWidgets('renders severity emoji row', (tester) async {
      await tester.pumpWidget(_wrap(const SymptomLogScreen()));
      await tester.pumpAndSettle();
      expect(find.text('😌'), findsOneWidget);
      expect(find.text('🤕'), findsOneWidget);
    });

    testWidgets('Save is disabled before body area and severity selected', (tester) async {
      await tester.pumpWidget(_wrap(const SymptomLogScreen()));
      await tester.pumpAndSettle();
      final btn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save Symptom'));
      expect(btn.onPressed, isNull);
    });

    testWidgets('Save enabled after body area and severity selected', (tester) async {
      await tester.pumpWidget(_wrap(const SymptomLogScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Head'));
      await tester.pump();
      await tester.tap(find.text('😌'));
      await tester.pump();
      final btn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save Symptom'));
      expect(btn.onPressed, isNotNull);
    });
  });
}
