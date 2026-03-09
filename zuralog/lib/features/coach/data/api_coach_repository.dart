/// Zuralog — API Coach Repository.
///
/// Production implementation of [CoachRepository] that communicates
/// with the Cloud Brain backend via:
///   - REST (ApiClient / Dio) for conversation CRUD, message history,
///     prompt suggestions, and quick actions.
///   - WebSocket (web_socket_channel) for real-time AI streaming per
///     conversation.
///
/// Auth tokens are read from [SecureStorage] before each WebSocket
/// connection because WS connections bypass the Dio interceptor chain.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/core/storage/secure_storage.dart';
import 'package:zuralog/features/coach/data/coach_repository.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';

// ── Icon name → Material code point mapping ───────────────────────────────────

/// Maps Material icon name strings (as returned by the backend) to their
/// corresponding code points for use with [IconData].
///
/// The backend returns string names (e.g. ``"bedtime"``); the Flutter
/// [QuickAction] model stores int code points. Unknown names fall back to
/// [_kDefaultIcon].
const _kDefaultIcon = 0xe8b6; // Icons.help_outline_rounded

const Map<String, int> _kIconMap = {
  'wb_sunny': 0xe430,
  'bedtime': 0xe3ab,
  'nights_stay': 0xf1b1,
  'hotel': 0xe3a5,
  'flag': 0xe153,
  'water_drop': 0xf09e,
  'sentiment_satisfied': 0xe24d,
  'sentiment_very_satisfied': 0xe24e,
  'directions_run': 0xe0a8,
  'fitness_center': 0xe3b2,
  'track_changes': 0xe3a3,
  'restaurant': 0xe56c,
  'calendar_today': 0xe0a7,
  'insights': 0xf09c,
  'emoji_events': 0xea23,
  'summarize': 0xf071,
  'help_outline': 0xe8b6,
  'mood': 0xe5c8,
  'check_circle': 0xe5d0,
  'edit_note': 0xf0e7,
  'monitor_heart': 0xf5c7,
  'self_improvement': 0xea78,
  'local_fire_department': 0xef55,
  'bar_chart': 0xe0b6,
  'trending_up': 0xe3f8,
  'timer': 0xe425,
  'psychology': 0xea4a,
  'medication': 0xf8ff,
  'scale': 0xf065,
};

int _resolveIcon(String? iconName) {
  if (iconName == null) return _kDefaultIcon;
  return _kIconMap[iconName] ?? _kDefaultIcon;
}

// ── ApiCoachRepository ────────────────────────────────────────────────────────

/// Production [CoachRepository] backed by the Cloud Brain API.
final class ApiCoachRepository implements CoachRepository {
  /// Creates an [ApiCoachRepository].
  ///
  /// [apiClient] handles authenticated REST calls (JWT injected by Dio
  /// interceptor, auto-refresh on 401).
  /// [secureStorage] is used to read the JWT for WebSocket connections
  /// (which bypass the Dio interceptor chain).
  /// [wsBaseUrl] can be overridden for tests; defaults to the env-derived URL.
  ApiCoachRepository({
    required ApiClient apiClient,
    required SecureStorage secureStorage,
    String? wsBaseUrl,
  })  : _apiClient = apiClient,
        _secureStorage = secureStorage,
        _wsBaseUrl = wsBaseUrl ?? _deriveWsUrl();

  final ApiClient _apiClient;
  final SecureStorage _secureStorage;
  final String _wsBaseUrl;

  static String _deriveWsUrl() {
    const String envUrl = String.fromEnvironment('BASE_URL', defaultValue: '');
    final String httpUrl = envUrl.isNotEmpty
        ? envUrl
        : Platform.isIOS
            ? 'http://127.0.0.1:8001'
            : 'http://10.0.2.2:8001';
    return httpUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
  }

  // ── listConversations ──────────────────────────────────────────────────────

  @override
  Future<List<Conversation>> listConversations() async {
    final response = await _apiClient.get('/api/v1/chat/conversations');
    final List<dynamic> raw = response.data as List<dynamic>;
    return raw.map(_parseConversation).toList();
  }

  Conversation _parseConversation(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    return Conversation(
      id: m['id'] as String,
      title: (m['title'] as String?) ?? 'Untitled',
      createdAt: _parseDate(m['created_at']),
      updatedAt: _parseDate(m['updated_at'] ?? m['created_at']),
      preview: m['preview_snippet'] as String?,
      messageCount: (m['message_count'] as int?) ?? 0,
      isArchived: (m['archived'] as bool?) ?? false,
    );
  }

