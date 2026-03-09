/// Zuralog — Coach Feature Riverpod Providers.
///
/// Central provider graph for the Coach tab:
///
///  - [coachRepositoryProvider]          — the live [ApiCoachRepository]
///  - [coachConversationsProvider]       — list of conversations (async notifier)
///  - [coachChatNotifierProvider]        — per-conversation streaming chat state
///  - [coachMessagesProvider]            — one-shot message fetch for a conversation
///  - [coachPromptSuggestionsProvider]   — contextual prompt chips
///  - [coachQuickActionsProvider]        — contextual quick-action tiles
///  - [coachPrefillProvider]             — cross-tab prefill text
///  - [pendingFirstMessageProvider]      — carries the first message across the
///                                         NewChat → ChatThread navigation boundary
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/coach/data/api_coach_repository.dart';
import 'package:zuralog/features/coach/data/coach_repository.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Provides the live [ApiCoachRepository].
///
/// In debug builds (`kDebugMode`) a [MockCoachRepository] is returned so the
/// Coach tab works without a running backend.
/// Override in tests with [MockCoachRepository].
final coachRepositoryProvider = Provider<CoachRepository>((ref) {
  if (kDebugMode) return const MockCoachRepository();
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
    this.activeToolName,
    this.isLoadingHistory = false,
    this.isSending = false,
    this.errorMessage,
    this.resolvedConversationId,
  });

  /// Messages loaded from history (does NOT include the in-flight streaming
  /// message; that lives in [streamingContent]).
  final List<ChatMessage> messages;

  /// Partial tokens from the current streaming response.
  /// Non-null while a streaming response is in progress.
  final String? streamingContent;

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

  CoachChatState copyWith({
    List<ChatMessage>? messages,
    String? streamingContent,
    bool clearStreaming = false,
    String? activeToolName,
    bool clearTool = false,
    bool? isLoadingHistory,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
    String? resolvedConversationId,
  }) {
    return CoachChatState(
      messages: messages ?? this.messages,
      streamingContent: clearStreaming ? null : (streamingContent ?? this.streamingContent),
      activeToolName: clearTool ? null : (activeToolName ?? this.activeToolName),
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      resolvedConversationId: resolvedConversationId ?? this.resolvedConversationId,
    );
  }
}

/// Notifier that drives a single conversation's chat UI.
///
/// Created as a `.family` provider keyed on the conversation ID
/// (which may be a temporary "new_XXXX" string for brand-new conversations).
class CoachChatNotifier extends FamilyNotifier<CoachChatState, String> {
  StreamSubscription<ChatStreamEvent>? _streamSub;

