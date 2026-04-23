/// Zuralog — Chat Onboarding Domain Types.
///
/// The data model behind the conversation. Kept minimal and const-friendly
/// so the chat state is cheap to copy and diff for Riverpod.
library;

/// Who owns a message bubble.
enum MessageAuthor { coach, user }

/// The kind of content a message holds. Keeps the UI layer switchable
/// without touching the controller.
enum MessageKind {
  /// Plain text from the coach or the user.
  text,

  /// The coach is composing — shows a typing indicator.
  typing,

  /// A rich card (BMR, focus preview, activity baseline, finale profile).
  card,
}

/// Which card variant to render when [MessageKind.card] is used.
enum ChatCardKind {
  bmr,
  focusPreview,
  activityBaseline,
  toneSample,
  autonomousAction,
  finaleProfile,
}

/// The ordered conversation steps. Index in this enum doubles as the
/// progress counter for the top progress dots.
enum ChatStep {
  name,
  sex,
  birthday,
  height,
  weight,
  focus,
  goal,
  tone,
  // Extended profile (landed after tone so the AI has full context before
  // the integrations step).
  diet,
  limitations,
  training,
  sleep,
  frustration,
  // Tail of flow
  connect,
  source,
  finale,
}

/// A single message rendered in the chat transcript.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.kind,
    this.text = '',
    this.cardKind,
  });

  /// Stable identity used by Flutter's list diffing.
  final String id;
  final MessageAuthor author;
  final MessageKind kind;

  /// Display text when [kind] is [MessageKind.text]. Empty otherwise.
  final String text;

  /// Which card to render when [kind] is [MessageKind.card].
  final ChatCardKind? cardKind;
}

/// What the user has told the coach so far. Grows as the conversation
/// advances. All fields are optional because the user can arrive at any
/// [ChatStep] with only the earlier ones filled.
class OnboardingProfile {
  const OnboardingProfile({
    this.name,
    this.sex,
    this.birthday,
    this.heightCm,
    this.weightKg,
    this.focus,
    this.goal,
    this.tone,
    this.dietaryRestrictions = const <String>[],
    this.injuries = const <String>[],
    this.trainingExperience,
    this.sleepPattern,
    this.healthFrustration,
    this.connectedIntegrations = const <String>[],
    this.discoverySource,
  });

  final String? name;
  final String? sex;
  final DateTime? birthday;
  final double? heightCm;
  final double? weightKg;
  final String? focus;
  final String? goal;
  final String? tone;

  /// Selected dietary tags. Empty list means "no restrictions" (user picked
  /// the exclusive "None" option).
  final List<String> dietaryRestrictions;

  /// Selected injury/limitation tags. Empty list means "no limitations"
  /// (user picked the exclusive "I'm good" option).
  final List<String> injuries;

  /// Self-assessed training experience — maps 1:1 to
  /// user_preferences.fitness_level on the backend.
  /// One of: 'beginner', 'active', 'athletic'.
  final String? trainingExperience;

  /// Sleep pattern keyword.
  /// One of: 'great', 'hard_to_fall_asleep', 'wake_up_a_lot', 'short_hours'.
  final String? sleepPattern;

  /// Short free-text description of the user's biggest blocker.
  final String? healthFrustration;

  /// Integration IDs the user opted into on the connect step.
  /// Empty list = they tapped Skip.
  final List<String> connectedIntegrations;

  /// How the user found Zuralog (analytics-grade optional question).
  final String? discoverySource;

  bool get hasAnyIntegration => connectedIntegrations.isNotEmpty;

  OnboardingProfile copyWith({
    String? name,
    String? sex,
    DateTime? birthday,
    double? heightCm,
    double? weightKg,
    String? focus,
    String? goal,
    String? tone,
    List<String>? dietaryRestrictions,
    List<String>? injuries,
    String? trainingExperience,
    String? sleepPattern,
    String? healthFrustration,
    List<String>? connectedIntegrations,
    String? discoverySource,
  }) {
    return OnboardingProfile(
      name: name ?? this.name,
      sex: sex ?? this.sex,
      birthday: birthday ?? this.birthday,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      focus: focus ?? this.focus,
      goal: goal ?? this.goal,
      tone: tone ?? this.tone,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      injuries: injuries ?? this.injuries,
      trainingExperience: trainingExperience ?? this.trainingExperience,
      sleepPattern: sleepPattern ?? this.sleepPattern,
      healthFrustration: healthFrustration ?? this.healthFrustration,
      connectedIntegrations:
          connectedIntegrations ?? this.connectedIntegrations,
      discoverySource: discoverySource ?? this.discoverySource,
    );
  }
}

/// Full chat state: the ordered transcript + the user's current answers +
/// what step the coach is currently asking for + whether the coach is
/// "composing" (shows a typing indicator in lieu of the input area).
class ChatState {
  const ChatState({
    required this.messages,
    required this.profile,
    required this.currentStep,
    required this.isCoachComposing,
  });

  final List<ChatMessage> messages;
  final OnboardingProfile profile;
  final ChatStep currentStep;
  final bool isCoachComposing;

  ChatState copyWith({
    List<ChatMessage>? messages,
    OnboardingProfile? profile,
    ChatStep? currentStep,
    bool? isCoachComposing,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      profile: profile ?? this.profile,
      currentStep: currentStep ?? this.currentStep,
      isCoachComposing: isCoachComposing ?? this.isCoachComposing,
    );
  }

  static const ChatState initial = ChatState(
    messages: [],
    profile: OnboardingProfile(),
    currentStep: ChatStep.name,
    isCoachComposing: false,
  );
}
