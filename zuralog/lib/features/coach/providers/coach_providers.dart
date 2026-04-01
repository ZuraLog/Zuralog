/// Zuralog — Coach Feature Riverpod Providers.
///
/// Central provider graph for the Coach tab:
///
///  - [coachRepositoryProvider]          — the live [ApiCoachRepository]
///  - [coachConversationsProvider]       — list of conversations (async notifier)
///  - [coachChatNotifierProvider]        — per-conversation streaming chat state
///  - [coachPromptSuggestionsProvider]   — contextual prompt chips
///  - [coachQuickActionsProvider]        — contextual quick-action tiles
///  - [coachPrefillProvider]             — cross-tab prefill text
///  - [pendingFirstMessageProvider]      — carries the first message across the
///                                         NewChat → ChatThread navigation boundary
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/coach/data/api_coach_repository.dart';
import 'package:zuralog/features/coach/data/coach_repository.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Tool name keywords that indicate a write/mutation operation.
///
/// Used to suppress tool call indicators in ghost mode so write operations
/// don't appear in the UI when nothing should be persisted.
const _kGhostWriteToolKeywords = [
  'save', 'store', 'write', 'memory', 'log',
  'create', 'update', 'delete', 'archive',
];

// ── Repository ────────────────────────────────────────────────────────────────

