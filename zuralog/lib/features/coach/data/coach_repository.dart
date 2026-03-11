/// Zuralog — Coach Repository.
///
/// Defines the abstract [CoachRepository] interface used by all Coach
/// screens, plus the sealed [ChatStreamEvent] hierarchy used for
/// real-time streaming, and the [MockCoachRepository] stub for tests.
library;

import 'package:flutter/widgets.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';

// ── Stream Events ─────────────────────────────────────────────────────────────

/// Sealed base class for all events emitted by [CoachRepository.sendMessageStream].
sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

/// The server assigned a real UUID to the conversation.
///
/// Emitted as the first event when a new conversation is created
/// so the Flutter client can update its route / state with the
/// server-assigned ID before the first token arrives.
final class ConversationCreated extends ChatStreamEvent {
  const ConversationCreated(this.conversationId);

  /// The server-assigned conversation UUID.
  final String conversationId;
}

/// A partial response token from the LLM.
final class StreamToken extends ChatStreamEvent {
  const StreamToken({required this.delta, required this.accumulated});

  /// The incremental text fragment for this token.
  final String delta;

  /// All text received so far (running concatenation).
  final String accumulated;
}

/// The AI is running a MCP tool (e.g. fetching Apple Health data).
final class ToolProgress extends ChatStreamEvent {
  const ToolProgress({required this.toolName, required this.isStart});

  /// The internal tool name (e.g. ``apple_health_read_metrics``).
  final String toolName;

  /// True when the tool starts; false when it completes.
  final bool isStart;
}

/// Streaming has finished — the complete message is available.
final class StreamComplete extends ChatStreamEvent {
  const StreamComplete({
    required this.message,
    required this.conversationId,
  });

  /// The fully assembled [ChatMessage] including its server-assigned ID.
  final ChatMessage message;

  /// The conversation ID (may differ from the initial temp ID if new).
  final String conversationId;
}

/// An error occurred during the stream.
final class StreamError extends ChatStreamEvent {
  const StreamError(this.error);

  /// A human-readable description of the error.
  final String error;
}

// ── Repository Interface ───────────────────────────────────────────────────────

/// Abstract interface for the coach data source.
abstract interface class CoachRepository {
  /// Returns all non-deleted conversations ordered by [updatedAt] desc.
  Future<List<Conversation>> listConversations();

  /// Returns all messages for [conversationId] ordered by [createdAt] asc.
  Future<List<ChatMessage>> listMessages(String conversationId);

  /// Returns contextual prompt suggestions for the current user context.
  Future<List<PromptSuggestion>> fetchPromptSuggestions();

  /// Returns quick-action tiles for the current user context.
  Future<List<QuickAction>> fetchQuickActions();

  /// Permanently soft-deletes the conversation with [conversationId].
  Future<void> deleteConversation(String conversationId);

  /// Archives the conversation with [conversationId].
  Future<void> archiveConversation(String conversationId);

  /// Renames the conversation with [conversationId] to [newTitle].
  Future<void> renameConversation(String conversationId, String newTitle);

  /// Sends [text] as a new user message and streams the AI response.
  ///
  /// Emits [ChatStreamEvent] subtypes in this order:
  /// 1. [ConversationCreated] — only if this is a new conversation.
  /// 2. [ToolProgress] — zero or more pairs (isStart=true then false).
  /// 3. [StreamToken] — one per partial token from the LLM.
  /// 4. [StreamComplete] — final assembled message with server-assigned ID.
  ///
  /// On failure emits [StreamError] and the stream closes.
  ///
  /// When [isRegenerate] is true, the backend will skip persisting the user
  /// message (it was already saved during the original send).
  Stream<ChatStreamEvent> sendMessageStream({
    required String? conversationId,
    required String text,
    required String persona,
    required String proactivity,
    required String responseLength,
    List<Map<String, dynamic>> attachments = const [],
    bool isRegenerate = false,
  });
}

// ── Mock Implementation ────────────────────────────────────────────────────────

/// Stub implementation of [CoachRepository] backed by in-memory fixtures.
///
/// Used in unit tests and widget tests via provider overrides.
final class MockCoachRepository implements CoachRepository {
  const MockCoachRepository();

