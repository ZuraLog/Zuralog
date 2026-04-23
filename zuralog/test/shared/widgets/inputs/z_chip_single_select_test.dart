import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

void main() {
  group('ZChipSingleSelect', () {
    testWidgets('renders every option label', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ZChipSingleSelect<String>(
            options: [
              ZChipOption(value: 'a', label: 'Alpha'),
              ZChipOption(value: 'b', label: 'Beta'),
            ],
            value: 'a',
            onChanged: _noop,
          ),
        ),
      ));

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('tapping an option fires onChanged with its value', (tester) async {
      String? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZChipSingleSelect<String>(
            options: const [
              ZChipOption(value: 'a', label: 'Alpha'),
              ZChipOption(value: 'b', label: 'Beta'),
            ],
            value: 'a',
            onChanged: (v) => captured = v,
          ),
        ),
      ));

      await tester.tap(find.text('Beta'));
      await tester.pump();
      expect(captured, 'b');
    });
  });
}

void _noop(String _) {}
