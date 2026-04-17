/// ZuraLog — Guided Meal Walkthrough Domain Model.
///
/// Defines the shapes used by the Question Walkthrough screen. The backend
/// returns a list of [GuidedQuestion] items alongside the parsed foods.
/// Each question specifies which visual component it wants, plus defaults
/// and validation bounds.
library;

import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';

// ── OnAnswerFood ────────────────────────────────────────────────────────────

/// A lightweight food payload embedded in an [OnAnswerOp].
///
/// Mirrors the shape of [ParsedFoodItem] but only carries the fields needed
/// for an `add_food` or `replace_food` operation. The backend emits one of
/// these inside every `on_answer` recipe so the client can mint a new
/// [ParsedFoodItem] locally without a network round trip.
class OnAnswerFood {
  /// Creates an immutable [OnAnswerFood].
  const OnAnswerFood({
    required this.foodName,
    required this.portionAmount,
    required this.portionUnit,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  /// Human-readable food name.
  final String foodName;

  /// Portion size in the given [portionUnit].
  final double portionAmount;

  /// Unit of measurement for the portion (e.g. `'g'`, `'tsp'`, `'tbsp'`).
  final String portionUnit;

  /// Energy content in kilocalories.
  final double calories;

  /// Protein content in grams.
  final double proteinG;

  /// Carbohydrate content in grams.
  final double carbsG;

  /// Fat content in grams.
  final double fatG;

  /// Deserialises an [OnAnswerFood] defensively from a backend JSON map.
  ///
  /// Every field tolerates null / missing values so a malformed LLM payload
  /// never throws — the surrounding parser falls through to [NoOpOp.instance]
  /// when this factory returns default values it cannot use.
  factory OnAnswerFood.fromJson(Map<String, dynamic> json) {
    return OnAnswerFood(
      foodName: json['food_name'] as String? ?? '',
      portionAmount: (json['portion_amount'] as num?)?.toDouble() ?? 0.0,
      portionUnit: json['portion_unit'] as String? ?? 'g',
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Builds a [ParsedFoodItem] from this payload with attribution fields set.
  ///
  /// [sourceQuestionId] and [sourceAnswerValue] are persisted on the returned
  /// [ParsedFoodItem] so the UI can show a "From your answer" badge and open
  /// a detail sheet tracing the food back to the walkthrough question.
  ParsedFoodItem toParsedFoodItem({
    required String sourceQuestionId,
    required String sourceAnswerValue,
  }) {
    return ParsedFoodItem(
      foodName: foodName,
      portionAmount: portionAmount,
      portionUnit: portionUnit,
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      origin: 'from_answer',
      sourceQuestionId: sourceQuestionId,
      sourceAnswerValue: sourceAnswerValue,
    );
  }
}

// ── OnAnswerOp ──────────────────────────────────────────────────────────────

/// Sealed hierarchy describing one deterministic operation the client should
/// apply when the user picks a given answer in the guided walkthrough.
///
/// The backend embeds a [Map<String, OnAnswerOp>] in every [GuidedQuestion]
/// so the walkthrough screen can update its working food list instantly,
/// without another AI call.
sealed class OnAnswerOp {
  const OnAnswerOp();

  /// Parses an [OnAnswerOp] defensively from a backend JSON map.
  ///
  /// Unknown, missing, or malformed payloads always fall through to
  /// [NoOpOp.instance] so the walkthrough never crashes on hostile input.
  factory OnAnswerOp.fromJson(Map<String, dynamic> json) {
    try {
      final op = json['op'];
      switch (op) {
        case 'add_food':
          final food = json['food'];
          if (food is! Map<String, dynamic>) return NoOpOp.instance;
          return AddFoodOp(food: OnAnswerFood.fromJson(food));
        case 'scale_food':
          final factor = ((json['factor'] as num?) ?? 1.0)
              .toDouble()
              .clamp(0.1, 10.0);
          return ScaleFoodOp(factor: factor);
        case 'replace_food':
          final food = json['food'];
          if (food is! Map<String, dynamic>) return NoOpOp.instance;
          return ReplaceFoodOp(food: OnAnswerFood.fromJson(food));
        case 'no_op':
          return NoOpOp.instance;
        default:
          return NoOpOp.instance;
      }
    } catch (_) {
      // Never throw on malformed JSON — walkthrough must keep going.
      return NoOpOp.instance;
    }
  }
}

/// Append a new [ParsedFoodItem] (built from [food]) to the working list.
class AddFoodOp extends OnAnswerOp {
  /// Creates an [AddFoodOp] carrying the food to append.
  const AddFoodOp({required this.food});

  /// The food payload to mint into a [ParsedFoodItem].
  final OnAnswerFood food;
}

/// Scale the referenced food's portion and macros by [factor].
///
/// Factor is pre-clamped by [OnAnswerOp.fromJson] to the range `[0.1, 10.0]`.
class ScaleFoodOp extends OnAnswerOp {
  /// Creates a [ScaleFoodOp] with the given multiplier.
  const ScaleFoodOp({required this.factor});

  /// Multiplier applied to portion / calories / macros.
  final double factor;
}

/// Replace the referenced food with a new [ParsedFoodItem] (built from [food]).
class ReplaceFoodOp extends OnAnswerOp {
  /// Creates a [ReplaceFoodOp] carrying the replacement food.
  const ReplaceFoodOp({required this.food});

  /// The food payload to mint into a [ParsedFoodItem].
  final OnAnswerFood food;
}

/// No-op — the answer does not change the food list.
///
/// Implemented as a singleton because every `no_op` is interchangeable.
class NoOpOp extends OnAnswerOp {
  const NoOpOp._();

  /// Canonical instance — always reuse instead of constructing a new one.
  static const NoOpOp instance = NoOpOp._();
}

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
    this.onAnswer,
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

  /// Per-answer adjustment recipe.
  ///
  /// Keys are answer values as strings (`"yes"`, `"no"`, a button label, a
  /// numeric slider value rendered as a string, etc.). Values are the ops the
  /// client should apply when the user picks that answer. `null` means the
  /// backend did not emit a recipe for this question — the client should
  /// fall back to its legacy heuristics.
  final Map<String, OnAnswerOp>? onAnswer;

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

    final rawOnAnswer = json['on_answer'];
    Map<String, OnAnswerOp>? parsedOnAnswer;
    if (rawOnAnswer is Map) {
      final built = <String, OnAnswerOp>{};
      rawOnAnswer.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          built[key.toString()] = OnAnswerOp.fromJson(value);
        } else if (value is Map) {
          // Defensive cast for `Map<dynamic, dynamic>` coming from jsonDecode.
          built[key.toString()] =
              OnAnswerOp.fromJson(Map<String, dynamic>.from(value));
        }
        // Skip entries whose value is not a map.
      });
      parsedOnAnswer = built.isEmpty ? null : built;
    }

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
      onAnswer: parsedOnAnswer,
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
