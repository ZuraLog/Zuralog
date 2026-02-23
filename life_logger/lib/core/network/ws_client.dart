/// Life Logger Edge Agent — WebSocket Client.
///
/// Provides a persistent, bi-directional WebSocket connection to
/// the Cloud Brain for real-time AI chat streaming. Includes automatic
/// reconnection with exponential backoff and connection status tracking.
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Connection status for the WebSocket client.
enum ConnectionStatus {
  /// Not connected and not attempting to connect.
  disconnected,

  /// Attempting to establish or re-establish a connection.
  connecting,

  /// Successfully connected and ready to send/receive.
  connected,
}

/// WebSocket client for real-time Cloud Brain communication.
///
/// Used primarily for streaming AI chat responses. The connection
/// is authenticated via a token passed as a query parameter.
///
/// Features:
/// - Broadcast stream for multiple listeners
/// - Automatic reconnection with exponential backoff
/// - Connection status tracking via [statusStream]
class WsClient {
  /// The active WebSocket channel, if connected.
  WebSocketChannel? _channel;

  /// Subscription to the active channel's stream.
  StreamSubscription<dynamic>? _channelSubscription;

  /// The base WebSocket URL for the Cloud Brain.
  final String _baseUrl;

  /// The auth token for the current connection.
  String? _token;

  /// Whether auto-reconnect is enabled.
  bool _shouldReconnect = false;

  /// Current reconnect delay in seconds (exponential backoff).
  int _reconnectDelay = 1;

  /// Current retry attempt count.
  int _retryCount = 0;

  /// Maximum reconnect delay in seconds.
  static const int _maxReconnectDelay = 30;

  /// Maximum number of reconnect attempts before giving up.
  static const int _maxRetries = 5;

  /// Broadcast controller for incoming messages.
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Controller for connection status changes.
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();

  /// The current connection status.
  ConnectionStatus _status = ConnectionStatus.disconnected;

  /// Creates a new [WsClient].
  ///
  /// The WebSocket URL is derived from the shared `BASE_URL` env var
  /// (same one used by [ApiClient]), converting `http(s)` to `ws(s)`.
  /// Override per-instance via [baseUrl] for testing.
  WsClient({String? baseUrl}) : _baseUrl = baseUrl ?? _deriveWsUrl();

  /// Derives the WebSocket URL from the shared `BASE_URL` env var.
  static String _deriveWsUrl() {
    const httpUrl = String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'http://10.0.2.2:8001',
    );
    return httpUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
  }

  /// The incoming message stream from the Cloud Brain.
  ///
  /// Messages are parsed JSON maps. Multiple listeners can subscribe
  /// to this broadcast stream.
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Stream of connection status changes.
  ///
  /// Emits [ConnectionStatus] values as the connection state changes.
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  /// The current connection status.
  ConnectionStatus get status => _status;

  /// Opens a WebSocket connection to the Cloud Brain chat endpoint.
  ///
  /// [token] is the user's JWT auth token for authentication.
  /// Enables automatic reconnection on disconnect.
  void connect(String token) {
    _token = token;
    _shouldReconnect = true;
    _reconnectDelay = 1;
    _retryCount = 0;
    _doConnect();
  }

  /// Internal connection method. Called by [connect] and the reconnect logic.
  void _doConnect() {
    if (_token == null) return;

    _setStatus(ConnectionStatus.connecting);

    try {
      final uri = Uri.parse('$_baseUrl/api/v1/chat/ws?token=$_token');
      _channel = WebSocketChannel.connect(uri);

      _channelSubscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _setStatus(ConnectionStatus.connected);
      _reconnectDelay = 1;
      _retryCount = 0; // Reset on successful connect
    } catch (e) {
      _setStatus(ConnectionStatus.disconnected);
      _scheduleReconnect();
    }
  }

  /// Handles an incoming WebSocket message.
  ///
  /// Parses the JSON string into a map and forwards it to listeners.
  void _onMessage(dynamic rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage as String) as Map<String, dynamic>;
      _messageController.add(decoded);
    } catch (e) {
      // Non-JSON message — wrap it
      _messageController.add({'type': 'raw', 'content': rawMessage.toString()});
    }
  }

  /// Handles WebSocket errors.
  void _onError(Object error) {
    _setStatus(ConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  /// Handles WebSocket close events.
  void _onDone() {
    _setStatus(ConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  /// Schedules a reconnection attempt with exponential backoff.
  ///
  /// Gives up after [_maxRetries] consecutive failures.
  void _scheduleReconnect() {
    if (!_shouldReconnect) return;

    _retryCount++;
    if (_retryCount > _maxRetries) {
      _shouldReconnect = false;
      _setStatus(ConnectionStatus.disconnected);
      return;
    }

    Future<void>.delayed(Duration(seconds: _reconnectDelay), () {
      if (_shouldReconnect) {
        _doConnect();
      }
    });

    // Exponential backoff: 1s → 2s → 4s → 8s → ... → 30s max
    _reconnectDelay = (_reconnectDelay * 2).clamp(1, _maxReconnectDelay);
  }

  /// Updates the connection status and notifies listeners.
  void _setStatus(ConnectionStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    _statusController.add(newStatus);
  }

  /// Sends a chat [message] to the Cloud Brain.
  ///
  /// The message is JSON-encoded before sending.
  /// Does nothing if not connected.
  void send(String message) {
    if (_channel == null || _status != ConnectionStatus.connected) return;
    _channel?.sink.add(jsonEncode({'message': message}));
  }

  /// Closes the WebSocket connection gracefully.
  ///
  /// Disables auto-reconnect and releases resources.
  void disconnect() {
    _shouldReconnect = false;
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel?.sink.close();
    _channel = null;
    _setStatus(ConnectionStatus.disconnected);
  }

  /// Releases all resources held by this client.
  ///
  /// Call this when the client is no longer needed (e.g., on app dispose).
  void dispose() {
    disconnect();
    _messageController.close();
    _statusController.close();
  }
}
