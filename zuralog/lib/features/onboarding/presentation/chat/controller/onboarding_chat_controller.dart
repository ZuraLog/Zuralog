/// Zuralog — Chat Onboarding Controller.
///
/// Drives the conversation with the AI coach. Each submit* method:
///   1. Appends the user's answer as a right-aligned bubble.
///   2. Updates [OnboardingProfile].
///   3. Plays back one or more coach replies (with a typing indicator
///      pause in front) that react to what the user just said.
///   4. Advances [currentStep] so the UI swaps in the next inline input.
///
/// No backend calls — persistence happens once the user taps
/// "Meet your coach" at the finale (handled by the screen).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/onboarding/presentation/chat/domain/chat_types.dart';

final onboardingChatControllerProvider =
    StateNotifierProvider.autoDispose<OnboardingChatController, ChatState>(
  (ref) => OnboardingChatController()..start(),
);

class OnboardingChatController extends StateNotifier<ChatState> {
  OnboardingChatController() : super(ChatState.initial);

  // ── Timing ──────────────────────────────────────────────────────────────

  /// Short pause — used between tightly-related coach lines.
  static const Duration _shortPause = Duration(milliseconds: 650);

  /// Medium pause — gives the reader a beat before the next question.
  static const Duration _mediumPause = Duration(milliseconds: 950);

  /// Slightly longer pause when a card is about to render.
  static const Duration _cardPause = Duration(milliseconds: 1100);

