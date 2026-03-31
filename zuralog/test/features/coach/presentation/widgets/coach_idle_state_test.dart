// zuralog/test/features/coach/presentation/widgets/coach_idle_state_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_idle_state.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_suggestion_card.dart';

void main() {
  testWidgets('CoachIdleState shows three suggestion cards', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CoachIdleState(onSuggestionTap: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CoachSuggestionCard), findsNWidgets(3));
  });

  testWidgets('CoachIdleState shows a greeting text', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CoachIdleState(onSuggestionTap: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
    // One of the possible greeting texts appears
    final greetingFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data?.contains('morning') == true ||
              widget.data?.contains('afternoon') == true ||
              widget.data?.contains('evening') == true),
    );
    expect(greetingFinder, findsAtLeastNWidgets(1));
  });

  testWidgets('CoachIdleState calls onSuggestionTap with non-empty prompt', (tester) async {
    String? tappedPrompt;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CoachIdleState(onSuggestionTap: (p) => tappedPrompt = p),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(CoachSuggestionCard).first);
    expect(tappedPrompt, isNotNull);
    expect(tappedPrompt, isNotEmpty);
  });
}
