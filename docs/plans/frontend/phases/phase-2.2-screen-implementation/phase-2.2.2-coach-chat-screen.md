# Phase 2.2.2: Coach Chat Screen

**Parent Goal:** Phase 2.2 Screen Implementation (Wiring)
**Checklist:**
- [x] 2.2.1 Welcome & Auth Screen
- [x] 2.2.2 Coach Chat Screen
- [ ] 2.2.3 Dashboard Screen
- [ ] 2.2.4 Integrations Hub Screen
- [ ] 2.2.5 Settings Screen

---

## What
The main interface for interacting with the AI Brain. A WhatsApp-style chat interface.

## Why
The core value prop is the "Relationship" with the AI.

## How
Use `ListView.builder` with `MessageBubble` widgets. Connect to `ChatRepository` streams.

## Features
- **Real-time:** Messages appear instantly via WebSocket.
- **Typing Indicators:** Show when the AI is "thinking".
- **Markdown Support:** Render AI responses with bold/italic/lists using `flutter_markdown`.
- **Tool UI:** If AI triggers a "Deep Link", show a distinct UI card ("Open Strava" button) inside the chat stream.

## Files
- Create: `zuralog/lib/features/chat/presentation/chat_screen.dart`
- Create: `zuralog/lib/features/chat/presentation/widgets/message_bubble.dart`
- Create: `zuralog/lib/features/chat/presentation/widgets/chat_input_bar.dart`

## Steps

1. **Create Chat Screen (`zuralog/lib/features/chat/presentation/chat_screen.dart`)**

```dart
class ChatScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatMessagesProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text("Life Coach")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // Start from bottom
              itemCount: messages.length,
              itemBuilder: (context, index) => MessageBubble(message: messages[index]),
            ),
          ),
          ChatInputBar(
            onSend: (text) => ref.read(chatRepositoryProvider).sendMessage(text),
          ),
        ],
      ),
    );
  }
}
```

2. **Handle Special Messages**
   - In `MessageBubble`, check `message.metadata['client_action']`.
   - If present, render `DeepLinkCard` instead of text.

## Exit Criteria
- Can send message.
- Can receive echo/AI response.
- Chat history persists (via Repository).
