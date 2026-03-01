/// Zuralog Edge Agent — Chat Riverpod Providers.
///
/// Provides reactive state management for the Coach Chat feature:
/// - [chatNotifierProvider] for mutable chat state (messages, typing, error).
/// - [connectionStatusProvider] for live WebSocket connection status.
///
/// The [ChatNotifier] delegates all I/O to [ChatRepository] and exposes
/// a clean command interface ([connect], [reconnect], [sendMessage],
/// [loadHistory], [setTyping]) for the UI layer to drive.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/network/ws_client.dart';
import 'package:zuralog/features/chat/data/chat_repository.dart';
import 'package:zuralog/features/chat/domain/message.dart';

// ── Chat State ────────────────────────────────────────────────────────────────

/// Immutable snapshot of the chat screen's state.
///
/// Holds the accumulated message list, a typing flag while the AI is
/// generating a response, and an optional error string.
class ChatState {
  /// The list of messages in chronological order (oldest first).
  final List<ChatMessage> messages;

  /// Whether the AI assistant is currently composing a response.
  final bool isTyping;

  /// A non-null error message when an operation has failed.
  final String? error;

  /// Creates a [ChatState].
  ///
  /// All fields default to empty / false / null for the initial state.
  const ChatState({
    this.messages = const [],
    this.isTyping = false,
    this.error,
  });

  /// Returns a copy of this state with the specified fields replaced.
  ///
  /// Unspecified fields retain their current values.
  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      error: error ?? this.error,
    );
  }
}

// ── Chat Notifier ─────────────────────────────────────────────────────────────

/// State notifier that manages [ChatState] for the Coach Chat screen.
///
/// Orchestrates [ChatRepository] calls and updates the state reactively.
/// Subscribes to the message stream on [connect] and accumulates messages
/// into [ChatState.messages].
class ChatNotifier extends StateNotifier<ChatState> {
  /// The chat repository for WebSocket and REST operations.
  final ChatRepository _repository;

  /// Riverpod ref used to read other providers (e.g. [secureStorageProvider]).
  final Ref _ref;

  /// Tracks the stream subscription so it can be cancelled on dispose.
  Object? _messageSub;

  /// Whether [chat_opened] has been fired for the current session.
  bool _chatOpened = false;

  /// Creates a [ChatNotifier] with the given [repository] and [ref].
  ///
  /// Initial state has no messages, not typing, and no error.
  ChatNotifier(this._repository, this._ref) : super(const ChatState());

  @override
  void dispose() {
    if (_messageSub case final sub?) {
      // Cancel subscription if it was stored as a cancelable object.
      // We store the subscription handle as dynamic to avoid import coupling.
      _cancelSub(sub);
    }
    super.dispose();
  }

  /// Cancels a stream subscription stored as an opaque object.
  void _cancelSub(Object sub) {
    // ignore: avoid_dynamic_calls
    (sub as dynamic).cancel();
  }

  /// Reconnects the WebSocket using the token stored in [SecureStorage].
  ///
  /// Reads the auth token from [secureStorageProvider] and calls [connect].
  /// This is the correct handler for pull-to-refresh — it re-authenticates
  /// and resets the [WsClient] retry state before opening a fresh connection.
  /// Does nothing when no token is available.
  Future<void> reconnect() async {
    final token =
        await _ref.read(secureStorageProvider).getAuthToken();
    if (token != null && token.isNotEmpty) {
      connect(token);
    }
  }

  /// Opens the WebSocket connection and begins accumulating messages.
  ///
  /// [token] is the user's JWT authentication token.
  /// Starts listening to [ChatRepository.messages] and appends each
  /// incoming [ChatMessage] to [ChatState.messages].
  void connect(String token) {
    _repository.connect(token);

    // Analytics: fire chat_opened once per session when WebSocket connects.
    if (!_chatOpened) {
      _chatOpened = true;
      _ref.read(analyticsServiceProvider).capture(event: 'chat_opened');
    }

    final subscription = _repository.messages.listen(
      (message) {
        if (!mounted) return;
        final updated = [...state.messages, message];
        state = state.copyWith(messages: updated, isTyping: false);
      },
      onError: (Object error) {
        if (!mounted) return;
        state = state.copyWith(error: error.toString());
      },
    );
    _messageSub = subscription;
  }

  /// Sends a user message to the Cloud Brain.
  ///
  /// [text] is the message content to send.
  /// Optimistically adds the message to the local state before the server
  /// echo arrives, and sets [ChatState.isTyping] to true to show the
  /// typing indicator while the AI formulates a response.
  void sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      role: 'user',
      content: text.trim(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
      error: null,
    );

    _repository.sendMessage(text.trim());

    // Analytics: capture message sent event (fire-and-forget).
    _ref.read(analyticsServiceProvider).capture(
      event: 'chat_message_sent',
      properties: {'message_length': text.length},
    );
  }

  /// Fetches conversation history from the REST API.
  ///
  /// Prepends historical messages to the current message list.
  /// Silently ignores errors (history is non-critical).
  Future<void> loadHistory() async {
    try {
      final history = await _repository.fetchHistory();
      final historyMessages = <ChatMessage>[];

      for (final conversation in history) {
        if (conversation is! Map<String, dynamic>) continue;
        final msgs = conversation['messages'];
        if (msgs is! List<dynamic>) continue;
        for (final msgJson in msgs) {
          if (msgJson is! Map<String, dynamic>) continue;
          historyMessages.add(ChatMessage.fromJson(msgJson));
        }
      }

      if (!mounted) return;
      // Prepend history; deduplicate by id if available.
      final existing = state.messages;
      final combined = [...historyMessages, ...existing];
      state = state.copyWith(messages: combined);
    } catch (_) {
      // History fetch failure is non-critical — ignore silently.
    }
  }

  /// Updates the AI typing indicator state.
  ///
  /// [value] is `true` to show the indicator, `false` to hide it.
  void setTyping(bool value) {
    if (!mounted) return;
    state = state.copyWith(isTyping: value);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Provides [ChatNotifier] and its [ChatState] for the Coach Chat screen.
///
/// Auto-disposes when the screen is removed from the widget tree.
final chatNotifierProvider =
    StateNotifierProvider.autoDispose<ChatNotifier, ChatState>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return ChatNotifier(repository, ref);
});

/// Provides a reactive stream of [ConnectionStatus] from the WebSocket.
///
/// Auto-disposes when no longer watched.
final connectionStatusProvider =
    StreamProvider.autoDispose<ConnectionStatus>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.connectionStatus;
});
