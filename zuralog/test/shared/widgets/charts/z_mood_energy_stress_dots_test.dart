import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/charts/z_mood_energy_stress_dots.dart';

void main() {
  testWidgets('ZMoodEnergyStressDots renders with all values', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 80,
          child: ZMoodEnergyStressDots(mood: 8, energy: 6, stress: 3),
        ),
      ),
    ));
    // Labels are drawn directly on the canvas by the CustomPainter, so the
    // smoke check verifies the widget pumps and renders a CustomPaint.
    expect(find.byType(ZMoodEnergyStressDots), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ZMoodEnergyStressDots renders with null values', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 80,
          child: ZMoodEnergyStressDots(mood: null, energy: null, stress: null),
        ),
      ),
    ));
    // Should not throw with all-null input.
    expect(find.byType(ZMoodEnergyStressDots), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
