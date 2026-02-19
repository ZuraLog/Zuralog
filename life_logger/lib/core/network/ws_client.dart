/// Life Logger Edge Agent — WebSocket Client.
///
/// Provides a persistent, bi-directional WebSocket connection to
/// the Cloud Brain for real-time AI chat streaming.
library;

import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket client for real-time Cloud Brain communication.
///
/// Used primarily for streaming AI chat responses. The connection
/// is authenticated via a token passed as a query parameter.
class WsClient {
  /// The active WebSocket channel, if connected.
  WebSocketChannel? _channel;

  /// The base WebSocket URL for the Cloud Brain.
  final String _baseUrl;

  /// Creates a new [WsClient].
  ///
  /// [baseUrl] defaults to the Android emulator localhost alias.
  /// Override for production via `--dart-define=WS_URL=...`.
  WsClient({String? baseUrl})
    : _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'WS_URL',
            defaultValue: 'ws://10.0.2.2:8000',
          );

  /// Opens a WebSocket connection to the Cloud Brain chat endpoint.
  ///
  /// [token] is the user's JWT auth token for authentication.
  void connect(String token) {
    _channel = WebSocketChannel.connect(
      Uri.parse('$_baseUrl/ws/chat?token=$token'),
    );
  }

  /// The incoming message stream from the Cloud Brain.
  ///
  /// Throws if [connect] has not been called.
  Stream<dynamic> get stream => _channel!.stream;

  /// Sends a chat [message] to the Cloud Brain.
  ///
  /// The message is JSON-encoded before sending.
  void send(String message) {
    _channel?.sink.add(jsonEncode({'message': message}));
  }

  /// Closes the WebSocket connection gracefully.
  void disconnect() {
    _channel?.sink.close();
  }
}
