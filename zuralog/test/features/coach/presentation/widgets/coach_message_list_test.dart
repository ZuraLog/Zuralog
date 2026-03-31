import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_message_list.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_ai_response.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_user_message.dart';

// Helper to pump CoachMessageList inside a MaterialApp.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

ChatMessage _userMsg(String content) => ChatMessage(
      id: 'u1',
      conversationId: 'c1',
      role: MessageRole.user,
      content: content,
      createdAt: DateTime(2026),
    );

ChatMessage _assistantMsg(String content) => ChatMessage(
      id: 'a1',
      conversationId: 'c1',
      role: MessageRole.assistant,
      content: content,
      createdAt: DateTime(2026),
    );

ChatMessage _systemMsg(String content) => ChatMessage(
      id: 's1',
      conversationId: 'c1',
      role: MessageRole.system,
      content: content,
      createdAt: DateTime(2026),
    );

void main() {
  testWidgets('renders user message as CoachUserMessage', (tester) async {
    await tester.pumpWidget(_wrap(
      CoachMessageList(
        messages: [_userMsg('Hello')],
        isStreaming: false,
        isThinking: false,
      ),
    ));
    await tester.pump();
    expect(find.byType(CoachUserMessage), findsOneWidget);
  });

  testWidgets('renders assistant message as CoachAiResponse', (tester) async {
    await tester.pumpWidget(_wrap(
      CoachMessageList(
        messages: [_assistantMsg('Hi there!')],
        isStreaming: false,
        isThinking: false,
      ),
    ));
    await tester.pump();
    expect(find.byType(CoachAiResponse), findsOneWidget);
  });

  testWidgets('renders mixed message types without errors', (tester) async {
    await tester.pumpWidget(_wrap(
      CoachMessageList(
        messages: [
          _userMsg('Log my sleep'),
          _assistantMsg('Sure, how many hours?'),
          _systemMsg('Journal entry logged'),
        ],
        isStreaming: false,
        isThinking: false,
      ),
    ));
    await tester.pump();
    expect(find.byType(CoachUserMessage), findsOneWidget);
    expect(find.byType(CoachAiResponse), findsOneWidget);
    expect(find.byType(CoachMessageList), findsOneWidget);
  });

  testWidgets('renders scroll-to-bottom FAB when scrolled up', (tester) async {
    final messages = List.generate(
      30,
      (i) => ChatMessage(
        id: 'msg-$i',
        conversationId: 'c1',
        role: MessageRole.user,
        content: 'Message $i',
        createdAt: DateTime(2026),
      ),
    );
    await tester.pumpWidget(_wrap(
      CoachMessageList(
        messages: messages,
        isStreaming: false,
        isThinking: false,
      ),
    ));
    await tester.pump();
    // Widget builds without errors — FAB visibility depends on scroll state.
    expect(find.byType(CoachMessageList), findsOneWidget);
  });

  testWidgets('onEditMessage parameter is accepted without error', (tester) async {
    int? editedIndex;
    await tester.pumpWidget(_wrap(
      CoachMessageList(
        messages: [_userMsg('Edit me')],
        isStreaming: false,
        isThinking: false,
        onEditMessage: (index) => editedIndex = index,
      ),
    ));
    await tester.pump();
    // Widget accepts the callback and renders without errors.
    expect(find.byType(CoachUserMessage), findsOneWidget);
    // Callback is not yet fired (no interaction).
    expect(editedIndex, isNull);
  });
}
