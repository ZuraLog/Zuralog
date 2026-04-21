/// Zuralog — Workout Resume Service.
///
/// On cold start, detects a stranded in-progress workout draft in
/// SharedPreferences (`workout_active_draft`) and decides whether to offer
/// a "Resume your workout?" prompt. Drafts older than 6 hours are silently
/// discarded; malformed drafts are wiped defensively.
///
/// The draft shape is owned by `WorkoutSessionNotifier._saveDraft` — see
/// `workout_session.dart#WorkoutSession.toJson`:
/// ```json
/// {
///   "id": "<uuid>",
///   "startedAt": "<UTC ISO-8601>",
///   "exercises": [ ... ]
/// }
/// ```
/// This service only reads `startedAt` (to compute age) and the length of
/// `exercises` (for the dialog body). It never mutates the draft beyond
/// calling [discard] or the internal stale/malformed cleanup.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Metadata about a resumable in-progress workout, returned by
/// [WorkoutResumeService.checkResumable].
class ResumableWorkout {
  const ResumableWorkout({
    required this.startedAt,
    required this.exerciseCount,
    required this.rawJson,
  });

  /// When the user started the workout (local time).
  final DateTime startedAt;

  /// Number of exercises already added to the draft.
  final int exerciseCount;

  /// The raw JSON string still sitting in SharedPreferences.
  /// The session screen restores from this key, not from this value — we
  /// expose it for diagnostic/log purposes only.
  final String rawJson;

  /// How long ago the workout was started.
  Duration get age => DateTime.now().difference(startedAt);
}

/// Thin, synchronous wrapper around SharedPreferences that decides whether a
/// stored workout draft is worth offering to resume.
class WorkoutResumeService {
  WorkoutResumeService(this._prefs);

  final SharedPreferences _prefs;

  /// Must match the key used by `WorkoutSessionNotifier` to persist the draft.
  /// Duplicated here (rather than imported) so the service stays independent
  /// of the providers layer.
  static const _kDraftKey = 'workout_active_draft';

  /// Drafts older than this threshold are silently discarded on cold start.
  /// Matches Decision 7 in the background-workout plan.
  static const _kStaleThreshold = Duration(hours: 6);

  /// Returns a [ResumableWorkout] when a fresh draft is stored, or `null`
  /// when there is nothing to resume.
  ///
  /// Side effects:
  /// - Silently removes the draft key when the stored session is older than
  ///   [_kStaleThreshold].
  /// - Silently removes the draft key when the stored payload is malformed
  ///   (invalid JSON, missing `startedAt`, or unparseable timestamp).
  ResumableWorkout? checkResumable() {
    final raw = _prefs.getString(_kDraftKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _prefs.remove(_kDraftKey);
        return null;
      }

      final startedAtIso = decoded['startedAt'] as String?;
      if (startedAtIso == null || startedAtIso.isEmpty) {
        _prefs.remove(_kDraftKey);
        return null;
      }

      final parsed = DateTime.tryParse(startedAtIso);
      if (parsed == null) {
        _prefs.remove(_kDraftKey);
        return null;
      }
      final startedAt = parsed.toLocal();

      final exercisesRaw = decoded['exercises'];
      final exerciseCount =
          exercisesRaw is List ? exercisesRaw.length : 0;

      final age = DateTime.now().difference(startedAt);
      if (age > _kStaleThreshold) {
        _prefs.remove(_kDraftKey);
        return null;
      }

      return ResumableWorkout(
        startedAt: startedAt,
        exerciseCount: exerciseCount,
        rawJson: raw,
      );
    } catch (_) {
      // Malformed draft — wipe it so we never offer it again.
      _prefs.remove(_kDraftKey);
      return null;
    }
  }

  /// Explicitly discards the stored draft. Called when the user taps
  /// "Discard" on the resume prompt.
  Future<void> discard() async {
    await _prefs.remove(_kDraftKey);
  }
}
