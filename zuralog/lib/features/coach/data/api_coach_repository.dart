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
import 'dart:io' show Platform, SocketException;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/core/storage/secure_storage.dart';
import 'package:zuralog/features/coach/data/coach_repository.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';

// ── Icon name → Material code point mapping ───────────────────────────────────

/// Maps Material icon name strings (as returned by the backend) to their
/// corresponding [IconData] values.
///
/// The backend returns string names (e.g. ``"bedtime"``); the Flutter
/// [QuickAction] model stores [IconData]. Unknown names fall back to
/// [_kDefaultIcon].
///
/// Every value is a compile-time constant so Flutter can tree-shake unused
/// Material Icons glyphs during release builds.
const _kDefaultIcon = IconData(0xe8b6, fontFamily: 'MaterialIcons');

const Map<String, IconData> _kIconMap = {
  'wb_sunny': IconData(0xe430, fontFamily: 'MaterialIcons'),
  'bedtime': IconData(0xe3ab, fontFamily: 'MaterialIcons'),
  'nights_stay': IconData(0xf1b1, fontFamily: 'MaterialIcons'),
  'hotel': IconData(0xe3a5, fontFamily: 'MaterialIcons'),
  'flag': IconData(0xe153, fontFamily: 'MaterialIcons'),
  'water_drop': IconData(0xf09e, fontFamily: 'MaterialIcons'),
  'sentiment_satisfied': IconData(0xe24d, fontFamily: 'MaterialIcons'),
  'sentiment_very_satisfied': IconData(0xe24e, fontFamily: 'MaterialIcons'),
  'directions_run': IconData(0xe0a8, fontFamily: 'MaterialIcons'),
  'fitness_center': IconData(0xe3b2, fontFamily: 'MaterialIcons'),
  'track_changes': IconData(0xe3a3, fontFamily: 'MaterialIcons'),
  'restaurant': IconData(0xe56c, fontFamily: 'MaterialIcons'),
  'calendar_today': IconData(0xe0a7, fontFamily: 'MaterialIcons'),
  'insights': IconData(0xf09c, fontFamily: 'MaterialIcons'),
  'emoji_events': IconData(0xea23, fontFamily: 'MaterialIcons'),
  'summarize': IconData(0xf071, fontFamily: 'MaterialIcons'),
  'help_outline': IconData(0xe8b6, fontFamily: 'MaterialIcons'),
  'mood': IconData(0xe5c8, fontFamily: 'MaterialIcons'),
  'check_circle': IconData(0xe5d0, fontFamily: 'MaterialIcons'),
  'edit_note': IconData(0xf0e7, fontFamily: 'MaterialIcons'),
  'monitor_heart': IconData(0xf5c7, fontFamily: 'MaterialIcons'),
  'self_improvement': IconData(0xea78, fontFamily: 'MaterialIcons'),
  'local_fire_department': IconData(0xef55, fontFamily: 'MaterialIcons'),
  'bar_chart': IconData(0xe0b6, fontFamily: 'MaterialIcons'),
  'trending_up': IconData(0xe3f8, fontFamily: 'MaterialIcons'),
  'timer': IconData(0xe425, fontFamily: 'MaterialIcons'),
  'psychology': IconData(0xea4a, fontFamily: 'MaterialIcons'),
  'medication': IconData(0xf8ff, fontFamily: 'MaterialIcons'),
  'scale': IconData(0xf065, fontFamily: 'MaterialIcons'),
};

