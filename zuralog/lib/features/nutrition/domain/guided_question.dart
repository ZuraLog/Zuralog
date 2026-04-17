/// ZuraLog — Guided Meal Walkthrough Domain Model.
///
/// Defines the shapes used by the Question Walkthrough screen. The backend
/// returns a list of [GuidedQuestion] items alongside the parsed foods.
/// Each question specifies which visual component it wants, plus defaults
/// and validation bounds.
library;

import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';

// ── GuidedComponentType ─────────────────────────────────────────────────────

/// Which interactive component a [GuidedQuestion] should render.
///
/// Each value carries a backend [wire] identifier used for serialising to and
/// from JSON, so the UI and backend stay in lock-step as new components are
/// added.
enum GuidedComponentType {
  /// Continuous range picker (min/max/step).
  slider('slider'),

  /// Single-select chip group.
  buttonGroup('button_group'),

  /// Integer plus/minus stepper.
  numberStepper('number_stepper'),

  /// Size chips (XS/S/M/L/XL) delegating to the button group visually.
  sizePicker('size_picker'),

  /// Binary yes/no picker.
  yesNo('yes_no'),

  /// Multi-line free-text input.
  freeText('free_text'),

  /// Fallback for component types the client does not recognise.
  unknown('unknown');

  const GuidedComponentType(this.wire);

  /// Backend wire identifier for this component type.
  final String wire;

  /// Parses a component type from the backend wire identifier.
  ///
  /// Returns [GuidedComponentType.unknown] for null or unrecognised values so
  /// the walkthrough can still render a safe fallback.
  static GuidedComponentType fromWire(String? value) {
    if (value == null) return GuidedComponentType.unknown;
    for (final type in GuidedComponentType.values) {
      if (type.wire == value) return type;
    }
    return GuidedComponentType.unknown;
  }
}

// ── GuidedQuestion ──────────────────────────────────────────────────────────

/// A single question shown during the guided meal walkthrough.
///
/// Defaults and bounds are all optional — the UI renders whatever the backend
/// provides and falls back to safe defaults otherwise. [skippedByRule] is set
/// by the backend when a user's rule already answered this question, so the
/// client can show a small "Applied your rule" badge if desired.
class GuidedQuestion {
  /// Creates an immutable [GuidedQuestion].
  const GuidedQuestion({
    required this.id,
    required this.foodIndex,
    required this.question,
    required this.componentType,
    this.options,
    this.defaultValue,
    this.skippedByRule,
    this.min,
    this.max,
    this.step,
    this.unit,
  });

  /// Stable identifier for this question (used as answer map key).
  final String id;

  /// Index of the food this question refers to in the parsed foods list.
  final int foodIndex;

  /// The human-readable question text shown to the user.
  final String question;

  /// Which interactive component to render.
  final GuidedComponentType componentType;

  /// Choices for [GuidedComponentType.buttonGroup] and
  /// [GuidedComponentType.sizePicker] questions.
  final List<String>? options;

  /// The initial / skip value for this question.
  final Object? defaultValue;

  /// If non-null, this question was skipped by the backend because a user rule
  /// already answered it. The client may display a small "Applied your rule"
  /// label using this text.
  final String? skippedByRule;

  /// Minimum numeric value for slider / stepper questions.
  final double? min;

  /// Maximum numeric value for slider / stepper questions.
  final double? max;

  /// Step size for slider / stepper questions.
  final double? step;

  /// Optional unit label (e.g. `'g'`, `'tbsp'`).
  final String? unit;

  /// Deserialises a [GuidedQuestion] defensively from a backend JSON map.
  ///
  /// Every field except [id] and [question] tolerates null or missing values.
  factory GuidedQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final List<String>? parsedOptions = rawOptions is List
        ? rawOptions
            .whereType<Object>()
            .map((e) => e.toString())
            .toList(growable: false)
        : null;

    return GuidedQuestion(
      id: json['id'] as String? ?? '',
      foodIndex: (json['food_index'] as num?)?.toInt() ?? 0,
      question: json['question'] as String? ?? '',
      componentType: GuidedComponentType.fromWire(
        json['component_type'] as String?,
      ),
      options: parsedOptions,
      defaultValue: json['default_value'],
      skippedByRule: json['skipped_by_rule'] as String?,
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
      step: (json['step'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
    );
  }
}

// ── MealWalkthroughArgs ─────────────────────────────────────────────────────

/// Arguments passed to the Meal Walkthrough screen via route navigation.
///
/// The screen walks through [questions] one at a time, accumulates answers,
/// and returns them to the caller via `context.pop(answers)`.
class MealWalkthroughArgs {
  /// Creates an immutable [MealWalkthroughArgs].
  const MealWalkthroughArgs({
    required this.questions,
    required this.foods,
    this.initialAnswers = const {},
  });

  /// The ordered list of questions to ask.
  final List<GuidedQuestion> questions;

  /// The parsed foods each question refers to by index.
  final List<ParsedFoodItem> foods;

  /// Optional pre-filled answers keyed by question id.
  final Map<String, dynamic> initialAnswers;
}
