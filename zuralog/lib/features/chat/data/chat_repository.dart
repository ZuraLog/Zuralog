/// Zuralog Edge Agent — Chat Repository.
///
/// Mediates between the WebSocket client, REST API client, and the UI.
/// Provides typed streams for incoming messages and connection status,
/// and methods for sending messages and fetching history.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/monitoring/sentry_breadcrumbs.dart';
import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/core/network/ws_client.dart';
import 'package:zuralog/features/chat/domain/attachment.dart';
import 'package:zuralog/features/chat/domain/message.dart';

/// Repository that manages the chat data flow.
///
/// Wraps [WsClient] for real-time messaging and [ApiClient] for
/// REST operations like fetching conversation history. The UI
/// should interact with this repository rather than using the
/// clients directly.
class ChatRepository {
  /// The WebSocket client for real-time communication.
  final WsClient _wsClient;

  /// The REST API client for history retrieval.
  final ApiClient _apiClient;

  /// Creates a new [ChatRepository].
  ///
  /// [wsClient] handles WebSocket connections.
  /// [apiClient] handles REST API calls.
  ChatRepository({required WsClient wsClient, required ApiClient apiClient})
    : _wsClient = wsClient,
      _apiClient = apiClient;

  /// Stream of incoming chat messages from the WebSocket.
  ///
  /// Messages are parsed into [ChatMessage] objects. Each message
  /// from the Cloud Brain is transformed and forwarded.
  Stream<ChatMessage> get messages => _wsClient.messages.map((data) {
    return ChatMessage.fromJson(data);
  });

  /// Stream of connection status changes.
  ///
  /// Emits [ConnectionStatus] values as the WebSocket state changes.
  Stream<ConnectionStatus> get connectionStatus => _wsClient.statusStream;

  /// The current connection status.
  ConnectionStatus get currentStatus => _wsClient.status;

  /// Connects to the Cloud Brain WebSocket.
  ///
  /// [token] is the user's JWT auth token.
  void connect(String token) {
    SentryBreadcrumbs.apiRequest(
      method: 'CONNECT',
      path: 'ws://cloud-brain/chat',
    );
    _wsClient.connect(token);
  }

  /// Sends a chat message to the Cloud Brain.
  ///
  /// [text] is the message content to send.
  void sendMessage(String text) {
    SentryBreadcrumbs.aiMessageSent(
      messageLength: text.length,
      conversationId: 'active',
    );
    _wsClient.send(text);
  }

  /// Sends a chat message with file attachments to the Cloud Brain.
  ///
  /// [text] is the message content (may be empty for voice-only messages).
  /// [attachments] is the list of uploaded attachments to include.
  void sendMessageWithAttachments(
    String text,
    List<ChatAttachment> attachments,
  ) {
    _wsClient.sendJson({
      'message': text,
      'attachments': attachments.map((a) => a.toJson()).toList(),
    });
  }

  /// Fetches conversation history from the REST API.
  ///
  /// Returns a list of conversation maps with nested messages.
  /// Returns an empty list on error.
  Future<List<Object?>> fetchHistory() async {
    SentryBreadcrumbs.apiRequest(
      method: 'GET',
      path: '/api/v1/chat/history',
    );
    try {
      final response = await _apiClient.get('/api/v1/chat/history');
      return response.data as List<Object?>;
    } catch (e) {
      return [];
    }
  }

  /// Disconnects the WebSocket and releases resources.
  void dispose() {
    _wsClient.disconnect();
  }
}

/// Provides a singleton [ChatRepository] for chat operations.
///
/// Depends on [wsClientProvider] and [apiClientProvider] from the
/// core providers module.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final wsClient = ref.watch(wsClientProvider);
  final apiClient = ref.watch(apiClientProvider);
  return ChatRepository(wsClient: wsClient, apiClient: apiClient);
});