IconData _resolveIcon(String? iconName) {
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

  /// Tracks how many times we have re-attempted the WebSocket connection
  /// after receiving close code 4003 (token expired). Reset at the start
  /// of each new [sendMessageStream] call.
  int _wsReconnectAttempts = 0;

  /// Completer for the currently active WebSocket stream, used by
  /// [cancelActiveStream] to signal done without waiting for the WS to close.
  Completer<int?>? _activeDoneCompleter;

  /// The currently active WebSocket channel, used by [cancelActiveStream].
  WebSocketChannel? _activeChannel;

  /// Cancels any in-flight WebSocket stream immediately.
  ///
  /// Completes [_activeDoneCompleter] (so the awaiting [_runWebSocketStream]
  /// unblocks) and closes the channel sink. Safe to call when idle.
  @override
  Future<void> cancelActiveStream() async {
    _activeDoneCompleter?.complete(null);
    await _activeChannel?.sink.close();
    _activeDoneCompleter = null;
    _activeChannel = null;
  }

  static String _deriveWsUrl() {
    const String envUrl = String.fromEnvironment('BASE_URL', defaultValue: '');
    final String httpUrl = envUrl.isNotEmpty
        ? envUrl
        : Platform.isIOS
            ? 'http://127.0.0.1:8001'
            : 'http://10.0.2.2:8001';
    // Fix L2: if the URL is already a ws/wss scheme, use it as-is.
    final parsed = Uri.parse(httpUrl);
    if (parsed.scheme == 'ws' || parsed.scheme == 'wss') return httpUrl;
    // dart:io WebSocket.connect does not resolve default ports for wss:// or
    // ws://, producing port 0 and a failed connection. Parse as http(s) first
    // (which Dart resolves correctly to port 443/80), then rebuild with the
    // wss/ws scheme and the resolved port set explicitly.
    final wsScheme = parsed.scheme == 'https' ? 'wss' : 'ws';
    final wsPort = parsed.hasPort ? parsed.port : (wsScheme == 'wss' ? 443 : 80);
    return Uri(scheme: wsScheme, host: parsed.host, port: wsPort).toString();
  }

  // ── listConversations ──────────────────────────────────────────────────────

  @override
  Future<List<Conversation>> listConversations() async {
    final response = await _apiClient.get('/api/v1/chat/conversations');
    final rawData = response.data;
    if (rawData is! List) throw Exception('Unexpected server response format');
    final List<dynamic> raw = List<dynamic>.from(rawData);
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
    final rawData = response.data;
    if (rawData is! List) throw Exception('Unexpected server response format');
    final List<dynamic> raw = List<dynamic>.from(rawData);
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
    // Reset reconnect counter for each new message stream.
    _wsReconnectAttempts = 0;
    // Using a StreamController so we can handle async WS setup cleanly.
    final doneCompleter = Completer<int?>();
    final controller = StreamController<ChatStreamEvent>();
    _runWebSocketStream(
      controller: controller,
      doneCompleter: doneCompleter,
      conversationId: conversationId,
      text: text,
      persona: persona,
      proactivity: proactivity,
      responseLength: responseLength,
      attachments: attachments,
      isRegenerate: isRegenerate,
    );
    return controller.stream;
  }

  Future<void> _runWebSocketStream({
    required StreamController<ChatStreamEvent> controller,
    required Completer<int?> doneCompleter,
    required String? conversationId,
    required String text,
    required String persona,
    required String proactivity,
    required String responseLength,
    required List<Map<String, dynamic>> attachments,
    bool isRegenerate = false,
  }) async {
    // Fix 3: re-wire onCancel to this invocation's completer so cancellation
    // during a reconnect completes the active (not the original) completer.
    controller.onCancel = () {
      if (!doneCompleter.isCompleted) doneCompleter.complete(null);
    };

    WebSocketChannel? channel;
    StreamSubscription<dynamic>? subscription;
    // Fix C5: track whether the sink has already been closed.
    bool sinkClosed = false;
    // Tracks whether a 4003-triggered reconnect should happen after cleanup.
    bool reconnectAfter4003 = false;
    Timer? initTimer;

    try {
      // Read a fresh JWT — WS connections bypass the Dio interceptor chain.
      final token = await _secureStorage.getAuthToken();
      if (token == null) {
        if (!controller.isClosed) controller.add(const StreamError('No auth token available'));
        if (!doneCompleter.isCompleted) doneCompleter.complete(null);
        await controller.close();
        return;
      }

      // Build the WS URI. Conversation ID may be passed as a query param for
      // server-side routing before the auth message is processed.
      // Fix C3: JWT is NOT included in the URL query params — it is sent as
      // the first message after connecting.
      final queryParams = <String, String>{
        'conversation_id': ?conversationId,
      };
      final uri = Uri.parse(_wsBaseUrl).replace(
        path: '/api/v1/chat/ws',
        queryParameters: queryParams,
      );

      channel = WebSocketChannel.connect(uri);

      // Track active channel and completer so cancelActiveStream() can abort.
      _activeChannel = channel;
      _activeDoneCompleter = doneCompleter;

      // Fix C3: send token as the first message so it is not exposed in the URL.
      // NOTE: Backend must accept token from first WS message, not query param.
      channel.sink.add(jsonEncode({'type': 'auth', 'token': token}));

      String? resolvedConversationId = conversationId;
      bool messageSent = false;
      String accumulated = '';

      // Fix H5: track when conversation_init is received.
      final initCompleter = Completer<void>();

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

                // Fix H5: signal that init was received.
                if (!initCompleter.isCompleted) {
                  initCompleter.complete();
                  initTimer?.cancel();
                }

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
                    'response_length': responseLength,
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
                final rawMsgId = msg['message_id'] as String?;
                final msgId = (rawMsgId == null || rawMsgId.isEmpty)
                    ? 'msg_${DateTime.now().millisecondsSinceEpoch}'
                    : rawMsgId;
                // Fix M6: reject stream_end with no conversation ID.
                final convId = msg['conversation_id'] as String? ?? resolvedConversationId;
                if (convId == null) {
                  if (!controller.isClosed) {
                    controller.add(const StreamError('Server did not return conversation ID'));
                  }
                  if (!sinkClosed) {
                    sinkClosed = true;
                    channel?.sink.close();
                  }
                  return;
                }

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
                // Fix C5: guarded close.
                if (!sinkClosed) {
                  sinkClosed = true;
                  channel?.sink.close();
                }

              case 'error':
                final errContent = msg['content'] as String? ?? 'Unknown error';
                controller.add(StreamError(errContent));
                if (!sinkClosed) {
                  sinkClosed = true;
                  channel?.sink.close();
                }

              case 'rate_limit':
                final msg2 = msg['content'] as String? ?? 'Rate limit reached. Please try again later.';
                controller.add(StreamError(msg2));
                if (!sinkClosed) {
                  sinkClosed = true;
                  channel?.sink.close();
                }

              default:
                // Unknown message type — ignore.
                break;
            }
          } catch (_) {
            controller.add(const StreamError('Something went wrong. Please try again.'));
          }
        },
        onError: (Object error, StackTrace stackTrace) async {
          String errorMessage;
          if (error is SocketException || error is WebSocketChannelException) {
            final connectivity = await Connectivity().checkConnectivity();
            final hasInterface = !connectivity.contains(ConnectivityResult.none);
            errorMessage = hasInterface
                ? "Connected to network but can't reach the server. "
                  "If using public WiFi, a login screen may be required."
                : 'No internet connection. Please check your network.';
          } else {
            errorMessage = 'Something went wrong. Please try again.';
          }
          if (!controller.isClosed) controller.add(StreamError(errorMessage));
          await subscription?.cancel();
          if (!sinkClosed) {
            sinkClosed = true;
            channel?.sink.close();
          }
          // Fix C4: complete the single doneCompleter.
          if (!doneCompleter.isCompleted) doneCompleter.complete(null);
        },
        onDone: () {
          // Fix 1: capture closeCode before completing so it is available after
          // the channel may be torn down.
          final capturedCode = channel?.closeCode;
          if (!doneCompleter.isCompleted) doneCompleter.complete(capturedCode);
        },
        cancelOnError: false,
      );

      // Fix H5: 30-second timeout waiting for conversation_init.
      initTimer = Timer(const Duration(seconds: 30), () {
        if (initCompleter.isCompleted) return;
        if (!controller.isClosed) {
          controller.add(const StreamError('Connection timed out'));
        }
        subscription?.cancel();
        if (!doneCompleter.isCompleted) doneCompleter.complete(null);
        if (!sinkClosed) {
          sinkClosed = true;
          channel?.sink.close();
        }
      });

      // Fix C4: wait for the single doneCompleter.
      final closeCode = await doneCompleter.future;

      // Check for close code 4003 (token expired on the WebSocket side).
      // Attempt up to 2 token refreshes before giving up.
      if (closeCode == 4003) {
        if (_wsReconnectAttempts < 2) {
          _wsReconnectAttempts++;
          try {
            await _apiClient.refreshToken();
            reconnectAfter4003 = true;
          } catch (refreshError) {
            if (!controller.isClosed) {
              controller.add(StreamError('Session expired. Please log in again.'));
            }
          }
        } else {
          if (!controller.isClosed) {
            controller.add(const StreamError('Session expired. Please log in again.'));
          }
        }
      }
    } catch (e) {
      String errorMessage;
      if (e is SocketException || e is WebSocketChannelException) {
        final connectivity = await Connectivity().checkConnectivity();
        final hasInterface = !connectivity.contains(ConnectivityResult.none);
        errorMessage = hasInterface
            ? "Connected to network but can't reach the server. "
              "If using public WiFi, a login screen may be required."
            : 'No internet connection. Please check your network.';
      } else {
        errorMessage = 'Something went wrong. Please try again.';
      }
      if (!controller.isClosed) controller.add(StreamError(errorMessage));
    } finally {
      initTimer?.cancel();
      await subscription?.cancel();
      // Fix C5: guarded close in finally.
      if (!sinkClosed) {
        sinkClosed = true;
        await channel?.sink.close();
      }
      // Clear instance references so cancelActiveStream() is a no-op after done.
      if (_activeDoneCompleter == doneCompleter) {
        _activeDoneCompleter = null;
        _activeChannel = null;
      }
      // Only close the controller if we are not about to reconnect.
      if (!reconnectAfter4003 && !controller.isClosed) await controller.close();
    }

    // Reconnect outside the try/finally so the old subscription and channel
    // are fully torn down before we open a new WebSocket connection.
    if (reconnectAfter4003) {
      // Close the reconnect race window: assign _activeDoneCompleter BEFORE
      // entering _runWebSocketStream so any cancelActiveStream() call during
      // the async gap finds a valid completer and can abort the new connection.
      final reconnectCompleter = Completer<int?>();
      _activeDoneCompleter = reconnectCompleter;
      await _runWebSocketStream(
        controller: controller,
        doneCompleter: reconnectCompleter,
        conversationId: conversationId,
        text: text,
        persona: persona,
        proactivity: proactivity,
        responseLength: responseLength,
        attachments: attachments,
        isRegenerate: isRegenerate,
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  DateTime _parseDate(dynamic raw) {
    if (raw == null) {
      debugPrint('[ApiCoachRepository] _parseDate: received null, falling back to DateTime.now()');
      return DateTime.now();
    }
    try {
      return DateTime.parse(raw as String).toLocal();
    } catch (e) {
      debugPrint('[ApiCoachRepository] Date parse failed for "$raw": $e — falling back to DateTime.now()');
      return DateTime.now();
    }
  }
}