  @override
  Future<List<Conversation>> listConversations() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final now = DateTime.now();
    return [
      Conversation(
        id: 'c1',
        title: 'Sleep & Recovery Deep Dive',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(hours: 5)),
        preview: 'Based on your HRV trend, I recommend shifting bedtime by 30 min.',
        messageCount: 14,
      ),
      Conversation(
        id: 'c2',
        title: 'Weekly Training Load Review',
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(days: 1)),
        preview: 'Your zone 2 minutes are up 18% — great consistency this week.',
        messageCount: 9,
      ),
      Conversation(
        id: 'c3',
        title: 'Nutrition & Energy Correlation',
        createdAt: now.subtract(const Duration(days: 14)),
        updatedAt: now.subtract(const Duration(days: 3)),
        preview: 'Try adding protein within 45 min of waking based on your energy dips.',
        messageCount: 22,
      ),
    ];
  }

  @override
  Future<List<ChatMessage>> listMessages(String conversationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final now = DateTime.now();
    return [
      ChatMessage(
        id: 'm1',
        conversationId: conversationId,
        role: MessageRole.user,
        content: 'Why has my sleep quality been dropping this week?',
        createdAt: now.subtract(const Duration(hours: 6, minutes: 20)),
      ),
      ChatMessage(
        id: 'm2',
        conversationId: conversationId,
        role: MessageRole.assistant,
        content:
            'Looking at your data from the past 7 days, I can see a few contributing factors:\n\n'
            '**1. Later bedtimes** — You\'ve been going to bed 45 min later on average since Tuesday.\n\n'
            '**2. Elevated resting heart rate** — Your RHR is up 6 bpm compared to your 30-day baseline.\n\n'
            'Would you like me to build a short wind-down protocol based on what\'s worked best for you historically?',
        createdAt: now.subtract(const Duration(hours: 6, minutes: 15)),
      ),
    ];
  }

  @override
  Future<List<PromptSuggestion>> fetchPromptSuggestions() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const [
      PromptSuggestion(id: 'ps1', text: 'Why has my sleep score been dropping?', category: 'sleep'),
      PromptSuggestion(id: 'ps2', text: 'How was my recovery this week?', category: 'activity'),
      PromptSuggestion(id: 'ps3', text: 'What should I focus on to improve my health score?', category: 'general'),
      PromptSuggestion(id: 'ps4', text: 'Analyze my stress and HRV patterns', category: 'heart'),
    ];
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> archiveConversation(String conversationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> renameConversation(String conversationId, String newTitle) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Stream<ChatStreamEvent> sendMessageStream({
    required String? conversationId,
    required String text,
    required String persona,
    required String proactivity,
    required String responseLength,
    List<Map<String, dynamic>> attachments = const [],
    bool isRegenerate = false,
  }) async* {
    final String effectiveId = conversationId ?? 'mock_${DateTime.now().millisecondsSinceEpoch}';

    if (conversationId == null) {
      yield ConversationCreated(effectiveId);
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
    yield const ToolProgress(toolName: 'apple_health_read_metrics', isStart: true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    yield const ToolProgress(toolName: 'apple_health_read_metrics', isStart: false);

    const mockReply = 'This is a mock streaming response. Wire the real backend to see actual AI responses.';
    String accumulated = '';
    for (final word in mockReply.split(' ')) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final delta = '$word ';
      accumulated += delta;
      yield StreamToken(delta: delta, accumulated: accumulated);
    }

    yield StreamComplete(
      message: ChatMessage(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: effectiveId,
        role: MessageRole.assistant,
        content: accumulated.trim(),
        createdAt: DateTime.now(),
      ),
      conversationId: effectiveId,
    );
  }

  @override
  Future<List<QuickAction>> fetchQuickActions() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return const [
      QuickAction(
        id: 'qa1',
        title: 'Log Sleep',
        subtitle: 'Tell me how you slept last night',
        icon: IconData(0xe3ab, fontFamily: 'MaterialIcons'),
        prompt: 'I want to log my sleep from last night.',
      ),
      QuickAction(
        id: 'qa2',
        title: 'Log Workout',
        subtitle: 'Describe your training session',
        icon: IconData(0xe3b2, fontFamily: 'MaterialIcons'),
        prompt: 'I want to log a workout I just completed.',
      ),
      QuickAction(
        id: 'qa3',
        title: 'Log Mood',
        subtitle: 'How are you feeling right now?',
        icon: IconData(0xe5c8, fontFamily: 'MaterialIcons'),
        prompt: 'I want to log my current mood and energy level.',
      ),
      QuickAction(
        id: 'qa4',
        title: 'Weekly Check-in',
        subtitle: 'Review your week with me',
        icon: IconData(0xe5d0, fontFamily: 'MaterialIcons'),
        prompt: 'Let\'s do a weekly health check-in and review my progress.',
      ),
    ];
  }
}
