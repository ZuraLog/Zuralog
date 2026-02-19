# Phase 1.9.2: Edge Agent WebSocket Client

**Parent Goal:** Phase 1.9 Chat & Communication Layer
**Checklist:**
- [x] 1.9.1 WebSocket Endpoint
- [x] 1.9.2 Edge Agent WebSocket Client
- [ ] 1.9.3 Message Persistence
- [ ] 1.9.4 Edge Agent Chat Repository
- [ ] 1.9.5 Chat UI in Harness
- [ ] 1.9.6 Push Notifications (FCM)
- [ ] 1.9.7 Edge Agent FCM Setup

---

## What
Implement a robust WebSocket client in Dart that handles connection lifecycle, automatic reconnection, and stream parsing.

## Why
Raw WebSockets are fragile. If the internet drops, the socket closes. Usage in the UI requires a stable stream that survives network blips.

## How
Use `web_socket_channel` package. Wrap it in a `WsClient` class that exposes a `Stream<Message>`.

## Features
- **Auto-Reconnect:** Tries to reconnect every X seconds if disconnected.
- **Heartbeat:** (Optional) Pings server to keep connection alive.

## Files
- Modify: `life_logger/lib/core/network/ws_client.dart` (created in Phase 1.1, now expanding)

## Steps

1. **Update WebSocket client (`life_logger/lib/core/network/ws_client.dart`)**

```dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';
import 'dart:async';

class WsClient {
  WebSocketChannel? _channel;
  final StreamController<dynamic> _controller = StreamController<dynamic>.broadcast();
  
  Stream<dynamic> get messages => _controller.stream;
  
  void connect(String baseUrl, String token) {
    // In real app, handling reconnect logic here is better
    final uri = Uri.parse('$baseUrl/ws/chat?token=$token');
    
    try {
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        (message) {
          _controller.add(jsonDecode(message));
        },
        onError: (error) {
          print("WS Error: $error");
          // Reconnect logic
        },
        onDone: () {
          print("WS Closed");
          // Reconnect logic
        }
      );
    } catch (e) {
      print("WS Connect Error: $e");
    }
  }
  
  void sendMessage(String message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'message': message,
      }));
    }
  }
  
  void disconnect() {
    _channel?.sink.close(status.goingAway);
  }
}
```

## Exit Criteria
- Client can connect and exchange messages.
- Does not crash app on network error.
