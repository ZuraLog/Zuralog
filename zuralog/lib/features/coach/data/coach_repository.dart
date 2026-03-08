/// Zuralog — Coach Repository.
///
/// Provides a mock data layer for the Coach feature.
/// In production this will call the Cloud Brain API; for Phase 10 Polish
/// the repository supplies realistic stub data so the screens render
/// without a live backend dependency.
library;

import 'package:zuralog/features/coach/domain/coach_models.dart';

/// Abstract interface for the coach data source.
abstract interface class CoachRepository {
  /// Returns all non-archived conversations ordered by [updatedAt] desc.
  Future<List<Conversation>> listConversations();

  /// Returns all messages for [conversationId] ordered by [createdAt] asc.
  Future<List<ChatMessage>> listMessages(String conversationId);

  /// Returns contextual prompt suggestions for the current user context.
  Future<List<PromptSuggestion>> fetchPromptSuggestions();

  /// Returns quick-action tiles for the current user context.
  Future<List<QuickAction>> fetchQuickActions();

  /// Permanently deletes the conversation with [conversationId].
  Future<void> deleteConversation(String conversationId);

  /// Archives the conversation with [conversationId].
  Future<void> archiveConversation(String conversationId);

  /// Sends [text] as a new user message in [conversationId].
  ///
  /// The [persona], [proactivity], and [responseLength] values are forwarded
  /// to the backend so the AI system prompt is tailored to the user's preferences.
  ///
  /// Returns the AI's reply message (may be streamed in a future implementation).
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String text,
    required String persona,
    required String proactivity,
    required String responseLength,
    List<String> attachmentUrls = const [],
  });
}

// ── Mock Implementation ────────────────────────────────────────────────────────

/// Stub implementation of [CoachRepository] backed by in-memory fixtures.
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
      Conversation(
        id: 'c4',
        title: 'Stress Management Strategies',
        createdAt: now.subtract(const Duration(days: 21)),
        updatedAt: now.subtract(const Duration(days: 10)),
        preview: 'Your HRV drops sharply on high-stress days. Let\'s build a protocol.',
        messageCount: 6,
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
            '**2. Elevated resting heart rate** — Your RHR is up 6 bpm compared to your 30-day baseline, '
            'which often signals under-recovery or mild illness.\n\n'
            '**3. Increased evening activity** — Your step count after 8pm has doubled this week.\n\n'
            'Would you like me to build a short wind-down protocol based on what\'s worked best for you historically?',
        createdAt: now.subtract(const Duration(hours: 6, minutes: 15)),
      ),
      ChatMessage(
        id: 'm3',
        conversationId: conversationId,
        role: MessageRole.user,
        content: 'Yes, what worked best before?',
        createdAt: now.subtract(const Duration(hours: 5, minutes: 50)),
      ),
      ChatMessage(
        id: 'm4',
        conversationId: conversationId,
        role: MessageRole.assistant,
        content:
            'Based on your HRV trend over the past 3 months, your best sleep quality '
            '(consistently above 85) correlated with:\n\n'
            '- No screens 45 min before bed\n'
            '- A short 10-min walk after dinner\n'
            '- Consistent wake time within a ±15 min window\n\n'
            'I recommend shifting your bedtime target to **10:30 PM** for the next week. '
            'Want me to set a gentle reminder?',
        createdAt: now.subtract(const Duration(hours: 5, minutes: 44)),
      ),
    ];
  }

  @override
  Future<List<PromptSuggestion>> fetchPromptSuggestions() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const [
      PromptSuggestion(
        id: 'ps1',
        text: 'Why has my sleep score been dropping?',
        category: 'sleep',
      ),
      PromptSuggestion(
        id: 'ps2',
        text: 'How was my recovery this week?',
        category: 'activity',
      ),
      PromptSuggestion(
        id: 'ps3',
        text: 'What should I focus on to improve my health score?',
        category: 'general',
      ),
      PromptSuggestion(
        id: 'ps4',
        text: 'Analyze my stress and HRV patterns',
        category: 'heart',
      ),
      PromptSuggestion(
        id: 'ps5',
        text: 'Help me understand my nutrition trends',
        category: 'nutrition',
      ),
      PromptSuggestion(
        id: 'ps6',
        text: 'What\'s the best time for me to work out?',
        category: 'activity',
      ),
    ];
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Mock: no-op in mock implementation
  }

  @override
  Future<void> archiveConversation(String conversationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Mock: no-op in mock implementation
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String text,
    required String persona,
    required String proactivity,
    required String responseLength,
    List<String> attachmentUrls = const [],
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return ChatMessage(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      role: MessageRole.assistant,
      content: 'Mock response',
      createdAt: DateTime.now(),
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
        icon: 0xe3ab, // Icons.bedtime_rounded codepoint
        prompt: 'I want to log my sleep from last night.',
      ),
      QuickAction(
        id: 'qa2',
        title: 'Log Workout',
        subtitle: 'Describe your training session',
        icon: 0xe3b2, // Icons.fitness_center_rounded codepoint
        prompt: 'I want to log a workout I just completed.',
      ),
      QuickAction(
        id: 'qa3',
        title: 'Log Mood',
        subtitle: 'How are you feeling right now?',
        icon: 0xe5c8, // Icons.mood_rounded codepoint
        prompt: 'I want to log my current mood and energy level.',
      ),
      QuickAction(
        id: 'qa4',
        title: 'Log Meal',
        subtitle: 'Describe what you ate',
        icon: 0xe56c, // Icons.restaurant_rounded codepoint
        prompt: 'I want to log a meal I just had.',
      ),
      QuickAction(
        id: 'qa5',
        title: 'Weekly Check-in',
        subtitle: 'Review your week with me',
        icon: 0xe5d0, // Icons.check_circle_rounded codepoint
        prompt: 'Let\'s do a weekly health check-in and review my progress.',
      ),
      QuickAction(
        id: 'qa6',
        title: 'Ask Anything',
        subtitle: 'Open-ended health question',
        icon: 0xe8b6, // Icons.help_outline_rounded codepoint
        prompt: '',
      ),
    ];
  }
}
