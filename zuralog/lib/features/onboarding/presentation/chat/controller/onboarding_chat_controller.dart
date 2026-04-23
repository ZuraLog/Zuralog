/// Zuralog — Chat Onboarding Controller.
///
/// Drives the conversation: appends coach messages, waits for user
/// answers, updates [OnboardingProfile], simulates typing delays so
/// every reply *feels* like the coach is thinking. No backend calls
/// live in here — the screen reads the reactive state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/onboarding/presentation/chat/domain/chat_types.dart';

/// Riverpod provider for the onboarding chat controller.
final onboardingChatControllerProvider =
    StateNotifierProvider.autoDispose<OnboardingChatController, ChatState>(
  (ref) => OnboardingChatController()..start(),
);

class OnboardingChatController extends StateNotifier<ChatState> {
  OnboardingChatController() : super(ChatState.initial);

  /// Delay used before each coach message lands — makes the conversation
  /// feel paced, not mechanical. Short enough to feel responsive.
  static const Duration _shortPause = Duration(milliseconds: 600);
  static const Duration _mediumPause = Duration(milliseconds: 900);

  int _idCounter = 0;
  String _nextId() => 'msg_${_idCounter++}';

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Kicks off the conversation with the coach's opening lines.
  Future<void> start() async {
    if (state.messages.isNotEmpty) return;
    await _coachSays('Hi. I\'m your coach.');
    await _coachSays('What should I call you?', pause: _mediumPause);
  }

  // ── Submissions from the inputs ────────────────────────────────────────

  /// Called by the name text input when the user submits.
  Future<void> submitName(String rawName) async {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return;

    _userSays(trimmed);
    state = state.copyWith(
      profile: state.profile.copyWith(name: trimmed),
    );

    await _coachSays('Nice to meet you, $trimmed.', pause: _shortPause);
    await _coachSays(
      'A few quick basics so I can do your health math right.',
      pause: _mediumPause,
    );
    state = state.copyWith(currentStep: ChatStep.sex);
  }

  // The rest of the conversation — sex, age, height, weight, focus, goal,
  // tone, connect, finale — will be added as each input is built. Keeping
  // the controller narrow for the first milestone so the flow is visible
  // end-to-end before scope grows.

  // ── Internal helpers ───────────────────────────────────────────────────

  Future<void> _coachSays(String text, {Duration? pause}) async {
    if (_disposed) return;
    // Show typing indicator first.
    state = state.copyWith(
      isCoachComposing: true,
      messages: [
        ...state.messages,
        ChatMessage(
          id: _nextId(),
          author: MessageAuthor.coach,
          kind: MessageKind.typing,
        ),
      ],
    );

    await Future.delayed(pause ?? _shortPause);
    if (_disposed) return;

    // Replace the typing placeholder with the real message.
    final withoutTyping = state.messages
        .where((m) => m.kind != MessageKind.typing)
        .toList();
    state = state.copyWith(
      isCoachComposing: false,
      messages: [
        ...withoutTyping,
        ChatMessage(
          id: _nextId(),
          author: MessageAuthor.coach,
          kind: MessageKind.text,
          text: text,
        ),
      ],
    );
  }

  void _userSays(String text) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          id: _nextId(),
          author: MessageAuthor.user,
          kind: MessageKind.text,
          text: text,
        ),
      ],
    );
  }
}
