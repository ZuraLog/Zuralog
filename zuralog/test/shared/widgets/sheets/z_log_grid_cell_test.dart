import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/sheets/z_log_grid_cell.dart';
import 'package:zuralog/shared/widgets/z_badge.dart';

void main() {
  group('ZLogGridCell', () {
    testWidgets('renders icon and label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZLogGridCell(
              icon: '💧',
              label: 'Water',
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('💧'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
    });

    testWidgets('shows green checkmark when isLogged is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZLogGridCell(
              icon: '💧',
              label: 'Water',
              isLogged: true,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('does not show checkmark when isLogged is false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZLogGridCell(
              icon: '💧',
              label: 'Water',
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('shows "Soon" badge when isComingSoon is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZLogGridCell(
              icon: '🏋️',
              label: 'Workout',
              isComingSoon: true,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byType(ZBadge), findsOneWidget);
      expect(find.text('Soon'), findsOneWidget);
    });

    testWidgets('renders at reduced opacity when isComingSoon is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZLogGridCell(
              icon: '🏋️',
              label: 'Workout',
              isComingSoon: true,
              onTap: () {},
            ),
          ),
        ),
      );
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.5);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZLogGridCell(
              icon: '💧',
              label: 'Water',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Water'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
