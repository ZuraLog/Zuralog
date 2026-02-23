# Phase 1.8.7: Test Harness: AI Chat

**Parent Goal:** Phase 1.8 The AI Brain (Reasoning Engine)
**Checklist:**
- [x] 1.8.1 LLM Client Setup
- [x] 1.8.2 Agent System Prompt
- [x] 1.8.3 Tool Selection Logic
- [x] 1.8.4 Cross-App Reasoning Engine
- [x] 1.8.5 Voice Input
- [x] 1.8.6 User Profile & Preferences
- [ ] 1.8.7 Test Harness: AI Chat
- [ ] 1.8.8 Kimi Integration Document
- [ ] 1.8.9 Rate Limiter Service
- [ ] 1.8.10 Usage Tracker Service
- [ ] 1.8.11 Rate Limiter Middleware

---

## What
Add a simple chat interface to the Developer UI Harness so we can talk to the AI without building the full frontend chat screen yet.

## Why
We need to verify the "Brain" works (LLM + Tools + System Prompt) in an isolated environment before dealing with complex UI state management.

## How
Add a `TextField` and a `ListView` of messages to `HarnessScreen`.

## Features
- **Debug Output:** Show raw JSON of tool calls (optional to toggle).
- **Voice Test:** Button to upload a sample audio file.

## Files
- Modify: `zuralog/lib/features/harness/harness_screen.dart`

## Steps

1. **Add AI chat test to harness (`zuralog/lib/features/harness/harness_screen.dart`)**

```dart
// Basic Chat UI in Harness
Column(
  children: [
    Expanded(
      child: ListView.builder(
        itemCount: _messages.length,
        itemBuilder: (context, index) => Text(_messages[index]),
      ),
    ),
    Row(
      children: [
        Expanded(child: TextField(controller: _chatInputController)),
        IconButton(
          icon: Icon(Icons.send),
          onPressed: () {
            // Send to API
            _sendMessage(_chatInputController.text);
          },
        ),
        IconButton(
          icon: Icon(Icons.mic),
          onPressed: () {
             // Mock voice upload
             _uploadMockAudio();
          },
        )
      ],
    )
  ],
)
```

## Exit Criteria
- Can send "How are my steps?" and get a real response from Kimi (via the backend).
