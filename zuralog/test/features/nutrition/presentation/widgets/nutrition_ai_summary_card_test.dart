import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/nutrition/presentation/widgets/nutrition_ai_summary_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('NutritionAiSummaryCard', () {
    testWidgets('shows "AI Summary" label always', (tester) async {
      await tester.pumpWidget(_wrap(const NutritionAiSummaryCard(aiSummary: null)));
      expect(find.text('AI Summary'), findsOneWidget);
    });

    testWidgets('shows provided summary text when aiSummary is not null', (tester) async {
      await tester.pumpWidget(_wrap(
        const NutritionAiSummaryCard(aiSummary: 'Looking good today!'),
      ));
      expect(find.text('Looking good today!'), findsOneWidget);
    });

    testWidgets('does not show summary text when aiSummary is null', (tester) async {
      await tester.pumpWidget(_wrap(const NutritionAiSummaryCard(aiSummary: null)));
      expect(find.text('Looking good today!'), findsNothing);
    });

    testWidgets('shows "Generated Xm ago" when generatedAt is provided', (tester) async {
      final recent = DateTime.now().subtract(const Duration(minutes: 5));
      await tester.pumpWidget(_wrap(
        NutritionAiSummaryCard(
          aiSummary: 'Great job!',
          generatedAt: recent,
        ),
      ));
      expect(find.textContaining('Generated'), findsOneWidget);
      expect(find.textContaining('m ago'), findsOneWidget);
    });

    testWidgets('does not show timestamp row when generatedAt is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const NutritionAiSummaryCard(aiSummary: 'Great job!'),
      ));
      expect(find.textContaining('Generated'), findsNothing);
    });
  });
}
