// zuralog/test/features/coach/presentation/widgets/coach_suggestion_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_suggestion_card.dart';

void main() {
  testWidgets('CoachSuggestionCard renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoachSuggestionCard(
            icon: Icons.bedtime_rounded,
            title: 'How did I sleep?',
            subtitle: 'Based on last night\'s data',
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('How did I sleep?'), findsOneWidget);
    expect(find.text('Based on last night\'s data'), findsOneWidget);
  });

  testWidgets('CoachSuggestionCard renders icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoachSuggestionCard(
            icon: Icons.bedtime_rounded,
            title: 'Sleep',
            subtitle: 'Check sleep',
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.bedtime_rounded), findsOneWidget);
  });

  testWidgets('CoachSuggestionCard calls onTap when tapped', (tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoachSuggestionCard(
            icon: Icons.bedtime_rounded,
            title: 'Sleep',
            subtitle: 'Check sleep',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CoachSuggestionCard));
    expect(tapped, isTrue);
  });
}