/// Provides the live [ApiCoachRepository].
///
/// Always uses the real [ApiCoachRepository] backed by the Cloud Brain API.
/// Override in tests with [MockCoachRepository].
final coachRepositoryProvider = Provider<CoachRepository>((ref) {
  return ApiCoachRepository(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

// ── Conversations List ────────────────────────────────────────────────────────

/// State for the conversation list used by the Conversation Drawer.
class _ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    try {
      return await ref.read(coachRepositoryProvider).listConversations();
    } on DioException catch (e) {
      throw Exception(ApiClient.friendlyError(e));
    }
  }

  /// Re-fetches the conversation list from the server.
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(coachRepositoryProvider).listConversations();
      state = AsyncData(result);
    } on DioException catch (e) {
      state = AsyncError(Exception(ApiClient.friendlyError(e)), StackTrace.current);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  /// Optimistically archives [conversationId] and syncs with the server.
  Future<void> archive(String conversationId) async {
    // Optimistic update
    final prev = state.valueOrNull;
    if (prev != null) {
      state = AsyncData(
        prev.map((c) => c.id == conversationId ? c.copyWith(isArchived: true) : c).toList(),
      );
    }
    try {
      await ref.read(coachRepositoryProvider).archiveConversation(conversationId);
      // Remove archived conversation from the default (non-archived) list.
      state = AsyncData(
        (state.valueOrNull ?? []).where((c) => c.id != conversationId).toList(),
      );
    } catch (_) {
      // Rollback
      if (prev != null) state = AsyncData(prev);
      rethrow;
    }
  }

  /// Optimistically removes [conversationId] and syncs with the server.
  Future<void> delete(String conversationId) async {
    final prev = state.valueOrNull;
    if (prev != null) {
      state = AsyncData(prev.where((c) => c.id != conversationId).toList());
    }
    try {
      await ref.read(coachRepositoryProvider).deleteConversation(conversationId);
    } catch (_) {
      if (prev != null) state = AsyncData(prev);
      rethrow;
    }
  }

  /// Optimistically renames [conversationId] to [newTitle].
  Future<void> rename(String conversationId, String newTitle) async {
    final prev = state.valueOrNull;
    if (prev != null) {
      state = AsyncData(
        prev.map((c) => c.id == conversationId ? c.copyWith(title: newTitle) : c).toList(),
      );
    }
    try {
      await ref.read(coachRepositoryProvider).renameConversation(conversationId, newTitle);
    } catch (_) {
      if (prev != null) state = AsyncData(prev);
      rethrow;
    }
  }

  /// Adds a newly created conversation to the top of the list.
  void prependConversation(Conversation conversation) {
    final current = state.valueOrNull ?? [];
    state = AsyncData([conversation, ...current]);
  }
}

/// Async notifier for the conversation list.
///
/// Call `.notifier.refresh()` to reload after mutations.
final coachConversationsProvider =
    AsyncNotifierProvider<_ConversationsNotifier, List<Conversation>>(
  _ConversationsNotifier.new,
);

// ── Per-Conversation Chat State ───────────────────────────────────────────────

/// Immutable state snapshot for one conversation's chat.
class CoachChatState {
  const CoachChatState({
    this.messages = const [],
    this.streamingContent,
    this.thinkingContent,
    this.activeToolName,
    this.isLoadingHistory = false,
    this.isSending = false,
    this.errorMessage,
    this.resolvedConversationId,
    this.isCancelled = false,
    this.isEditing = false,
    this.editingContent,
    this.editSnapshot,
    this.isNotFound = false,
  });

  /// Messages loaded from history (does NOT include the in-flight streaming
  /// message; that lives in [streamingContent]).
  final List<ChatMessage> messages;

  /// Partial tokens from the current streaming response.
  /// Non-null while a streaming response is in progress.
  final String? streamingContent;

  /// Accumulated reasoning/thinking text from the AI (display-only).
  /// Non-null while the AI is in its reasoning phase, before real content
  /// tokens start arriving.
  final String? thinkingContent;

  /// Tool being executed right now (e.g. "apple_health_read_metrics").
  final String? activeToolName;

  /// True while loading the conversation history on first open.
  final bool isLoadingHistory;

  /// True while the user's send is in flight (waiting for AI response).
  final bool isSending;

  /// Non-null when the last operation failed.
  final String? errorMessage;

  /// The server-assigned conversation UUID, which may differ from the
  /// temporary "new_XXXX" ID used before the first send completes.
  final String? resolvedConversationId;

  /// True after the user explicitly cancelled a stream via [cancelStream].
  /// Reset to false at the start of the next [sendMessage] call.
  final bool isCancelled;

  /// True when the conversation was not found on the server (HTTP 404).
  final bool isNotFound;

  /// True when the user is editing a previously sent message.
  final bool isEditing;

  /// The original content of the message being edited.
  final String? editingContent;

  /// Snapshot of messages taken just before [editMessage] truncates state.
  /// Restored if the user cancels the edit.
  final List<ChatMessage>? editSnapshot;

  CoachChatState copyWith({
    List<ChatMessage>? messages,
    String? streamingContent,
    bool clearStreaming = false,
    String? thinkingContent,
    bool clearThinking = false,
    String? activeToolName,
    bool clearTool = false,
    bool? isLoadingHistory,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
    String? resolvedConversationId,
    bool? isCancelled,
    bool? isEditing,
    String? editingContent,
    bool clearEditingContent = false,
    List<ChatMessage>? editSnapshot,
    bool clearEditSnapshot = false,
    bool? isNotFound,
  }) {
    return CoachChatState(
      messages: messages ?? this.messages,
      streamingContent: clearStreaming ? null : (streamingContent ?? this.streamingContent),
      thinkingContent: clearThinking ? null : (thinkingContent ?? this.thinkingContent),
      activeToolName: clearTool ? null : (activeToolName ?? this.activeToolName),
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      resolvedConversationId: resolvedConversationId ?? this.resolvedConversationId,
      isCancelled: isCancelled ?? this.isCancelled,
      isEditing: isEditing ?? this.isEditing,
      editingContent: clearEditingContent ? null : (editingContent ?? this.editingContent),
      editSnapshot: clearEditSnapshot ? null : (editSnapshot ?? this.editSnapshot),
      isNotFound: isNotFound ?? this.isNotFound,
    );
  }
}

/// Notifier that drives a single conversation's chat UI.
///
/// Created as a `.family` provider keyed on the conversation ID
/// (which may be a temporary "new_XXXX" string for brand-new conversations).
class CoachChatNotifier extends FamilyNotifier<CoachChatState, String> {
  StreamSubscription<ChatStreamEvent>? _streamSub;
  Timer? _timeoutTimer;
  String? _pendingTempMsgId;

  @override
  CoachChatState build(String conversationId) {
    ref.onDispose(() {
      _timeoutTimer?.cancel();
      _streamSub?.cancel();
    });
    return CoachChatState(resolvedConversationId: conversationId);
  }

  /// Loads existing messages from the server.
  ///
  /// Only called for conversations that already exist (non-"new_" prefix).
  Future<void> loadHistory() async {
    state = state.copyWith(isLoadingHistory: true, clearError: true);
    try {
      final messages = await ref
          .read(coachRepositoryProvider)
          .listMessages(arg);
      state = state.copyWith(messages: messages, isLoadingHistory: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        state = state.copyWith(isLoadingHistory: false, isNotFound: true);
        return;
      }
      state = state.copyWith(
        isLoadingHistory: false,
        errorMessage: ApiClient.friendlyError(e),
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingHistory: false,
        errorMessage: 'Could not load conversation. Please try again.',
      );
    }
  }

  /// Clears the current error message without triggering any network request.
  ///
  /// Used by the retry button for new conversations, where there is nothing
  /// to reload — the user simply re-types and sends again.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Sends [text] (with optional [attachments]) and streams the AI response.
  ///
  /// [conversationId] is null for new conversations; the server will create
  /// one and the [ConversationCreated] event will propagate it back.
  ///
  /// When [isRegenerate] is true, the backend skips persisting the user
  /// message (it was already saved during the original send).
  Future<void> sendMessage({
    required String? conversationId,
    required String text,
    required String persona,
    required String proactivity,
    required String responseLength,
    List<Map<String, dynamic>> attachments = const [],
    bool isRegenerate = false,
    String? systemPromptExtra,
    bool isGhost = false,
  }) async {
    if (state.isSending) return;

    // Fix H1: set isSending immediately to prevent double-sends.
    state = state.copyWith(isSending: true, clearError: true, isCancelled: false);

    // Fix CC2: connectivity check before doing anything.
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'No internet connection. Please check your network.',
      );
      return;
    }

    // Fix M2: message length cap.
    if (text.length > 4000) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Message too long (max 4,000 characters)',
      );
      return;
    }

    // Optimistically append the user's message (skipped when regenerating
    // because the user bubble is already present in state).
    String? tempMsgId;
    if (!isRegenerate) {
      tempMsgId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      _pendingTempMsgId = tempMsgId;
      final userMsg = ChatMessage(
        id: tempMsgId,
        conversationId: conversationId ?? arg,
        role: MessageRole.user,
        content: text,
        createdAt: DateTime.now(),
        attachmentUrls: attachments
            .map((a) => (a['signed_url'] ?? a['storage_path'] ?? '') as String)
            .where((u) => u.isNotEmpty)
            .toList(),
      );
      state = state.copyWith(
        messages: [...state.messages, userMsg],
      );
    } else {
      _pendingTempMsgId = null;
    }

    await _streamSub?.cancel();

    final stream = ref.read(coachRepositoryProvider).sendMessageStream(
      conversationId: conversationId,
      text: text,
      persona: persona,
      proactivity: proactivity,
      responseLength: responseLength,
      attachments: attachments,
      isRegenerate: isRegenerate,
      systemPromptExtra: systemPromptExtra,
      isGhost: isGhost,
    );

    final completer = Completer<void>();

    _streamSub = stream.listen(
      (event) {
        // Every event from the server proves the connection is alive — reset
        // the inactivity timer so a legitimately long response is never killed.
        _resetInactivityTimer();

        switch (event) {
          case ConversationCreated(:final conversationId):
            state = state.copyWith(resolvedConversationId: conversationId);

          case ToolProgress(:final toolName, :final isStart):
            final isWriteTool = _kGhostWriteToolKeywords.any(
              (kw) => toolName.toLowerCase().contains(kw),
            );
            if (isGhost && isWriteTool) break;
            state = state.copyWith(
              activeToolName: isStart ? toolName : null,
              clearTool: !isStart,
              // Clear thinking text when a tool starts so stale reasoning
              // text can't flash back if activeToolName briefly becomes null
              // between consecutive tool events on thinking models.
              clearThinking: isStart,
            );

          case ThinkingToken(:final accumulated):
            state = state.copyWith(thinkingContent: accumulated);

          case StreamToken(:final accumulated):
            state = state.copyWith(
              streamingContent: accumulated,
              clearThinking: true,
            );

          case StreamComplete(:final message, :final conversationId):
            _cancelInactivityTimer();
            // Append the AI reply to the existing messages list.
            state = state.copyWith(
              messages: [...state.messages, message],
              isSending: false,
              clearStreaming: true,
              clearTool: true,
              clearThinking: true,
              resolvedConversationId: conversationId,
            );
            _pendingTempMsgId = null;

            // Refresh the conversation list so the drawer shows the new entry.
            // Skip in ghost mode — ghost conversations are never persisted.
            if (!isGhost) ref.read(coachConversationsProvider.notifier).refresh();

            if (!completer.isCompleted) completer.complete();

          case StreamError(:final error):
            _cancelInactivityTimer();
            state = state.copyWith(
              messages: tempMsgId != null
                  ? state.messages.where((m) => m.id != tempMsgId).toList()
                  : null,
              isSending: false,
              clearStreaming: true,
              clearTool: true,
              clearThinking: true,
              errorMessage: error,
            );
            _pendingTempMsgId = null;
            if (!completer.isCompleted) completer.complete();
        }
      },
      onError: (Object error) {
        _cancelInactivityTimer();
        state = state.copyWith(
          messages: tempMsgId != null
              ? state.messages.where((m) => m.id != tempMsgId).toList()
              : null,
          isSending: false,
          clearStreaming: true,
          clearTool: true,
          clearThinking: true,
          errorMessage: 'Connection lost. Please try again.',
        );
        _pendingTempMsgId = null;
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        _cancelInactivityTimer();
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    // Start the inactivity timer. It resets on every server event, so it only
    // fires when the connection goes completely silent — matching how OpenAI,
    // Anthropic, and all major AI products handle this. The AI can think for
    // as long as it needs; we only give up if the server stops responding.
    _resetInactivityTimer();

    await completer.future;
  }

  /// The inactivity window before treating a silent connection as dead.
  ///
  /// 10 minutes matches the OpenAI SDK default and Anthropic's recommended
  /// threshold for streaming requests. Resets on every server event.
  static const _kInactivityTimeout = Duration(minutes: 10);

  /// Cancels the current inactivity timer and starts a fresh one.
  ///
  /// Called on every received server event so the timer only fires when the
  /// connection has been completely silent for [_kInactivityTimeout].
  void _resetInactivityTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_kInactivityTimeout, () => _onInactivityTimeout());
  }

  /// Cancels the inactivity timer without restarting it.
  ///
  /// Called when the stream completes normally or errors — no timeout needed.
  void _cancelInactivityTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  /// Called when the server has been silent for [_kInactivityTimeout].
  ///
  /// The connection is considered dead — cancel the stream (both locally and
  /// on the repository so the server-side WebSocket is torn down immediately,
  /// avoiding unnecessary LLM token burn) and surface a clear error so the
  /// user knows they can try again.
  Future<void> _onInactivityTimeout() async {
    _streamSub?.cancel();
    _streamSub = null;
    _timeoutTimer = null;

    // Tell the server to close the active WebSocket stream so it stops
    // generating tokens — mirrors what cancelStream() does explicitly.
    await ref.read(coachRepositoryProvider).cancelActiveStream();

    state = state.copyWith(
      messages: _pendingTempMsgId != null
          ? state.messages.where((m) => m.id != _pendingTempMsgId).toList()
          : null,
      isSending: false,
      clearStreaming: true,
      clearTool: true,
      clearThinking: true,
      errorMessage: 'The connection went silent. Please try again.',
    );
    _pendingTempMsgId = null;
  }

  /// Removes the last assistant message from local state and re-sends the
  /// last user message, telling the backend NOT to persist a duplicate.
  ///
  /// No-op if there is no assistant message or no user message in the list.
  Future<void> regenerate() async {
    if (state.isSending) return;

    final messages = state.messages;

    // Find the last assistant message index.
    final lastAssistantIndex =
        messages.lastIndexWhere((m) => m.role == MessageRole.assistant);
    if (lastAssistantIndex == -1) return;

    // Find the user message immediately before the assistant message being
    // removed — not just the last user message in the whole list.
    ChatMessage? lastUserMsg;
    for (int i = lastAssistantIndex - 1; i >= 0; i--) {
      if (messages[i].role == MessageRole.user) {
        lastUserMsg = messages[i];
        break;
      }
    }
    if (lastUserMsg == null) return;

    // Read the user's actual settings so the regenerated response respects
    // their configured persona, proactivity, and response-length preferences.
    final persona = ref.read(coachPersonaProvider).value;
    final proactivity = ref.read(proactivityLevelProvider).value;
    final responseLength = ref.read(responseLengthProvider).value;

    // Remove the last assistant message from local state only.
    final updatedMessages = List<ChatMessage>.from(messages)
      ..removeAt(lastAssistantIndex);
    state = state.copyWith(messages: updatedMessages);

    // Re-send the last user message, skipping DB persistence on the backend.
    await sendMessage(
      conversationId: state.resolvedConversationId,
      text: lastUserMsg.content,
      persona: persona,
      proactivity: proactivity,
      responseLength: responseLength,
      isRegenerate: true,
      isGhost: ref.read(ghostModeProvider),
    );
  }

  /// Removes the message at [messageIndex] and all messages after it from
  /// local state, then returns the content of the removed message so the
  /// caller can pre-fill the input field.
  ///
  /// Delegates to [startEditing] so a snapshot is always saved before
  /// truncation (enabling cancel-restore via [cancelEditing]).
  ///
  /// This is a local-only operation — nothing is persisted to the DB.
  ///
  /// Returns null if [messageIndex] is out of bounds (e.g. state changed
  /// between render and tap).
  String? editMessage(int messageIndex) {
    if (state.isSending) return null;
    if (messageIndex < 0 || messageIndex >= state.messages.length) return null;
    final content = state.messages[messageIndex].content;
    startEditing(messageIndex);
    return content;
  }

  /// Restores [messages] into state.
  ///
  /// Called when the user cancels an edit so the truncated messages come back.
  void restoreMessages(List<ChatMessage> messages) {
    state = state.copyWith(messages: messages);
  }

  /// Enters editing mode for the message at [index].
  ///
  /// Stores a snapshot of the current messages for cancel-restore,
  /// truncates state to exclude the message being edited, and sets
  /// [CoachChatState.isEditing] / [CoachChatState.editingContent].
  void startEditing(int index) {
    if (state.isSending) return;
    if (index < 0 || index >= state.messages.length) return;
    final content = state.messages[index].content;
    final snapshot = List<ChatMessage>.from(state.messages);
    state = state.copyWith(
      messages: state.messages.sublist(0, index),
      isEditing: true,
      editingContent: content,
      editSnapshot: snapshot,
    );
  }

  /// Cancels editing mode and restores the snapshot.
  void cancelEditing() {
    final snapshot = state.editSnapshot;
    state = state.copyWith(
      isEditing: false,
      clearEditingContent: true,
      clearEditSnapshot: true,
      messages: snapshot ?? state.messages,
    );
  }

  /// Seeds this notifier with [messages] and [resolvedConversationId] from a
  /// prior (temp-ID) notifier instance.
  ///
  /// Called by [ChatThreadScreen] immediately after a new conversation's
  /// route-replace — before [_initConversation] runs — so the incoming screen
  /// shows the already-streamed messages instead of triggering a redundant
  /// history load.
  void seedFromPrior({
    required List<ChatMessage> messages,
    required String resolvedConversationId,
  }) {
    if (state.isSending) return;
    state = CoachChatState(
      messages: messages,
      resolvedConversationId: resolvedConversationId,
    );
  }

  /// Cancels any in-flight stream.
  ///
  /// Sets [CoachChatState.isCancelled] to true so the UI can show a
  /// "Generation stopped" indicator. No ghost message is appended — partial
  /// tokens are discarded. The cancelled state resets on the next send.
  Future<void> cancelStream() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    final wasSending = state.isSending; // capture before cancel
    _streamSub?.cancel();
    _streamSub = null;

    // Also cancel the active WebSocket stream on the repository so the
    // underlying connection is torn down immediately.
    await ref.read(coachRepositoryProvider).cancelActiveStream();

    if (!wasSending) return;

    state = state.copyWith(
      messages: _pendingTempMsgId != null
          ? state.messages.where((m) => m.id != _pendingTempMsgId).toList()
          : null,
      isSending: false,
      clearStreaming: true,
      clearTool: true,
      clearThinking: true,
      isCancelled: true,
    );
    _pendingTempMsgId = null;
  }
}

