/// Zuralog — Completed Workout Domain Model.
///
/// Immutable value objects representing a workout that was *finished*,
/// not an in-progress session. Persisted as JSON in SharedPreferences under
/// `workout_history`, newest first, capped at 100 entries by
/// `WorkoutHistoryRepository`.
///
/// Root-to-leaf:
/// - [CompletedWorkout]  — one finished workout (uuid + timestamp + totals).
/// - [CompletedExercise] — one exercise as completed.
/// - [WorkoutSet] (from workout_session.dart) — reused as-is.
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:uuid/uuid.dart';

import 'package:zuralog/features/workout/domain/workout_session.dart';

const _uuid = Uuid();

class CompletedExercise {
  const CompletedExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    required this.sets,
    this.unitOverride,
  });

  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final List<WorkoutSet> sets;
  final String? unitOverride;

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'muscleGroup': muscleGroup,
        'sets': sets.map((s) => s.toJson()).toList(growable: false),
        'unitOverride': unitOverride,
      };

  factory CompletedExercise.fromJson(Map<String, dynamic> json) =>
      CompletedExercise(
        exerciseId: json['exerciseId'] as String? ?? '',
        exerciseName: json['exerciseName'] as String? ?? '',
        muscleGroup: json['muscleGroup'] as String? ?? 'other',
        sets: ((json['sets'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WorkoutSet.fromJson)
            .toList(growable: false),
        unitOverride: json['unitOverride'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompletedExercise &&
          other.exerciseId == exerciseId &&
          other.exerciseName == exerciseName &&
          other.muscleGroup == muscleGroup &&
          listEquals(other.sets, sets) &&
          other.unitOverride == unitOverride);

  @override
  int get hashCode => Object.hash(
        exerciseId,
        exerciseName,
        muscleGroup,
        Object.hashAll(sets),
        unitOverride,
      );
}

class CompletedWorkout {
  const CompletedWorkout({
    required this.id,
    required this.completedAt,
    required this.durationSeconds,
    required this.exercises,
    required this.totalVolumeKg,
    required this.totalSetsCompleted,
  });

  final String id;
  final DateTime completedAt;
  final int durationSeconds;
  final List<CompletedExercise> exercises;
  final double totalVolumeKg;
  final int totalSetsCompleted;

  Duration get duration => Duration(seconds: durationSeconds);

  Map<String, dynamic> toJson() => {
        'id': id,
        'completedAt': completedAt.toUtc().toIso8601String(),
        'durationSeconds': durationSeconds,
        'exercises': exercises.map((e) => e.toJson()).toList(growable: false),
        'totalVolumeKg': totalVolumeKg,
        'totalSetsCompleted': totalSetsCompleted,
      };

  factory CompletedWorkout.fromJson(Map<String, dynamic> json) =>
      CompletedWorkout(
        id: json['id'] as String? ?? '',
        completedAt:
            DateTime.tryParse(json['completedAt'] as String? ?? '')?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        exercises: ((json['exercises'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CompletedExercise.fromJson)
            .toList(growable: false),
        totalVolumeKg: (json['totalVolumeKg'] as num?)?.toDouble() ?? 0.0,
        totalSetsCompleted:
            (json['totalSetsCompleted'] as num?)?.toInt() ?? 0,
      );

  /// Builds a [CompletedWorkout] from a live session. Normalizes every
  /// completed set's weight into kilograms using each exercise's
  /// `unitOverride` (falling back to [globalUnitSystem]).
  factory CompletedWorkout.fromSession(
    WorkoutSession session, {
    required DateTime completedAt,
    required String globalUnitSystem,
  }) {
    var totalKg = 0.0;
    var totalSets = 0;
    final completedExercises = session.exercises.map((ex) {
      final unit = ex.unitOverride ?? globalUnitSystem;
      for (final s in ex.sets) {
        if (!s.isCompleted) continue;
        final w = s.weightValue;
        final r = s.reps;
        if (w == null || r == null) {
          totalSets++;
          continue;
        }
        final kg = unit == 'imperial' ? lbsToKg(w) : w;
        totalKg += kg * r;
        totalSets++;
      }
      return CompletedExercise(
        exerciseId: ex.exerciseId,
        exerciseName: ex.exerciseName,
        muscleGroup: ex.muscleGroup,
        sets: List<WorkoutSet>.unmodifiable(ex.sets),
        unitOverride: ex.unitOverride,
      );
    }).toList(growable: false);

    final startUtc = session.startedAt.toUtc();
    final endUtc = completedAt.toUtc();
    final durationSecs = endUtc.difference(startUtc).inSeconds;

    return CompletedWorkout(
      id: _uuid.v4(),
      completedAt: endUtc,
      durationSeconds: durationSecs < 0 ? 0 : durationSecs,
      exercises: completedExercises,
      totalVolumeKg: double.parse(totalKg.toStringAsFixed(3)),
      totalSetsCompleted: totalSets,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompletedWorkout &&
          other.id == id &&
          other.completedAt == completedAt &&
          other.durationSeconds == durationSeconds &&
          listEquals(other.exercises, exercises) &&
          other.totalVolumeKg == totalVolumeKg &&
          other.totalSetsCompleted == totalSetsCompleted);

  @override
  int get hashCode => Object.hash(
        id,
        completedAt,
        durationSeconds,
        Object.hashAll(exercises),
        totalVolumeKg,
        totalSetsCompleted,
      );
}
