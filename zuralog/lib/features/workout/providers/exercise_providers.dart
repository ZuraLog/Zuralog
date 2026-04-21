library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/workout/data/exercise_repository.dart';
import 'package:zuralog/features/workout/domain/exercise.dart';
import 'package:zuralog/features/workout/providers/exercise_bookmarks_provider.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepository();
});

final exerciseListProvider = FutureProvider<List<Exercise>>((ref) async {
  final repo = ref.read(exerciseRepositoryProvider);
  return repo.loadAll();
});

final exerciseSearchQueryProvider =
    StateProvider.autoDispose<String>((ref) => '');

final exerciseMuscleGroupFilterProvider =
    StateProvider.autoDispose<MuscleGroup?>((ref) => null);

final exerciseSearchProvider = FutureProvider<List<Exercise>>((ref) async {
  // Watch state providers before the async gap so autoDispose keeps them alive.
  final query = ref.watch(exerciseSearchQueryProvider);
  final group = ref.watch(exerciseMuscleGroupFilterProvider);
  final bookmarksOnly = ref.watch(exerciseBookmarksOnlyFilterProvider);
  final bookmarkedIds =
      bookmarksOnly ? ref.watch(exerciseBookmarksProvider) : null;
  final all = await ref.watch(exerciseListProvider.future);

  final trimmed = query.trim().toLowerCase();

  return all.where((e) {
    if (bookmarkedIds != null && !bookmarkedIds.contains(e.id)) return false;
    if (group != null && e.muscleGroup != group) return false;
    if (trimmed.isNotEmpty && !e.name.toLowerCase().contains(trimmed)) {
      return false;
    }
    return true;
  }).toList(growable: false);
});
