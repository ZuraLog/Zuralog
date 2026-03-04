/// Zuralog — Coach Feature Riverpod Providers.
///
/// Exposes the [CoachRepository] and all async state needed by the Coach
/// screens (conversations list, messages, prompt suggestions, quick actions).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/coach/data/coach_repository.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Provides the [CoachRepository] implementation.
///
/// Override in tests with a mock or stub.
final coachRepositoryProvider = Provider<CoachRepository>(
  (_) => const MockCoachRepository(),
);

// ── Conversations List ────────────────────────────────────────────────────────

/// Loads the list of conversations for the Conversation Drawer.
final coachConversationsProvider =
    FutureProvider<List<Conversation>>((ref) async {
  return ref.read(coachRepositoryProvider).listConversations();
});

// ── Messages ──────────────────────────────────────────────────────────────────

/// Loads messages for a specific [conversationId].
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

// ── Active Conversation Notifier ──────────────────────────────────────────────

/// Tracks the ID of the currently open conversation (null = new chat).
final activeConversationIdProvider =
    StateProvider<String?>((ref) => null);
