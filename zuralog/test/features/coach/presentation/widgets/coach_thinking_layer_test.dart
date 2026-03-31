// zuralog/test/features/coach/presentation/widgets/coach_thinking_layer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_thinking_layer.dart';

void main() {
  testWidgets('CoachThinkingLayer shows a rotating word label when no content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CoachThinkingLayer()),
      ),
    );
    // The label is a random word from the thinking-words list followed by "…".
    // We can't assert a specific word, so just verify some text ending with "…"
    // is present.
    expect(find.textContaining('…'), findsOneWidget);
  });

  testWidgets('CoachThinkingLayer shows tool name when activeToolName is set', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoachThinkingLayer(activeToolName: 'strava_get_activities'),
        ),
      ),
    );
    expect(find.text('Checking Strava…'), findsOneWidget);
  });

  testWidgets('CoachThinkingLayer shows thinking content when provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoachThinkingLayer(
            thinkingContent: 'Reasoning about step one',
          ),
        ),
      ),
    );
    // Use pump instead of pumpAndSettle because CoachBlob uses a repeating
    // animation that never settles. A single frame pump is enough to render.
    await tester.pump();
    expect(find.text('Reasoning about step one'), findsOneWidget);
  });

  testWidgets('CoachThinkingLayer shows only the last 120 chars of long thinking content',
      (tester) async {
    // Build a string longer than 120 characters (widget's truncation threshold).
    final prefix = 'A' * 50; // 50 chars that should be trimmed
    final tail = 'B' * 120; // 120 chars that should be shown
    final longContent = prefix + tail;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoachThinkingLayer(thinkingContent: longContent),
        ),
      ),
    );
    await tester.pump();

    // The full string must not appear.
    expect(find.text(longContent), findsNothing);
    // Only the tail (last 120 chars) should appear.
    expect(find.text(tail), findsOneWidget);
  });
}
