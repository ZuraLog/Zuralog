# Phase 1.9.4: Edge Agent Chat Repository

**Parent Goal:** Phase 1.9 Chat & Communication Layer
**Checklist:**
- [x] 1.9.1 WebSocket Endpoint
- [x] 1.9.2 Edge Agent WebSocket Client
- [x] 1.9.3 Message Persistence
- [ ] 1.9.4 Edge Agent Chat Repository
- [ ] 1.9.5 Chat UI in Harness
- [ ] 1.9.6 Push Notifications (FCM)
- [ ] 1.9.7 Edge Agent FCM Setup

---

## What
Implement the repository layer that manages chat data flow in the Flutter app. It mediates between the WebSocket client, local storage (for offline caching), and the UI.

## Why
The UI shouldn't talk to `WsClient` directly. We need a repository to handle state related to "connecting," "sending," "optimistic updates," and "error handling."

## How
Create `ChatRepository` class using Riverpod.

## Features
- **Optimistic UI:** Adds message to local list immediately before network confirms. (Future)
- **Status Stream:** Exposes connection status (Connected/Connecting/Offline).

## Files
- Create: `zuralog/lib/features/chat/data/chat_repository.dart`
- Modify: `zuralog/lib/features/chat/domain/message.dart` (Model)

## Steps

1. **Create chat repository (`zuralog/lib/features/chat/data/chat_repository.dart`)**

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/ws_client.dart';

class ChatRepository {
  final WsClient _wsClient;
  final ApiClient _apiClient;
  
  ChatRepository({
    required WsClient wsClient,
    required ApiClient apiClient,
  }) : _wsClient = wsClient, _apiClient = apiClient;
  
  void connect(String token) {
    // In real app, get baseUrl from config/env
    _wsClient.connect("ws://10.0.2.2:8000", token);
  }
  
  Stream<dynamic> get messages => _wsClient.messages;
  
  Future<void> sendMessage(String text) async {
    _wsClient.sendMessage(text);
  }
  
  Future<List<dynamic>> fetchHistory() async {
    // Determine last sync time, fetch from API
    // return _apiClient.get('/chat/history');
    return [];
  }
  
  void dispose() {
    _wsClient.disconnect();
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  // Mock token retrieval
  return ChatRepository(
    wsClient: WsClient(), 
    apiClient: ref.read(apiClientProvider),
  );
});
```

## Exit Criteria
- Repository compiles.
- Can be watched by Riverpod.
