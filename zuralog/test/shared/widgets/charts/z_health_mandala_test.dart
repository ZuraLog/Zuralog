import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart' show HealthCategory;
import 'package:zuralog/features/data/domain/mandala_data.dart';
import 'package:zuralog/shared/widgets/charts/z_health_mandala.dart';

void main() {
  testWidgets('ZHealthMandala renders with empty data and shows "—"',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 280,
          height: 280,
          child: ZHealthMandala(
            data: MandalaData(wedges: <MandalaWedge>[]),
            healthScore: null,
          ),
        ),
      ),
    ));
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('ZHealthMandala fires onSpokeTap when a spoke is tapped',
      (tester) async {
    String? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 280,
          height: 280,
          child: ZHealthMandala(
            data: MandalaData(wedges: [
              MandalaWedge(category: HealthCategory.activity, spokes: const [
                MandalaSpoke(
                  metricId: 'steps',
                  displayName: 'Steps',
                  todayValue: 12000,
                  baseline30d: 8000,
                  inverted: false,
                ),
              ]),
            ]),
            healthScore: 78,
            onSpokeTap: (id) => tapped = id,
          ),
        ),
      ),
    ));
    // Activity wedge — single spoke, ratio clamped to 1.5, drawn at the
    // wedge's center angle (top-right). Center of canvas (140,140), baseline
    // radius = 140 * 0.85 * 0.7 = 83.3. Spoke length = 83.3 * 1.5 = 124.95.
    // Activity wedge center: -π/2 + 1.5*π/3 = 0 (pointing right).
    // Tip ≈ (140 + 124.95, 140) = (~265, 140). Tap target is 24×24 around it.
    await tester.tapAt(const Offset(265, 140));
    await tester.pump();
    expect(tapped, 'steps');
  });

  testWidgets('ZHealthMandala fires onCenterTap when center is tapped',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 280,
          height: 280,
          child: ZHealthMandala(
            data: const MandalaData(wedges: <MandalaWedge>[]),
            healthScore: 78,
            onCenterTap: () => tapped = true,
          ),
        ),
      ),
    ));
    await tester.tapAt(const Offset(140, 140));
    await tester.pump();
    expect(tapped, true);
  });
}
