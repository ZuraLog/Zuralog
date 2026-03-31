// zuralog/test/features/coach/presentation/widgets/coach_thinking_layer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_blob.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_thinking_layer.dart';

void main() {
  testWidgets('CoachThinkingLayer shows "Zura is thinking..." text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CoachThinkingLayer()),
      ),
    );
    expect(find.text('Zura is thinking...'), findsOneWidget);
  });

  testWidgets('CoachThinkingLayer starts collapsed (shows chevron_down icon)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CoachThinkingLayer()),
      ),
    );
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });

  testWidgets('CoachThinkingLayer expands on tap and shows steps', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoachThinkingLayer(
            steps: const ['Step one'],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CoachThinkingLayer));
    // Use pump instead of pumpAndSettle because CoachBlob uses a repeating
    // animation that never settles. A single frame pump is enough for the
    // synchronous setState expand toggle to take effect.
    await tester.pump();
    expect(find.text('Step one'), findsOneWidget);
  });
}
