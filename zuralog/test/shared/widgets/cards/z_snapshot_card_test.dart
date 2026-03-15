import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/shared/widgets/cards/z_snapshot_card.dart';

void main() {
  group('ZSnapshotCard', () {
    testWidgets('renders value and unit when data exists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZSnapshotCard(
              data: const SnapshotCardData(
                metricType: 'water',
                label: 'Water',
                icon: '💧',
                value: '750',
                unit: 'ml',
              ),
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('750'), findsOneWidget);
      expect(find.text('ml'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
    });

    testWidgets('renders empty state with dash when isEmpty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZSnapshotCard(
              data: const SnapshotCardData(
                metricType: 'water',
                label: 'Water',
                icon: '💧',
                isEmpty: true,
              ),
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('is dimmed (opacity 0.5) when isEmpty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZSnapshotCard(
              data: const SnapshotCardData(
                metricType: 'water',
                label: 'Water',
                icon: '💧',
                isEmpty: true,
              ),
              onTap: () {},
            ),
          ),
        ),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(ZSnapshotCard),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.5);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZSnapshotCard(
              data: const SnapshotCardData(
                metricType: 'water',
                label: 'Water',
                icon: '💧',
                isEmpty: true,
              ),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ZSnapshotCard));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
