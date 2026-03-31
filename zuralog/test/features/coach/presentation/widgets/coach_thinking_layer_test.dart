// zuralog/test/features/coach/presentation/widgets/coach_thinking_layer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_thinking_layer.dart';

void main() {
  testWidgets('CoachThinkingLayer shows default "Thinking…" text when no content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CoachThinkingLayer()),
      ),
    );
    expect(find.text('Thinking…'), findsOneWidget);
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
}