  int _idCounter = 0;
  String _nextId() => 'msg_${_idCounter++}';

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ── Entry ───────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (state.messages.isNotEmpty) return;
    await _coachSays("Hi. I'm your coach.");
    await _coachSays('What should I call you?', pause: _mediumPause);
  }

  // ── Submissions — one per step ──────────────────────────────────────────

  Future<void> submitName(String rawName) async {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return;

    _userSays(trimmed);
    state = state.copyWith(
      profile: state.profile.copyWith(name: trimmed),
    );

    await _coachSays('Nice to meet you, $trimmed.');
    await _coachSays(
      'A few quick basics so I can do your health math right.',
      pause: _mediumPause,
    );
    await _coachSays('What best describes you?');
    _advanceTo(ChatStep.sex);
  }

  Future<void> submitSex(String sexId) async {
    _userSays(_sexLabel(sexId));
    state = state.copyWith(
      profile: state.profile.copyWith(sex: sexId),
    );

    await _coachSays('Got it.');
    await _coachSays('How old are you?', pause: _mediumPause);
    _advanceTo(ChatStep.age);
  }

  Future<void> submitAge(int age) async {
    _userSays('$age');
    state = state.copyWith(
      profile: state.profile.copyWith(age: age),
    );

    await _coachSays("$age — I'll use that for your heart-rate zones.");
    await _coachSays('How tall are you?', pause: _mediumPause);
    _advanceTo(ChatStep.height);
  }

  Future<void> submitHeight(int heightCm) async {
    _userSays('$heightCm cm');
    state = state.copyWith(
      profile: state.profile.copyWith(heightCm: heightCm.toDouble()),
    );

    await _coachSays('Thanks.');
    await _coachSays('And your weight?', pause: _mediumPause);
    _advanceTo(ChatStep.weight);
  }

  Future<void> submitWeight(int weightKg) async {
    _userSays('$weightKg kg');
    state = state.copyWith(
      profile: state.profile.copyWith(weightKg: weightKg.toDouble()),
    );

    await _coachSays('Perfect.');
    // Drop a BMR card right here — shows the user the coach is doing
    // real math with what they just shared.
    await _coachSends(ChatCardKind.bmr, pause: _cardPause);
    await _coachSays(
      "That's what your body burns at rest. We'll build on it from here.",
      pause: _mediumPause,
    );
    await _coachSays(
      'What matters most to you right now?',
      pause: _mediumPause,
    );
    _advanceTo(ChatStep.focus);
  }

  Future<void> submitFocus(String focusId) async {
    _userSays(_focusLabel(focusId));
    state = state.copyWith(
      profile: state.profile.copyWith(focus: focusId),
    );

    await _coachSays("${_focusLabel(focusId)} it is.");
    await _coachSays(_focusFollowUp(focusId), pause: _mediumPause);
    _advanceTo(ChatStep.goal);
  }

  Future<void> submitGoal(List<String> goals) async {
    if (goals.isEmpty) return;
    _userSays(goals.join(', '));
    state = state.copyWith(
      profile: state.profile.copyWith(goal: goals.join(', ')),
    );

    await _coachSays("Noted. I'll watch for that.");
    await _coachSays(
      'One more thing — how should I talk to you?',
      pause: _mediumPause,
    );
    _advanceTo(ChatStep.tone);
  }

  Future<void> submitTone(String toneId) async {
    _userSays(_toneLabel(toneId));
    state = state.copyWith(
      profile: state.profile.copyWith(tone: toneId),
    );

    await _coachSays(_toneAck(toneId));
    await _coachSays(
      "Last step — share your health history with me so I can start spotting patterns.",
      pause: _mediumPause,
    );
    _advanceTo(ChatStep.connect);
  }

  Future<void> submitHealthConnect({required bool granted}) async {
    _userSays(granted ? 'Connected' : 'Skip for now');
    state = state.copyWith(
      profile: state.profile.copyWith(healthConnected: granted),
    );

    if (granted) {
      await _coachSays("Done — I've got your history.");
    } else {
      await _coachSays("All good — you can connect any time from settings.");
    }
    await _coachSays(
      "Here's what I'll remember about you.",
      pause: _mediumPause,
    );
    await _coachSends(ChatCardKind.finaleProfile, pause: _cardPause);
    await _coachSays('Ready when you are.', pause: _mediumPause);
    _advanceTo(ChatStep.finale);
  }

  // ── Internal helpers ────────────────────────────────────────────────────

  Future<void> _coachSays(String text, {Duration? pause}) async {
    if (_disposed) return;
    _showTyping();
    await Future.delayed(pause ?? _shortPause);
    if (_disposed) return;
    _replaceTypingWith(
      ChatMessage(
        id: _nextId(),
        author: MessageAuthor.coach,
        kind: MessageKind.text,
        text: text,
      ),
    );
  }

  Future<void> _coachSends(ChatCardKind cardKind, {Duration? pause}) async {
    if (_disposed) return;
    _showTyping();
    await Future.delayed(pause ?? _cardPause);
    if (_disposed) return;
    _replaceTypingWith(
      ChatMessage(
        id: _nextId(),
        author: MessageAuthor.coach,
        kind: MessageKind.card,
        cardKind: cardKind,
      ),
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

  void _showTyping() {
    // Drop a typing placeholder at the end of the transcript.
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
  }

  void _replaceTypingWith(ChatMessage real) {
    final withoutTyping = state.messages
        .where((m) => m.kind != MessageKind.typing)
        .toList();
    state = state.copyWith(
      isCoachComposing: false,
      messages: [...withoutTyping, real],
    );
  }

  void _advanceTo(ChatStep step) {
    state = state.copyWith(currentStep: step);
  }

  // ── Label helpers ───────────────────────────────────────────────────────

  String _sexLabel(String id) {
    switch (id) {
      case 'female':
        return 'Female';
      case 'male':
        return 'Male';
      case 'other':
        return 'Other';
      default:
        return id;
    }
  }

  String _focusLabel(String id) {
    switch (id) {
      case 'sleep':
        return 'Sleep';
      case 'activity':
        return 'Activity';
      case 'nutrition':
        return 'Nutrition';
      case 'overall':
        return 'Overall wellness';
      default:
        return id;
    }
  }

  String _focusFollowUp(String id) {
    switch (id) {
      case 'sleep':
        return "What's one thing you'd change about your sleep?";
      case 'activity':
        return "What's one thing you'd change about how you move?";
      case 'nutrition':
        return "What's one thing you'd change about how you eat?";
      case 'overall':
        return "What's one thing you'd change to feel better overall?";
      default:
        return "What's one thing you'd like to change?";
    }
  }

  String _toneLabel(String id) {
    switch (id) {
      case 'direct':
        return 'Direct & data-driven';
      case 'warm':
        return 'Warm & encouraging';
      case 'minimal':
        return 'Minimal nudges';
      case 'thorough':
        return 'Thorough & detailed';
      default:
        return id;
    }
  }

  String _toneAck(String id) {
    switch (id) {
      case 'direct':
        return "Direct it is. I'll keep it to the numbers.";
      case 'warm':
        return "Warm it is. I've got you.";
      case 'minimal':
        return "Minimal it is. I'll only chime in when it matters.";
      case 'thorough':
        return "Thorough it is. You'll get the full picture.";
      default:
        return "Got it.";
    }
  }
}
