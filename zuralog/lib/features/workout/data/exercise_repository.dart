library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:zuralog/features/workout/domain/exercise.dart';

const String kExercisesAssetPath = 'assets/data/exercises.json';

class ExerciseRepository {
  ExerciseRepository();

  List<Exercise>? _cache;

  Future<List<Exercise>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;

    try {
      final raw = await rootBundle.loadString(kExercisesAssetPath);
      final decoded = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final parsed = List<Exercise>.unmodifiable(
        decoded.map(Exercise.fromJson),
      );
      _cache = parsed;
      return parsed;
    } catch (e, st) {
      debugPrint('[ExerciseRepository] loadAll failed: $e\n$st');
      const empty = <Exercise>[];
      _cache = empty;
      return empty;
    }
  }

  List<Exercise> filter({
    MuscleGroup? muscleGroup,
    Equipment? equipment,
    String query = '',
  }) {
    final list = _cache;
    if (list == null) return const [];

    final trimmed = query.trim().toLowerCase();

    return list.where((e) {
      if (muscleGroup != null && e.muscleGroup != muscleGroup) return false;
      if (equipment != null && e.equipment != equipment) return false;
      if (trimmed.isNotEmpty && !e.name.toLowerCase().contains(trimmed)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }
}
