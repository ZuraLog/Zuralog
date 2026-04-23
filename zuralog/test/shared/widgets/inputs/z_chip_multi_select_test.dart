import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

void main() {
  group('ZChipMultiSelect', () {
    testWidgets('tapping a non-exclusive chip adds it to the selection', (tester) async {
      List<String>? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZChipMultiSelect<String>(
            options: const [
              ZChipOption(value: 'veg', label: 'Vegetarian'),
              ZChipOption(value: 'vegan', label: 'Vegan'),
            ],
            values: const [],
            onChanged: (v) => captured = v,
          ),
        ),
      ));

      await tester.tap(find.text('Vegetarian'));
      await tester.pump();
      expect(captured, ['veg']);
    });

    testWidgets('tapping a selected chip removes it from the selection', (tester) async {
      List<String>? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZChipMultiSelect<String>(
            options: const [
              ZChipOption(value: 'veg', label: 'Vegetarian'),
              ZChipOption(value: 'vegan', label: 'Vegan'),
            ],
            values: const ['veg', 'vegan'],
            onChanged: (v) => captured = v,
          ),
        ),
      ));

      await tester.tap(find.text('Vegan'));
      await tester.pump();
      expect(captured, ['veg']);
    });

    testWidgets('tapping the exclusive pill clears the selection', (tester) async {
      List<String>? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZChipMultiSelect<String>(
            options: const [
              ZChipOption(value: 'veg', label: 'Vegetarian'),
            ],
            values: const ['veg'],
            exclusiveLabel: 'None',
            onChanged: (v) => captured = v,
          ),
        ),
      ));

      await tester.tap(find.text('None'));
      await tester.pump();
      expect(captured, <String>[]);
    });

    testWidgets('tapping a regular chip while exclusive is active selects that chip', (tester) async {
      List<String>? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZChipMultiSelect<String>(
            options: const [
              ZChipOption(value: 'veg', label: 'Vegetarian'),
            ],
            values: const [],
            exclusiveLabel: 'None',
            onChanged: (v) => captured = v,
          ),
        ),
      ));

      await tester.tap(find.text('Vegetarian'));
      await tester.pump();
      expect(captured, ['veg']);
    });
  });
}