  @override
  CoachChatState build(String conversationId) {
    ref.onDispose(() {
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
  }) async {
    if (state.isSending) return;

    // Optimistically append the user's message.
    final tempMsgId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
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
      isSending: true,
      clearError: true,
    );

    await _streamSub?.cancel();

    final stream = ref.read(coachRepositoryProvider).sendMessageStream(
      conversationId: conversationId,
      text: text,
      persona: persona,
      proactivity: proactivity,
      responseLength: responseLength,
      attachments: attachments,
      isRegenerate: isRegenerate,
    );

    final completer = Completer<void>();

    _streamSub = stream.listen(
      (event) {
        switch (event) {
          case ConversationCreated(:final conversationId):
            state = state.copyWith(resolvedConversationId: conversationId);

          case ToolProgress(:final toolName, :final isStart):
            state = state.copyWith(
              activeToolName: isStart ? toolName : null,
              clearTool: !isStart,
            );

          case StreamToken(:final accumulated):
            state = state.copyWith(streamingContent: accumulated);

          case StreamComplete(:final message, :final conversationId):
            // Replace the optimistic user message with the server version
            // (same content, server-assigned ID) and append the AI reply.
            final updated = state.messages.map((m) {
              return m.id == tempMsgId ? m.copyWith(id: m.id) : m;
            }).toList();

            state = state.copyWith(
              messages: [...updated, message],
              isSending: false,
              clearStreaming: true,
              clearTool: true,
              resolvedConversationId: conversationId,
            );

            // Refresh the conversation list so the drawer shows the new entry.
            ref.read(coachConversationsProvider.notifier).refresh();

            if (!completer.isCompleted) completer.complete();

          case StreamError(:final error):
            state = state.copyWith(
              isSending: false,
              clearStreaming: true,
              clearTool: true,
              errorMessage: error,
            );
            if (!completer.isCompleted) completer.complete();
        }
      },
      onError: (Object error) {
        state = state.copyWith(
          isSending: false,
          clearStreaming: true,
          errorMessage: 'Connection error: $error',
        );
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: false,
    );

    await completer.future;
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

    // Find the last user message.
    ChatMessage? lastUserMsg;
    for (final m in messages.reversed) {
      if (m.role == MessageRole.user) {
        lastUserMsg = m;
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
    );
  }

  /// Cancels any in-flight stream.
  ///
  /// If partial tokens have already arrived ([streamingContent] is non-empty),
  /// they are committed as a final assistant message. Otherwise a placeholder
  /// message `_Generation stopped._` is appended so the user knows the
  /// generation was cancelled.
  void cancelStream() {
    final wasSending = state.isSending; // capture before cancel
    _streamSub?.cancel();
    _streamSub = null;

    if (!wasSending) return;

    final partial = state.streamingContent ?? '';
    final content = partial.isNotEmpty ? partial : '_Generation stopped._';

    final stoppedMsg = ChatMessage(
      id: 'stopped_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: state.resolvedConversationId ?? arg,
      role: MessageRole.assistant,
      content: content,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, stoppedMsg],
      isSending: false,
      clearStreaming: true,
      clearTool: true,
    );
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

// ── Messages (simple fetch — for initial load without the notifier) ────────────

/// Loads messages for a specific [conversationId].
///
/// Prefer [coachChatNotifierProvider] for the full chat experience;
/// this provider is a simpler read-only fetch for cases that don't
/// need streaming state.
final coachMessagesProvider = FutureProvider.family<List<ChatMessage>, String>(
  (ref, conversationId) async {
    return ref.read(coachRepositoryProvider).listMessages(conversationId);
  },
);

// ── Prompt Suggestions ────────────────────────────────────────────────────────

/// Loads contextual prompt suggestion chips for the New Chat screen.
final coachPromptSuggestionsProvider =
    FutureProvider<List<PromptSuggestion>>((ref) async {
  return ref.read(coachRepositoryProvider).fetchPromptSuggestions();
});

// ── Quick Actions ─────────────────────────────────────────────────────────────

/// Loads quick-action tiles for the Quick Actions bottom sheet.
final coachQuickActionsProvider =
    FutureProvider<List<QuickAction>>((ref) async {
  return ref.read(coachRepositoryProvider).fetchQuickActions();
});

// ── Coach Prefill ─────────────────────────────────────────────────────────────

/// Transient prefill text that the Data tab can set before navigating to the
/// Coach tab. [NewChatScreen] reads this once and clears it after injecting
/// the text into the input field, so it is never reused across navigations.
final coachPrefillProvider = StateProvider<String?>((ref) => null);

// ── Pending First Message ─────────────────────────────────────────────────────

/// Carries the pending first message from [NewChatScreen] to [ChatThreadScreen].
///
/// [NewChatScreen] sets this before pushing the thread route with a temp ID.
/// [ChatThreadScreen] reads and clears it on first build, triggering the
/// actual [CoachChatNotifier.sendMessage] call.
class PendingMessage {
  const PendingMessage({
    required this.text,
    required this.persona,
    required this.proactivity,
    required this.responseLength,
    this.attachments = const [],
  });

  final String text;
  final String persona;
  final String proactivity;
  final String responseLength;
  final List<Map<String, dynamic>> attachments;
}

final pendingFirstMessageProvider =
    StateProvider.family<PendingMessage?, String>((ref, tempId) => null);
