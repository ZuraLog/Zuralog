// zuralog/test/features/coach/presentation/widgets/coach_user_message_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_user_message.dart';

void main() {
  testWidgets('CoachUserMessage displays message text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoachUserMessage(
            content: 'How did I sleep last week?',
            onEdit: () {},
          ),
        ),
      ),
    );
    expect(find.text('How did I sleep last week?'), findsOneWidget);
  });

  testWidgets('CoachUserMessage is right-aligned (Row mainAxisAlignment.end)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoachUserMessage(
            content: 'Hello',
            onEdit: () {},
          ),
        ),
      ),
    );
    final row = tester.widget<Row>(find.byType(Row).first);
    expect(row.mainAxisAlignment, MainAxisAlignment.end);
  });

  testWidgets('CoachUserMessage shows long-press context menu with Copy and Edit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoachUserMessage(
            content: 'Hello',
            onEdit: () {},
          ),
        ),
      ),
    );
    await tester.longPress(find.text('Hello'));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });
}
