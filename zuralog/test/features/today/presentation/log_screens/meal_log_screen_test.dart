import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/presentation/log_screens/meal_log_screen.dart';

Widget _wrap(Widget child) => ProviderScope(child: MaterialApp(home: child));

void main() {
  group('MealLogScreen', () {
    testWidgets('renders quick mode toggle', (tester) async {
      await tester.pumpWidget(_wrap(const MealLogScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Quick calorie entry'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('renders meal type chips', (tester) async {
      await tester.pumpWidget(_wrap(const MealLogScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
    });

    testWidgets('full mode shows description field', (tester) async {
      await tester.pumpWidget(_wrap(const MealLogScreen()));
      await tester.pumpAndSettle();
      expect(find.text('What did you eat?'), findsOneWidget);
    });

    testWidgets('quick mode shows calorie preset chips', (tester) async {
      await tester.pumpWidget(_wrap(const MealLogScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('~200'), findsOneWidget);
      expect(find.text('~600'), findsOneWidget);
    });
  });
}
