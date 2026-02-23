# Phase 1.1.4: Edge Agent Network Layer

**Parent Goal:** Phase 1.1 Foundation & Infrastructure
**Checklist:**
- [x] 1.1.1 Cloud Brain Repository Setup
- [x] 1.1.2 Database Setup
- [x] 1.1.3 Edge Agent Setup
- [ ] 1.1.4 Network Layer
- [ ] 1.1.5 Local Storage
- [ ] 1.1.6 UI Harness

---

## What
Implement a robust networking layer for the Edge Agent, including a REST API client using Dio and a WebSocket client for real-time communication. This includes request interception for adding authentication tokens.

## Why
The mobile app needs to communicate with the Cloud Brain for data synchronization and AI interaction. A centralized network layer ensures consistent error handling, timeout configuration, and authentication management.

## How
We will use:
- **Dio:** For HTTP requests (GET, POST).
- **Interceptors:** To automatically inject JWT tokens into headers.
- **WebSocketChannel:** For persistent, bi-directional communication (chat).

## Features
- **Auto-Authentication:** Requests automatically include the user's auth token.
- **Real-time Streaming:** WebSocket support for instant AI responses.
- **Timeouts & Error Handling:** Graceful failure management.

## Files
- Create: `zuralog/lib/core/network/api_client.dart`
- Create: `zuralog/lib/core/network/ws_client.dart`
- Create: `zuralog/lib/core/network/fcm_service.dart`

## Steps

1. **Create API client in `zuralog/lib/core/network/api_client.dart`**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  
  ApiClient({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage() {
    _dio.options.baseUrl = 'http://10.0.2.2:8000'; // Android emulator
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }
  
  Future<Response> get(String path) => _dio.get(path);
  Future<Response> post(String path, {dynamic data}) => _dio.post(path, data: data);
}
```

2. **Create WebSocket client in `zuralog/lib/core/network/ws_client.dart`**

```dart
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsClient {
  WebSocketChannel? _channel;
  final String _baseUrl;
  
  WsClient({String? baseUrl}) : _baseUrl = baseUrl ?? 'ws://10.0.2.2:8000';
  
  void connect(String token) {
    _channel = WebSocketChannel.connect(
      Uri.parse('$_baseUrl/ws/chat?token=$token'),
    );
  }
  
  Stream<dynamic> get stream => _channel!.stream;
  
  void send(String message) {
    _channel?.sink.add(jsonEncode({'message': message}));
  }
  
  void disconnect() {
    _channel?.sink.close();
  }
}
```

3. **Verify imports work**

```bash
cd zuralog
flutter analyze
```

## Exit Criteria
- No analysis errors.
- Network layer compiles.
