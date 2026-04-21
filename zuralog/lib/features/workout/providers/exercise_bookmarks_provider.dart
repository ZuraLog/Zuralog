/// Zuralog — Exercise Bookmarks Provider.
///
/// Provides state management for bookmarked exercises with SharedPreferences
/// persistence. Users can bookmark exercises in the catalogue, and bookmarks
/// persist across app sessions.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/storage/prefs_service.dart';

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Manages a set of bookmarked exercise IDs with SharedPreferences persistence.
///
/// Bookmarks are stored as a comma-separated string in SharedPreferences under
/// the key `workout_bookmarked_exercises`. The notifier loads existing bookmarks
/// on initialization and persists any changes immediately.
class ExerciseBookmarksNotifier extends StateNotifier<Set<String>> {
  /// Creates an [ExerciseBookmarksNotifier] backed by [prefs].
  ///
  /// Loads existing bookmarks from SharedPreferences on initialization.
  ExerciseBookmarksNotifier(SharedPreferences prefs)
      : _prefs = prefs,
        super(_loadFromPrefs(prefs));

  final SharedPreferences _prefs;
  static const _key = 'workout_bookmarked_exercises';

  /// Loads bookmarks from SharedPreferences.
  ///
  /// Returns an empty set if no bookmarks are stored or the stored string is empty.
  static Set<String> _loadFromPrefs(SharedPreferences prefs) {
    final raw = prefs.getString(_key) ?? '';
    if (raw.isEmpty) return {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  /// Toggles the bookmark status of an exercise.
  ///
  /// If the exercise is bookmarked, it is removed. If it is not bookmarked,
  /// it is added. The updated set is immediately persisted to SharedPreferences.
  void toggle(String exerciseId) {
    final updated = Set<String>.from(state);
    if (updated.contains(exerciseId)) {
      updated.remove(exerciseId);
    } else {
      updated.add(exerciseId);
    }
    state = updated;
    _persist();
  }

  /// Returns whether the exercise with the given ID is bookmarked.
  ///
  /// Note: Prefer watching [isBookmarkedProvider] in widgets instead of
  /// calling this method directly.
  bool contains(String exerciseId) => state.contains(exerciseId);

  /// Persists the current state to SharedPreferences.
  void _persist() {
    _prefs.setString(_key, state.join(','));
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Provides reactive access to bookmarked exercise IDs.
///
/// Bookmarks are persisted across sessions in SharedPreferences. This provider
/// is not autoDispose so that bookmarks survive navigation between screens.
final exerciseBookmarksProvider = StateNotifierProvider<
    ExerciseBookmarksNotifier,
    Set<String>>((ref) {
  final prefs = ref.read(prefsProvider);
  return ExerciseBookmarksNotifier(prefs);
});

/// Provides whether a specific exercise ID is bookmarked.
///
/// This is a convenience provider for widgets that need to check the bookmark
/// status of a single exercise. It watches [exerciseBookmarksProvider] and
/// returns `true` if the exercise ID is in the set of bookmarks.
final isBookmarkedProvider = Provider.family.autoDispose<bool, String>(
  (ref, exerciseId) {
    return ref.watch(exerciseBookmarksProvider).contains(exerciseId);
  },
);

/// Provides the filter state for showing only bookmarked exercises.
///
/// This state provider drives the "Bookmarks" chip filter mode in the
/// exercise catalogue. When true, only bookmarked exercises are shown;
/// when false, all exercises are shown.
final exerciseBookmarksOnlyFilterProvider =
    StateProvider.autoDispose<bool>((ref) => false);
