/// Zuralog — Workout Session Domain Models.
///
/// Immutable value types for an in-progress workout session. Persisted as
/// JSON in SharedPreferences under `workout_active_draft` so the session
/// survives a crash or accidental app kill.
///
/// Root-to-leaf:
/// - [WorkoutSession]  — active session (uuid + startedAt + exercises).
/// - [WorkoutExercise] — one exercise added by the user.
/// - [WorkoutSet]      — one set on one exercise.
/// - [SetType]         — classification (Warm-Up, Working, Drop Set,
///                       Failure, AMRAP).
library;

import 'package:flutter/foundation.dart' show listEquals;

enum SetType {
  warmUp(label: 'Warm-Up'),
  working(label: 'Working'),
  dropSet(label: 'Drop Set'),
  failure(label: 'Failure'),
  amrap(label: 'AMRAP');

  const SetType({required this.label});

  final String label;

  static SetType fromName(String input) {
    for (final t in SetType.values) {
      if (t.name == input) return t;
    }
    return SetType.working;
  }
}

const Object _kUnset = Object();

class WorkoutSet {
  const WorkoutSet({
    required this.setNumber,
    required this.type,
    this.weightValue,
    this.reps,
    this.isCompleted = false,
    this.previousRecord,
  });

  final int setNumber;
  final SetType type;
  final double? weightValue;
  final int? reps;
  final bool isCompleted;
  final String? previousRecord;

  WorkoutSet copyWith({
    int? setNumber,
    SetType? type,
    Object? weightValue = _kUnset,
    Object? reps = _kUnset,
    bool? isCompleted,
    Object? previousRecord = _kUnset,
    bool clearWeightValue = false,
    bool clearReps = false,
    bool clearPreviousRecord = false,
  }) {
    return WorkoutSet(
      setNumber: setNumber ?? this.setNumber,
      type: type ?? this.type,
      weightValue: clearWeightValue
          ? null
          : (identical(weightValue, _kUnset)
              ? this.weightValue
              : (weightValue as num?)?.toDouble()),
      reps: clearReps
          ? null
          : (identical(reps, _kUnset) ? this.reps : (reps as num?)?.toInt()),
      isCompleted: isCompleted ?? this.isCompleted,
      previousRecord: clearPreviousRecord
          ? null
          : (identical(previousRecord, _kUnset)
              ? this.previousRecord
              : previousRecord as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'type': type.name,
        'weightValue': weightValue,
        'reps': reps,
        'isCompleted': isCompleted,
        'previousRecord': previousRecord,
      };

  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
        setNumber: (json['setNumber'] as num?)?.toInt() ?? 1,
        type: SetType.fromName(json['type'] as String? ?? 'working'),
        weightValue: (json['weightValue'] as num?)?.toDouble(),
        reps: (json['reps'] as num?)?.toInt(),
        isCompleted: json['isCompleted'] as bool? ?? false,
        previousRecord: json['previousRecord'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSet &&
          other.setNumber == setNumber &&
          other.type == type &&
          other.weightValue == weightValue &&
          other.reps == reps &&
          other.isCompleted == isCompleted &&
          other.previousRecord == previousRecord);

  @override
  int get hashCode => Object.hash(
        setNumber,
        type,
        weightValue,
        reps,
        isCompleted,
        previousRecord,
      );
}

class WorkoutExercise {
  const WorkoutExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    required this.sets,
    this.notes = '',
    this.restTimerEnabled = true,
    this.restTimerWarmUpSeconds = 90,
    this.restTimerWorkingSeconds = 90,
    this.unitOverride,
  });

  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final List<WorkoutSet> sets;
  final String notes;
  final bool restTimerEnabled;
  final int restTimerWarmUpSeconds;
  final int restTimerWorkingSeconds;
  final String? unitOverride;