/// Per-conversation chat notifier, keyed on the conversation ID.
///
/// Usage:
/// ```dart
/// final chatState = ref.watch(coachChatNotifierProvider(conversationId));
/// ref.read(coachChatNotifierProvider(conversationId).notifier).sendMessage(...);
/// ```
final coachChatNotifierProvider =
    NotifierProviderFamily<CoachChatNotifier, CoachChatState, String>(
  CoachChatNotifier.new,
);

// ── Prompt Suggestions ────────────────────────────────────────────────────────

/// Loads contextual prompt suggestion chips for the New Chat screen.
final coachPromptSuggestionsProvider =
    FutureProvider<List<PromptSuggestion>>((ref) async {
  try {
    return await ref.watch(coachRepositoryProvider).fetchPromptSuggestions();
  } catch (_) {
    return [];
  }
});

// ── Quick Actions ─────────────────────────────────────────────────────────────

/// Loads quick-action tiles for the Quick Actions bottom sheet.
final coachQuickActionsProvider =
    FutureProvider<List<QuickAction>>((ref) async {
  try {
    return await ref.watch(coachRepositoryProvider).fetchQuickActions();
  } catch (_) {
    return [];
  }
});

// ── Coach Prefill ─────────────────────────────────────────────────────────────

/// Transient prefill text that the Data tab can set before navigating to the
/// Coach tab. [NewChatScreen] reads this once and clears it after injecting
/// the text into the input field, so it is never reused across navigations.
final coachPrefillProvider = StateProvider<String?>((ref) => null);

