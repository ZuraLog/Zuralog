// zuralog/test/features/coach/presentation/widgets/coach_ai_response_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_ai_response.dart';

void main() {
  testWidgets('CoachAiResponse renders content text', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CoachAiResponse(
              content: 'You slept 7.5 hours last night.',
              isStreaming: false,
              isThinking: false,
              onCopy: () {},
              onThumbUp: () {},
              onThumbDown: () {},
              onRedo: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('7.5 hours'), findsOneWidget);
  });

  testWidgets('CoachAiResponse shows thinking layer when isThinking is true', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CoachAiResponse(
              content: '',
              isStreaming: true,
              isThinking: true,
              onCopy: () {},
              onThumbUp: () {},
              onThumbDown: () {},
              onRedo: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Zura is thinking...'), findsOneWidget);
  });

  testWidgets('CoachAiResponse hides action row while streaming', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CoachAiResponse(
              content: 'Streaming...',
              isStreaming: true,
              isThinking: false,
              onCopy: () {},
              onThumbUp: () {},
              onThumbDown: () {},
              onRedo: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.thumb_up_outlined), findsNothing);
  });

  testWidgets('CoachAiResponse shows action row after stream ends', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CoachAiResponse(
              content: 'Complete response.',
              isStreaming: false,
              isThinking: false,
              onCopy: () {},
              onThumbUp: () {},
              onThumbDown: () {},
              onRedo: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
  });
}
