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
    await _coachSays('When were you born?', pause: _mediumPause);
    _advanceTo(ChatStep.birthday);
  }

  Future<void> submitBirthday(DateTime birthday) async {
    final age = _ageFromBirthday(birthday);
    final formatted = _formatBirthday(birthday);
    _userSays(formatted);
    state = state.copyWith(
      profile: state.profile.copyWith(birthday: birthday),
    );

    await _coachSays("You're $age — I'll keep that for your health math.");
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
    // Drop a focus-preview card — shows a chart tailored to the picked
    // category so the abstract "Sleep" or "Activity" answer immediately
    // gets a visual payoff.
    await _coachSends(ChatCardKind.focusPreview, pause: _cardPause);
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
    // Drop a sample message card so the user sees what the chosen tone
    // actually sounds like — makes the abstract pick land concretely.
    await _coachSends(ChatCardKind.toneSample, pause: _cardPause);
    await _coachSays(
      'A few more quick ones so I can actually be useful.',
      pause: _mediumPause,
    );
    await _coachSays('Any dietary style I should stick to?');
    _advanceTo(ChatStep.diet);
  }

  /// Called by the dietary-restrictions multi-select. Empty list means
  /// the user tapped "None" (i.e. no restrictions).
  Future<void> submitDiet(List<String> tags) async {
    _userSays(_dietEcho(tags));
    state = state.copyWith(
      profile: state.profile.copyWith(dietaryRestrictions: tags),
    );

    await _coachSays(
      tags.isEmpty ? "Good to know — no restrictions." : "Got it.",
    );
    await _coachSays(
      "Anything I should avoid suggesting because of an injury?",
      pause: _mediumPause,
    );
    _advanceTo(ChatStep.limitations);
  }

  /// Called by the injuries/limitations multi-select. Empty list means
  /// the user tapped "I'm good".
  Future<void> submitLimitations(List<String> tags) async {
    _userSays(_injuriesEcho(tags));
    state = state.copyWith(
      profile: state.profile.copyWith(injuries: tags),
    );

    await _coachSays(
      tags.isEmpty
          ? "Perfect — I'll program without limitations."
          : "Noted — I'll steer clear.",
    );
    await _coachSays(
      "Where are you at with training right now?",
      pause: _mediumPause,
    );
    _advanceTo(ChatStep.training);
  }

  /// Called by the training-experience single-select. Maps to
  /// user_preferences.fitness_level on the backend.
  Future<void> submitTraining(String levelId) async {
    _userSays(trainingLabels[levelId] ?? levelId);
    state = state.copyWith(
      profile: state.profile.copyWith(trainingExperience: levelId),
    );

    await _coachSays("Good to know — I'll pitch things at that level.");
    await _coachSays("How's your sleep usually?", pause: _mediumPause);
    _advanceTo(ChatStep.sleep);
  }

  /// Called by the sleep-pattern single-select.
  Future<void> submitSleep(String patternId) async {
    _userSays(sleepLabels[patternId] ?? patternId);
    state = state.copyWith(
      profile: state.profile.copyWith(sleepPattern: patternId),
    );

    await _coachSays(_sleepAck(patternId));
    await _coachSays(
      "Last one — what's the biggest thing in your way?",
      pause: _mediumPause,
    );
    await _coachSays(
      "One sentence is fine, or skip.",
    );
    _advanceTo(ChatStep.frustration);
  }

  /// Called by the biggest-frustration free-text input. Pass null for a
  /// skip; pass a non-empty string for a real answer.
  Future<void> submitFrustration(String? text) async {
    final cleaned = text?.trim();
    if (cleaned != null && cleaned.isNotEmpty) {
      _userSays(cleaned);
      state = state.copyWith(
        profile: state.profile.copyWith(healthFrustration: cleaned),
      );
      await _coachSays("Thanks — I'll keep that front of mind.");
    } else {
      _userSays('Skip');
      await _coachSays("All good — you can tell me later.");
    }

    await _coachSays(
      'Now let\'s hook up your health data so I can start spotting patterns.',
      pause: _mediumPause,
    );
    await _coachSays(
      'Pick any apps you already use — you can add more later.',
    );
    _advanceTo(ChatStep.connect);
  }

  /// Called by the integrations picker when the user submits their set
  /// (an empty list means they tapped "Skip for now").
  Future<void> submitIntegrations(List<String> integrationIds) async {
    if (integrationIds.isEmpty) {
      _userSays('Skip for now');
      await _coachSays(
        "All good — you can connect your health apps any time from Settings.",
      );
    } else {
      _userSays(_formatIntegrationList(integrationIds));
      state = state.copyWith(
        profile: state.profile.copyWith(
          connectedIntegrations: integrationIds,
        ),
      );
      if (integrationIds.length == 1) {
        await _coachSays(
          "Nice — I'll pull from ${_integrationName(integrationIds.first)}.",
        );
      } else {
        await _coachSays(
          "Nice — I'll pull from all ${integrationIds.length}.",
        );
      }
    }

    await _coachSays(
      'Last quick one — where did you hear about us?',
      pause: _mediumPause,
    );
    _advanceTo(ChatStep.source);
  }

  /// Called by the discovery-source pill input.
  Future<void> submitDiscoverySource(String sourceId) async {
    _userSays(_sourceLabel(sourceId));
    state = state.copyWith(
      profile: state.profile.copyWith(discoverySource: sourceId),
    );

    await _coachSays("Good to know — thanks.");
    // The coach takes initiative — plays a short autonomous action
    // card to demo what it can DO for the user, not just observe.
    await _coachSays(
      "Hang on, let me get a few things set up for you...",
      pause: _mediumPause,
    );
    await _coachSends(ChatCardKind.autonomousAction, pause: _cardPause);
    await _coachSays(
      'All set.',
      // Longer pause lets the ~3.8s card animation land visually
      // before the coach speaks again.
      pause: const Duration(milliseconds: 4200),
    );
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
        return "Direct it is.";
      case 'warm':
        return "Warm it is.";
      case 'minimal':
        return "Minimal it is.";
      case 'thorough':
        return "Thorough it is.";
      default:
        return "Got it.";
    }
  }

  static int _ageFromBirthday(DateTime birthday) {
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
  }

  static String _formatBirthday(DateTime birthday) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[birthday.month - 1]} ${birthday.day}, ${birthday.year}';
  }

  // ── Integration / source label helpers ──────────────────────────────────

  String _integrationName(String id) {
    switch (id) {
      case 'apple_health':
        return 'Apple Health';
      case 'oura':
        return 'Oura';
      case 'strava':
        return 'Strava';
      case 'fitbit':
        return 'Fitbit';
      default:
        return id;
    }
  }

  String _formatIntegrationList(List<String> ids) {
    final names = ids.map(_integrationName).toList();
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} & ${names[1]}';
    final last = names.removeLast();
    return '${names.join(', ')} & $last';
  }

  // ── Shared option maps (reused by catch-up flow) ────────────────────────

  /// Human labels for the training-experience pick. Also used by the
  /// catch-up flow and the About You settings screen.
  static const Map<String, String> trainingLabels = {
    'beginner': 'New to this',
    'active': 'Consistently active',
    'athletic': 'Highly trained',
  };

  /// Human labels for the sleep-pattern pick.
  static const Map<String, String> sleepLabels = {
    'great': 'I sleep great',
    'hard_to_fall_asleep': 'Hard to fall asleep',
    'wake_up_a_lot': 'Wake up a lot',
    'short_hours': 'Short hours',
  };

  String _dietEcho(List<String> tags) {
    if (tags.isEmpty) return 'No restrictions';
    return tags.join(', ');
  }

  String _injuriesEcho(List<String> tags) {
    if (tags.isEmpty) return "I'm good";
    return tags.join(', ');
  }

  String _sleepAck(String id) {
    switch (id) {
      case 'great':
        return "That's a great foundation to build on.";
      case 'hard_to_fall_asleep':
        return "Got it — falling asleep can be tough. We'll work on that.";
      case 'wake_up_a_lot':
        return "Noted — those wake-ups add up. We'll look at the pattern.";
      case 'short_hours':
        return "Understood — we'll see if we can find you a bit more.";
      default:
        return "Got it.";
    }
  }

  String _sourceLabel(String id) {
    switch (id) {
      case 'friend':
        return 'Friend';
      case 'instagram':
        return 'Instagram';
      case 'tiktok':
        return 'TikTok';
      case 'podcast':
        return 'Podcast';
      case 'app_store':
        return 'App Store';
      case 'doctor':
        return 'Doctor';
      case 'other':
        return 'Somewhere else';
      default:
        return id;
    }
  }
}
