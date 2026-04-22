import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/features/nutrition/presentation/nutrition_goals_setup_sheet.dart';

// Helper: wrap widget in Material app with Riverpod
Widget wrapInApp(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('shows Height and Weight fields on open', (tester) async {
    await tester.pumpWidget(wrapInApp(const NutritionGoalsSetupSheet()));
    await tester.pump();
    expect(find.textContaining('Height'), findsOneWidget);
    expect(find.textContaining('Weight'), findsOneWidget);
  });
}
