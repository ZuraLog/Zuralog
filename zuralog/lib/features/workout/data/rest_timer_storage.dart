/// Zuralog — Rest Timer Storage.
///
/// Typed SharedPreferences wrapper that persists the rest timer's wall-clock
/// start stamp and configured duration so the timer survives notifier
/// recreation (e.g. hot reload) and app restarts. Only the raw scalars are
/// stored — the [RestTimerState] is rebuilt from them on load. Writes happen
/// only from the UI isolate (`RestTimerNotifier`).
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/features/workout/providers/rest_timer_provider.dart';

class RestTimerStorage {
  RestTimerStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _kStartedAtMs = 'workout_rest_started_at_ms';
  static const _kPlannedDurationS = 'workout_rest_planned_duration_s';
  static const _kAddedSeconds = 'workout_rest_added_seconds';

  /// Persist the scalars from [s]. If the state has no start stamp, the
  /// storage is cleared instead.
  Future<void> save(RestTimerState s) async {
    if (s.restStartedAt == null) {
      await clear();
      return;
    }
    await _prefs.setInt(_kStartedAtMs, s.restStartedAt!.millisecondsSinceEpoch);
    await _prefs.setInt(_kPlannedDurationS, s.plannedDurationSeconds);
    await _prefs.setInt(_kAddedSeconds, s.addedSeconds);
  }

  /// Returns the persisted state, or `null` if nothing is stored. The caller
  /// is responsible for deciding whether the restored state is still fresh.
  Future<RestTimerState?> load() async {
    final startedAtMs = _prefs.getInt(_kStartedAtMs);
    if (startedAtMs == null) return null;
    return RestTimerState(
      restStartedAt: DateTime.fromMillisecondsSinceEpoch(startedAtMs),
      plannedDurationSeconds: _prefs.getInt(_kPlannedDurationS) ?? 0,
      addedSeconds: _prefs.getInt(_kAddedSeconds) ?? 0,
    );
  }

  /// Remove all rest-timer keys.
  Future<void> clear() async {
    await _prefs.remove(_kStartedAtMs);
    await _prefs.remove(_kPlannedDurationS);
    await _prefs.remove(_kAddedSeconds);
  }
}
