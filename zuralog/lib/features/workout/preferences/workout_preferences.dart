/// Zuralog — Workout Preferences.
///
/// Local, device-scoped preferences for workout UX toggles that do NOT
/// round-trip to the backend. Stored in SharedPreferences.
///
/// Why local-only: these settings are specific to the rest-timer feedback
/// loop on this device. They are not synced across devices today because
/// the cloud `user_preferences` schema does not model them, and adding a
/// column requires a backend migration. Promoting this to the cloud model
/// later is a small change — the API here stays stable.
///
/// Current keys:
/// - `workout_rest_sound_enabled` — whether to play the rest-complete chime.
///   Defaults to `true`. The chime is also gated on the device's haptic
///   toggle being able to produce sound; if the user has turned system
///   sounds off, the service will simply no-op.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/storage/prefs_service.dart';

/// Thin wrapper around [SharedPreferences] for workout-specific toggles.
///
/// Obtain via [workoutPreferencesProvider]. Do not instantiate directly.
class WorkoutPreferences {
  /// Creates a [WorkoutPreferences] backed by [_prefs].
  WorkoutPreferences(this._prefs);

  final SharedPreferences _prefs;

  /// Storage key for the rest-completion sound toggle.
  static const String kRestSoundEnabledKey = 'workout_rest_sound_enabled';

  /// Whether the rest-complete chime is enabled. Defaults to `true`.
  bool get restSoundEnabled => _prefs.getBool(kRestSoundEnabledKey) ?? true;

  /// Persists the rest-sound toggle.
  Future<void> setRestSoundEnabled(bool value) async {
    await _prefs.setBool(kRestSoundEnabledKey, value);
  }
}

/// Riverpod provider exposing a ready-to-use [WorkoutPreferences].
///
/// Requires `prefsProvider` to be overridden at app startup (see main.dart).
final workoutPreferencesProvider = Provider<WorkoutPreferences>((ref) {
  return WorkoutPreferences(ref.watch(prefsProvider));
});