// ── Journal Mode ──────────────────────────────────────────────────────────────

/// When true, the next Coach conversation will use the journal check-in
/// system prompt instead of the general coaching prompt.
/// Reset to false after the conversation is opened.
final coachJournalModeProvider = StateProvider<bool>((ref) => false);

// ── Pending First Message ─────────────────────────────────────────────────────

/// Carries the pending first message from [NewChatScreen] to [ChatThreadScreen].
///
/// [NewChatScreen] sets this before pushing the thread route with a temp ID.
/// [ChatThreadScreen] reads and clears it on first build, triggering the
/// actual [CoachChatNotifier.sendMessage] call.
///
/// Attachments from [NewChatScreen] cannot be uploaded before the conversation
/// exists on the server. Raw file paths are stored in [rawAttachments] and
/// [ChatThreadScreen] uploads them after receiving a real conversation UUID
/// from the [ConversationCreated] stream event, then sends a follow-up message
/// with the resulting payloads.
class PendingMessage {
  const PendingMessage({
    required this.text,
    required this.persona,
    required this.proactivity,
    required this.responseLength,
    this.attachments = const [],
    this.rawAttachments = const [],
    this.systemPromptExtra,
  });

  final String text;
  final String persona;
  final String proactivity;
  final String responseLength;

  /// Pre-uploaded attachment payloads (used when a conversation ID was already
  /// available at upload time, e.g. follow-up messages in [ChatThreadScreen]).
  final List<Map<String, dynamic>> attachments;

  /// Raw local file paths for attachments that could not be uploaded before
  /// the conversation was created. Each entry is a map with keys:
  /// - `path`: absolute path to the local file
  /// - `name`: display filename
  ///
  /// [ChatThreadScreen] uploads these after the server assigns a real UUID.
  final List<Map<String, String>> rawAttachments;

  /// Optional extra system prompt injected on the first message of a
  /// conversation. Used by journal check-in mode to override the default
  /// coaching instructions with journal-specific guidance.
  final String? systemPromptExtra;
}

final pendingFirstMessageProvider =
    StateProvider.family<PendingMessage?, String>((ref, tempId) => null);

// ── Ghost Mode ────────────────────────────────────────────────────────────────

/// When true, the Coach tab is in ghost mode — no messages are persisted.
///
/// Ghost conversations are keyed with a "ghost_" prefix in [CoachScreen] so
/// they are never added to the conversation drawer or synced to the backend.
/// Resetting to false clears the ghost session and returns to [IdleState].
final ghostModeProvider = StateProvider<bool>((ref) => false);
