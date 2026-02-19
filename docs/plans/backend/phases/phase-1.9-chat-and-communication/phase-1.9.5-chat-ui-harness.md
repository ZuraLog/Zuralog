# Phase 1.9.5: Chat UI in Harness

**Parent Goal:** Phase 1.9 Chat & Communication Layer
**Checklist:**
- [x] 1.9.1 WebSocket Endpoint
- [x] 1.9.2 Edge Agent WebSocket Client
- [x] 1.9.3 Message Persistence
- [x] 1.9.4 Edge Agent Chat Repository
- [ ] 1.9.5 Chat UI in Harness
- [ ] 1.9.6 Push Notifications (FCM)
- [ ] 1.9.7 Edge Agent FCM Setup

---

## What
Update the Developer Harness to use the real WebSocket repository instead of the mock one from Phase 1.8.

## Why
To verify that real-time streaming works end-to-end.

## How
Replace the HTTP-based "Send" button logic in `HarnessScreen` with `ChatRepository.sendMessage()`.

## Features
- **Real-time:** Messages appear instantly as they arrive from WS.

## Files
- Modify: `life_logger/lib/features/harness/harness_screen.dart`

## Steps

1. **Update harness (`life_logger/lib/features/harness/harness_screen.dart`)**

```dart
// inside _HarnessScreenState
@override
void initState() {
    super.initState();
    // Connect on load (mock token)
    ref.read(chatRepositoryProvider).connect("test_token");
}

@override
Widget build(BuildContext context) {
    final chatRepo = ref.read(chatRepositoryProvider);
    
    return Column(children: [
        // ... Log output ...
        Expanded(
            child: StreamBuilder(
                stream: chatRepo.messages,
                builder: (context, snapshot) {
                    if (snapshot.hasData) {
                         // Add to local list of messages to display
                         // _messages.add(snapshot.data.toString());
                    }
                    return ListView.builder(
                        itemCount: _messages.length,
                        itemBuilder: (c, i) => Text(_messages[i]),
                    );
                }
            )
        ),
        // ... Input ...
    ]);
}
```

## Exit Criteria
- Harness displays incoming messages from WebSocket.
