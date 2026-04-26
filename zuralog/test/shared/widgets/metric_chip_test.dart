import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/shared/widgets/metric_chip.dart';

void main() {
  Widget harness(Widget child) =>
      MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child));

  testWidgets('MetricChip shows label, value, unit, delta', (tester) async {
    await tester.pumpWidget(harness(const MetricChip(
      label: 'HRV',
      value: '58',
      unit: 'ms',
      delta: 'up 12%',
      accent: Colors.green,
    )));
    expect(find.text('HRV'), findsOneWidget);
    expect(find.text('58'), findsOneWidget);
    expect(find.text('ms'), findsOneWidget);
    expect(find.text('up 12%'), findsOneWidget);
  });

  testWidgets('MetricChip renders em-dash when value is null', (tester) async {
    await tester.pumpWidget(harness(const MetricChip(
      label: 'HRV',
      value: null,
      accent: Colors.green,
    )));
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('MetricChip calls onTap when tapped', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(harness(MetricChip(
      label: 'HRV',
      value: '58',
      accent: Colors.green,
      onTap: () => tapped++,
    )));
    await tester.tap(find.byType(MetricChip));
    expect(tapped, 1);
  });
}
