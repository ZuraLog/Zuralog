library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/workout/data/exercise_repository.dart';
import 'package:zuralog/features/workout/domain/exercise.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepository();
});

final exerciseListProvider = FutureProvider<List<Exercise>>((ref) async {
  final repo = ref.read(exerciseRepositoryProvider);
  try {
    return await repo.loadAll();
  } catch (e, st) {
    debugPrint('exerciseListProvider failed: $e\n$st');
    return const <Exercise>[];
  }
});

final exerciseSearchQueryProvider = StateProvider<String>((ref) => '');

final exerciseMuscleGroupFilterProvider =
    StateProvider<MuscleGroup?>((ref) => null);

final exerciseSearchProvider = FutureProvider<List<Exercise>>((ref) async {
  final all = await ref.watch(exerciseListProvider.future);
  final query = ref.watch(exerciseSearchQueryProvider);
  final group = ref.watch(exerciseMuscleGroupFilterProvider);

  final trimmed = query.trim().toLowerCase();

  return all.where((e) {
    if (group != null && e.muscleGroup != group) return false;
    if (trimmed.isNotEmpty && !e.name.toLowerCase().contains(trimmed)) {
      return false;
    }
    return true;
  }).toList(growable: false);
});
