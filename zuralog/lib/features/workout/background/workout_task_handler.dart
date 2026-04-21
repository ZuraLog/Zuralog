/// Zuralog — Workout Foreground Task Handler.
///
/// Runs in a SEPARATE Dart isolate managed by `flutter_foreground_task`.
/// Does NOT have access to Riverpod state from the UI isolate — it
/// communicates with the UI by:
///   • reading persisted rest-timer state from [SharedPreferences]
///     (written by the UI isolate via `RestTimerStorage` /
///     `workoutSessionProvider.persist`);
///   • calling [FlutterForegroundTask.sendDataToMain] to push ticks
///     and notification-button actions back to the UI isolate;
///   • receiving `sendDataToTask` pokes via [onReceiveData] so the
///     UI can ask the handler to re-read prefs immediately.
///
/// Phase 4 of `docs/superpowers/plans/2026-04-22-workout-background-system.md`.
/// Android-only in Phase 4; iOS surfaces arrive in Phase 5 (notifications)
/// and Phase 6 (Live Activity).
library;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entry point for the foreground-service isolate.
///
/// MUST be a top-level function and decorated with `@pragma('vm:entry-point')`
/// so the Dart VM preserves it for the isolate spawner. This is invoked by
/// `flutter_foreground_task` in a brand-new isolate with no Flutter engine
/// bindings beyond what the plugin wires up — notably, no Riverpod, no
/// GoRouter, and no access to the main-isolate static state.
@pragma('vm:entry-point')
void workoutTaskCallback() {
  FlutterForegroundTask.setTaskHandler(WorkoutTaskHandler());
}

/// Handler that runs inside the foreground-service isolate.
///
/// State fields here are a mirror of the UI-isolate state; they are
/// rehydrated from [SharedPreferences] on [onStart] and refreshed whenever
/// the UI isolate nudges us via [onReceiveData]. We never mutate prefs
/// from this isolate — writes are owned by the UI isolate's notifiers.
class WorkoutTaskHandler extends TaskHandler {
  DateTime? _restStartedAt;
  int _plannedDurationSeconds = 0;
  int _addedSeconds = 0;
  DateTime? _workoutStartedAt;

  // Keys shared with the UI isolate.
  // Must stay in sync with `RestTimerStorage` and the workout draft writer.
  static const _kStartedAtMs = 'workout_rest_started_at_ms';
  static const _kPlannedDurationS = 'workout_rest_planned_duration_s';
  static const _kAddedSeconds = 'workout_rest_added_seconds';
  static const _kWorkoutDraft = 'workout_active_draft';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _hydrateFromPrefs();
  }

  Future<void> _hydrateFromPrefs() async {
    // Reload so we see writes made by the UI isolate since this isolate's
    // last read. SharedPreferences caches values per isolate.
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final ms = prefs.getInt(_kStartedAtMs);
    if (ms != null) {
      _restStartedAt = DateTime.fromMillisecondsSinceEpoch(ms);
      _plannedDurationSeconds = prefs.getInt(_kPlannedDurationS) ?? 0;
      _addedSeconds = prefs.getInt(_kAddedSeconds) ?? 0;
    } else {
      _restStartedAt = null;
      _plannedDurationSeconds = 0;
      _addedSeconds = 0;
    }

    // Parse workout startedAt from the active draft JSON using a cheap regex,
    // avoiding a dependency on the draft's full codec (which lives in the UI
    // isolate and pulls in a lot of code).
    final draft = prefs.getString(_kWorkoutDraft);
    if (draft != null) {
      try {
        final start =
            RegExp(r'"startedAt"\s*:\s*"([^"]+)"').firstMatch(draft)?.group(1);
        if (start != null) _workoutStartedAt = DateTime.parse(start);
      } catch (_) {
        // Malformed draft — ignore; we'll keep the previous value.
      }
    } else {
      _workoutStartedAt = null;
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _updateNotification();
    // Heartbeat to the UI isolate so it can (optionally) react.
    FlutterForegroundTask.sendDataToMain(
      <String, dynamic>{'tick': timestamp.millisecondsSinceEpoch},
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Nothing to flush — all authoritative state lives in the UI isolate.
  }

  @override
  void onReceiveData(Object data) {
    // Commands from the UI isolate. Today we just re-hydrate so the next
    // tick reflects the latest rest/workout state. We intentionally do
    // NOT act on the command payload beyond this — the UI isolate remains
    // the source of truth for mutations.
    if (data is Map && data['command'] is String) {
      _hydrateFromPrefs();
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Forward to the UI isolate, where `workoutServiceBridgeProvider`
    // translates the action id into a Riverpod mutation.
    FlutterForegroundTask.sendDataToMain(
      <String, dynamic>{'action': id},
    );
  }

  @override
  void onNotificationPressed() {
    // Deep-link back into the active workout session screen when the user
    // taps the ongoing notification. Requires SYSTEM_ALERT_WINDOW on older
    // Android; on recent versions this just launches the app normally.
    FlutterForegroundTask.launchApp('/log/workout/session');
  }

  @override
  void onNotificationDismissed() {
    // No-op. Foreground-service notifications are generally non-dismissable
    // on Android 14+; if the user manages to dismiss it we let the service
    // keep running and rebuild the notification on the next tick.
  }

  void _updateNotification() {
    FlutterForegroundTask.updateService(
      notificationTitle: 'Workout in progress',
      notificationText: _buildText(),
    );
  }

  String _buildText() {
    if (_restStartedAt != null) {
      final total = Duration(seconds: _plannedDurationSeconds + _addedSeconds);
      final elapsed = DateTime.now().difference(_restStartedAt!);
      final remaining = total - elapsed;
      if (remaining.isNegative) {
        return 'Rest over — back to work!';
      }
      final mm = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
      return 'Rest  $mm:$ss';
    }
    if (_workoutStartedAt != null) {
      final elapsed = DateTime.now().difference(_workoutStartedAt!);
      final hh = elapsed.inHours;
      final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
      return hh > 0 ? '$hh:$mm:$ss' : 'Workout $mm:$ss';
    }
    return 'Active';
  }
}
