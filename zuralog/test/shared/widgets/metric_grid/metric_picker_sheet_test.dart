// zuralog/test/shared/widgets/metric_grid/metric_picker_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/metric_grid/metric_picker_sheet.dart';

void main() {
  group('MetricPickerSheet', () {
    testWidgets('shows all metric categories', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MetricPickerSheet(
            pinnedTypes: const {},
            onSelect: (_) {},
          ),
        ),
      ));
      // At least one category header should be visible
      expect(find.text('Wellness'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
    });

    testWidgets('already-pinned metrics show a checkmark', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MetricPickerSheet(
            pinnedTypes: const {'water'},
            onSelect: (_) {},
          ),
        ),
      ));
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
    });

    testWidgets('tapping an unpinned metric calls onSelect', (tester) async {
      String? selected;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MetricPickerSheet(
            pinnedTypes: const {},
            onSelect: (type) { selected = type; },
          ),
        ),
      ));
      await tester.tap(find.text('Water'));
      expect(selected, 'water');
    });

    testWidgets('tapping an already-pinned metric does not call onSelect', (tester) async {
      var called = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MetricPickerSheet(
            pinnedTypes: const {'water'},
            onSelect: (_) { called = true; },
          ),
        ),
      ));
      await tester.tap(find.text('Water'));
      expect(called, isFalse);
    });
  });
}
