import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart'
    show HealthCategory, MetricDataPoint;
import 'package:zuralog/shared/widgets/sheets/z_metric_microscope_sheet.dart';

void main() {
  testWidgets('showZMetricMicroscopeSheet displays metric name + value',
      (tester) async {
    final dataPoints = [
      for (var i = 0; i < 10; i++)
        MetricDataPoint(
          timestamp: DateTime(2026, 4, 1 + i).toIso8601String(),
          value: 60.0 + i.toDouble(),
        ),
    ];
    var askCoachCalled = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showZMetricMicroscopeSheet(
                context,
                metricId: 'resting_heart_rate',
                category: HealthCategory.heart,
                displayName: 'Resting heart rate',
                unit: 'bpm',
                todayValue: 58,
                baseline30d: 64,
                inverted: true,
                dataPoints: dataPoints,
                lastReadingTime: DateTime.now(),
                onAskCoach: () => askCoachCalled = true,
              ),
              child: const Text('Open'),
            ),
          ),
        );
      }),
    ));
    await tester.tap(find.text('Open'));
    // Advance enough frames for the modal sheet animation to finish, but
    // avoid pumpAndSettle — the Ask Coach button contains a perpetually
    // animated brand pattern overlay (ZPatternOverlay with animate: true)
    // that never settles.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Resting heart rate'), findsOneWidget);
    // Value renders both in the hero (Lora 48pt) and in the "today" stat
    // tile (Lora 14pt), so allow ≥ 1 match.
    expect(find.text('58'), findsWidgets);
    expect(find.text('Ask Coach about this'), findsOneWidget);

    // The sheet is tall enough that the Ask Coach button sits just below
    // the test surface's default 800x600 viewport. Scroll it into view
    // before tapping.
    await tester.ensureVisible(find.text('Ask Coach about this'));
    await tester.pump();
    await tester.tap(find.text('Ask Coach about this'));
    await tester.pump();
    expect(askCoachCalled, true);
  });
}
