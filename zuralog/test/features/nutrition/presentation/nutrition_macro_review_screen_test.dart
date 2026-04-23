import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/features/nutrition/presentation/nutrition_macro_review_screen.dart';
import 'package:zuralog/features/nutrition/presentation/nutrition_goals_wizard.dart'
    show WeightGoalChoice;

Widget wrapInApp(Widget child) => ProviderScope(
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('shows calorie budget header', (tester) async {
    await tester.pumpWidget(wrapInApp(
      const NutritionMacroReviewScreen(
        calorieBudget: 2000,
        proteinG: 150,
        carbsG: 225,
        fatG: 56,
        goalChoice: WeightGoalChoice.maintain,
      ),
    ));
    await tester.pump();
    expect(find.textContaining('2,000'), findsOneWidget);
  });
}