  // ── listMessages ───────────────────────────────────────────────────────────

  @override
  Future<List<ChatMessage>> listMessages(String conversationId) async {
    final response = await _apiClient.get(
      '/api/v1/chat/conversations/$conversationId/messages',
    );
    final List<dynamic> raw = response.data as List<dynamic>;
    return raw.map((m) => _parseMessage(m as Map<String, dynamic>, conversationId)).toList();
  }

  ChatMessage _parseMessage(Map<String, dynamic> m, String conversationId) {
    final roleStr = m['role'] as String? ?? 'assistant';
    final role = switch (roleStr) {
      'user' => MessageRole.user,
      'system' => MessageRole.system,
      _ => MessageRole.assistant,
    };

    // Extract signed URLs from the attachments JSONB array.
    final List<dynamic>? rawAttachments = m['attachments'] as List<dynamic>?;
    final List<String> attachmentUrls = rawAttachments
            ?.map((a) {
              final att = a as Map<String, dynamic>;
              return (att['signed_url'] ?? att['storage_path'] ?? '') as String;
            })
            .where((url) => url.isNotEmpty)
            .toList() ??
        [];

    return ChatMessage(
      id: m['id'] as String,
      conversationId: conversationId,
      role: role,
      content: m['content'] as String? ?? '',
      createdAt: _parseDate(m['created_at']),
      attachmentUrls: attachmentUrls,
    );
  }

  // ── fetchPromptSuggestions ────────────────────────────────────────────────

  @override
  Future<List<PromptSuggestion>> fetchPromptSuggestions() async {
    final response = await _apiClient.get('/api/v1/prompts/suggestions');
    final data = response.data as Map<String, dynamic>;
    final List<dynamic> raw = data['suggestions'] as List<dynamic>? ?? [];
    return raw.map((s) {
      final m = s as Map<String, dynamic>;
      return PromptSuggestion(
        id: m['id'] as String? ?? m['text'].toString().hashCode.toString(),
        text: m['text'] as String? ?? '',
        category: m['category'] as String?,
      );
    }).toList();
  }

  // ── fetchQuickActions ─────────────────────────────────────────────────────

  @override
  Future<List<QuickAction>> fetchQuickActions() async {
    final response = await _apiClient.get('/api/v1/quick-actions');
    final data = response.data as Map<String, dynamic>;
    final List<dynamic> raw = data['actions'] as List<dynamic>? ?? [];
    return raw.map((a) {
      final m = a as Map<String, dynamic>;
      return QuickAction(
        id: m['id'] as String,
        title: m['title'] as String,
        subtitle: m['subtitle'] as String? ?? '',
        icon: _resolveIcon(m['icon'] as String?),
        prompt: m['prompt'] as String? ?? '',
      );
    }).toList();
  }

  // ── deleteConversation ────────────────────────────────────────────────────

  @override
  Future<void> deleteConversation(String conversationId) async {
    await _apiClient.delete('/api/v1/chat/conversations/$conversationId');
  }

  // ── archiveConversation ───────────────────────────────────────────────────

  @override
  Future<void> archiveConversation(String conversationId) async {
    await _apiClient.patch(
      '/api/v1/chat/conversations/$conversationId',
      body: {'archived': true},
    );
  }

  // ── renameConversation ────────────────────────────────────────────────────

  @override
  Future<void> renameConversation(String conversationId, String newTitle) async {
    await _apiClient.patch(
      '/api/v1/chat/conversations/$conversationId',
      body: {'title': newTitle},
    );
  }

  // ── sendMessageStream ─────────────────────────────────────────────────────

  @override
  Stream<ChatStreamEvent> sendMessageStream({
    required String? conversationId,
    required String text,
    required String persona,
    required String proactivity,
    required String responseLength,
    List<Map<String, dynamic>> attachments = const [],
    bool isRegenerate = false,
  }) {
    // Using a StreamController so we can handle async WS setup cleanly.
    // The cancelCompleter is completed when the consumer cancels, which
    // unblocks _runWebSocketStream so it can close the WebSocket promptly.
    final cancelCompleter = Completer<void>();
    final controller = StreamController<ChatStreamEvent>(
      onCancel: () {
        if (!cancelCompleter.isCompleted) cancelCompleter.complete();
      },
    );
    _runWebSocketStream(
      controller: controller,
      cancelCompleter: cancelCompleter,
      conversationId: conversationId,
      text: text,
      persona: persona,
      proactivity: proactivity,
      attachments: attachments,
      isRegenerate: isRegenerate,
    );
    return controller.stream;
  }

