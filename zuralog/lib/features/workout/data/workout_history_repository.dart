/// Zuralog — Workout History Repository.
///
/// Persists a list of [CompletedWorkout]s as JSON under SharedPreferences
/// key `workout_history`. Offline-only, no network. Capped at 100 entries
/// so SharedPreferences doesn't grow unbounded over years of use.
///
/// Order guarantee: [loadAll] returns most-recent-first.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/features/workout/domain/completed_workout.dart';

const String kWorkoutHistoryKey = 'workout_history';
const int kWorkoutHistoryMaxEntries = 100;

class WorkoutHistoryRepository {
  WorkoutHistoryRepository(this._prefs);

  final SharedPreferences _prefs;

  Future<List<CompletedWorkout>> loadAll() async {
    final raw = _prefs.getString(kWorkoutHistoryKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final parsed = decoded
          .whereType<Map<String, dynamic>>()
          .map(CompletedWorkout.fromJson)
          .toList(growable: false);
      parsed.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      return parsed;
    } catch (e, st) {
      debugPrint('[WorkoutHistoryRepository] loadAll decode failed: $e\n$st');
      return const [];
    }
  }

  Future<void> saveWorkout(CompletedWorkout workout) async {
    final existing = await loadAll();
    final merged = <CompletedWorkout>[workout, ...existing];
    merged.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final capped = merged.length > kWorkoutHistoryMaxEntries
        ? merged.sublist(0, kWorkoutHistoryMaxEntries)
        : merged;
    try {
      final encoded = jsonEncode(
        capped.map((w) => w.toJson()).toList(growable: false),
      );
      await _prefs.setString(kWorkoutHistoryKey, encoded);
    } catch (e, st) {
      debugPrint('[WorkoutHistoryRepository] saveWorkout failed: $e\n$st');
    }
  }
}