  WorkoutExercise copyWith({
    String? exerciseId,
    String? exerciseName,
    String? muscleGroup,
    List<WorkoutSet>? sets,
    String? notes,
    bool? restTimerEnabled,
    int? restTimerWarmUpSeconds,
    int? restTimerWorkingSeconds,
    Object? unitOverride = _kUnset,
    bool clearUnitOverride = false,
  }) {
    return WorkoutExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      sets: sets ?? this.sets,
      notes: notes ?? this.notes,
      restTimerEnabled: restTimerEnabled ?? this.restTimerEnabled,
      restTimerWarmUpSeconds:
          restTimerWarmUpSeconds ?? this.restTimerWarmUpSeconds,
      restTimerWorkingSeconds:
          restTimerWorkingSeconds ?? this.restTimerWorkingSeconds,
      unitOverride: clearUnitOverride
          ? null
          : (identical(unitOverride, _kUnset)
              ? this.unitOverride
              : unitOverride as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'muscleGroup': muscleGroup,
        'sets': sets.map((s) => s.toJson()).toList(growable: false),
        'notes': notes,
        'restTimerEnabled': restTimerEnabled,
        'restTimerWarmUpSeconds': restTimerWarmUpSeconds,
        'restTimerWorkingSeconds': restTimerWorkingSeconds,
        'unitOverride': unitOverride,
      };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) =>
      WorkoutExercise(
        exerciseId: json['exerciseId'] as String? ?? '',
        exerciseName: json['exerciseName'] as String? ?? '',
        muscleGroup: json['muscleGroup'] as String? ?? 'other',
        sets: ((json['sets'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WorkoutSet.fromJson)
            .toList(growable: false),
        notes: json['notes'] as String? ?? '',
        restTimerEnabled: json['restTimerEnabled'] as bool? ?? true,
        restTimerWarmUpSeconds:
            (json['restTimerWarmUpSeconds'] as num?)?.toInt() ?? 90,
        restTimerWorkingSeconds:
            (json['restTimerWorkingSeconds'] as num?)?.toInt() ?? 90,
        unitOverride: json['unitOverride'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutExercise &&
          other.exerciseId == exerciseId &&
          other.exerciseName == exerciseName &&
          other.muscleGroup == muscleGroup &&
          listEquals(other.sets, sets) &&
          other.notes == notes &&
          other.restTimerEnabled == restTimerEnabled &&
          other.restTimerWarmUpSeconds == restTimerWarmUpSeconds &&
          other.restTimerWorkingSeconds == restTimerWorkingSeconds &&
          other.unitOverride == unitOverride);

  @override
  int get hashCode => Object.hash(
        exerciseId,
        exerciseName,
        muscleGroup,
        Object.hashAll(sets),
        notes,
        restTimerEnabled,
        restTimerWarmUpSeconds,
        restTimerWorkingSeconds,
        unitOverride,
      );
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.startedAt,
    required this.exercises,
  });

  final String id;
  final DateTime startedAt;
  final List<WorkoutExercise> exercises;

  WorkoutSession copyWith({
    String? id,
    DateTime? startedAt,
    List<WorkoutExercise>? exercises,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      exercises: exercises ?? this.exercises,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'exercises':
            exercises.map((e) => e.toJson()).toList(growable: false),
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) =>
      WorkoutSession(
        id: json['id'] as String? ?? '',
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
        exercises: ((json['exercises'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WorkoutExercise.fromJson)
            .toList(growable: false),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSession &&
          other.id == id &&
          other.startedAt == startedAt &&
          listEquals(other.exercises, exercises));

  @override
  int get hashCode => Object.hash(id, startedAt, Object.hashAll(exercises));
}

/// Returns the effective unit system for [exercise]: the per-exercise
/// override if set, otherwise the caller-provided global default.
String effectiveUnitSystem(WorkoutExercise exercise, String globalDefault) =>
    exercise.unitOverride ?? globalDefault;

/// Returns "kg" or "lbs" for use as a TextField suffix.
String unitLabel(String unitSystem) =>
    unitSystem == 'imperial' ? 'lbs' : 'kg';

/// Converts kilograms to pounds.
double kgToLbs(double kg) => kg * 2.2046226218;

/// Converts pounds to kilograms.
double lbsToKg(double lbs) => lbs / 2.2046226218;