  Future<void> _runWebSocketStream({
    required StreamController<ChatStreamEvent> controller,
    required Completer<void> cancelCompleter,
    required String? conversationId,
    required String text,
    required String persona,
    required String proactivity,
    required List<Map<String, dynamic>> attachments,
    bool isRegenerate = false,
  }) async {
    WebSocketChannel? channel;
    StreamSubscription<dynamic>? subscription;

    try {
      // Read a fresh JWT — WS connections bypass the Dio interceptor chain.
      final token = await _secureStorage.getAuthToken();
      if (token == null) {
        controller.addError(StreamError('No auth token available'));
        await controller.close();
        return;
      }

      // Build the WS URL.
      final convParam =
          conversationId != null ? '&conversation_id=$conversationId' : '';
      final uri = Uri.parse(
        '$_wsBaseUrl/api/v1/chat/ws?token=$token$convParam',
      );

      channel = WebSocketChannel.connect(uri);

      String? resolvedConversationId = conversationId;
      bool messageSent = false;
      String accumulated = '';
      String? finalConversationId;

      final wsCompleter = Completer<void>();

      subscription = channel.stream.listen(
        (rawMessage) {
          if (controller.isClosed) return;
          try {
            final Map<String, dynamic> msg =
                jsonDecode(rawMessage as String) as Map<String, dynamic>;
            final type = msg['type'] as String?;

            switch (type) {
              case 'conversation_init':
                // Server assigned a UUID (always sent, even for existing convs).
                resolvedConversationId = msg['conversation_id'] as String?;
                finalConversationId = resolvedConversationId;

                // If conversationId was null, this is a new conversation.
                if (conversationId == null && resolvedConversationId != null) {
                  controller.add(ConversationCreated(resolvedConversationId!));
                }

                // Send the user message immediately after receiving the init.
                if (!messageSent) {
                  messageSent = true;
                  final payload = <String, dynamic>{
                    'message': text,
                    'persona': persona,
                    'proactivity': proactivity,
                    if (attachments.isNotEmpty) 'attachments': attachments,
                    if (isRegenerate) 'regenerate': true,
                  };
                  channel?.sink.add(jsonEncode(payload));
                }

              case 'typing_start':
                // Acknowledged — no event emitted to UI (typing indicator is
                // shown by the UI when isSending is true).
                break;

              case 'tool_start':
                controller.add(ToolProgress(
                  toolName: msg['tool_name'] as String? ?? 'tool',
                  isStart: true,
                ));

              case 'tool_end':
                controller.add(ToolProgress(
                  toolName: msg['tool_name'] as String? ?? 'tool',
                  isStart: false,
                ));

              case 'stream_token':
                final delta = msg['content'] as String? ?? '';
                accumulated += delta;
                controller.add(StreamToken(
                  delta: delta,
                  accumulated: accumulated,
                ));

              case 'stream_end':
                final content = msg['content'] as String? ?? accumulated;
                final msgId = msg['message_id'] as String? ??
                    'msg_${DateTime.now().millisecondsSinceEpoch}';
                final convId = msg['conversation_id'] as String? ??
                    finalConversationId ??
                    resolvedConversationId ??
                    'unknown';

                final chatMsg = ChatMessage(
                  id: msgId,
                  conversationId: convId,
                  role: MessageRole.assistant,
                  content: content,
                  createdAt: DateTime.now(),
                );
                controller.add(StreamComplete(
                  message: chatMsg,
                  conversationId: convId,
                ));
                // Gracefully close after final message.
                channel?.sink.close();

              case 'error':
                final errContent = msg['content'] as String? ?? 'Unknown error';
                controller.add(StreamError(errContent));
                channel?.sink.close();

              default:
                // Unknown message type — ignore.
                break;
            }
          } catch (e) {
            controller.add(StreamError('Message parse error: $e'));
          }
        },
        onError: (Object error) {
          controller.add(StreamError('WebSocket error: $error'));
          if (!wsCompleter.isCompleted) wsCompleter.completeError(error);
        },
        onDone: () {
          if (!wsCompleter.isCompleted) wsCompleter.complete();
        },
        cancelOnError: false,
      );

      // Wait for either the WebSocket to finish naturally or the consumer to
      // cancel (via cancelCompleter). Whichever fires first unblocks us, and
      // the finally block closes the channel and the controller.
      await Future.any([wsCompleter.future, cancelCompleter.future]);
    } catch (e) {
      controller.add(StreamError('Connection error: $e'));
    } finally {
      await subscription?.cancel();
      await channel?.sink.close();
      await controller.close();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    try {
      return DateTime.parse(raw as String).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }
}
