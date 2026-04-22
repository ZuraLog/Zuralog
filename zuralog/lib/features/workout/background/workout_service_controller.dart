/// Zuralog — Workout Foreground Service Controller.
///
/// UI-isolate façade over `flutter_foreground_task`. Starts and stops the
/// Android foreground service that keeps the workout alive when the app is
/// backgrounded, the screen is off, or the Dart VM is killed by the OS.
///
/// On iOS, macOS, web, and desktop this controller is a graceful no-op —
/// iOS uses local notifications + Live Activities (Phases 5 and 6), and
/// the other platforms never host a live workout session.
///
/// Phase 4 of `docs/superpowers/plans/2026-04-22-workout-background-system.md`.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/workout/background/workout_task_handler.dart';

/// Thin wrapper around the plugin's static API so the rest of the app can
/// depend on a narrow interface (and so tests on non-Android platforms can
/// exercise the no-op contract without dragging in the plugin).
class WorkoutServiceController {
  bool _initialized = false;

  /// Whether the platform actually supports the Android foreground-service
  /// bridge. On every other platform this controller is deliberately inert.
  bool get _supported => !kIsWeb && Platform.isAndroid;

  void _ensureInitialized() {
    if (!_supported || _initialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'zuralog_workout',
        channelName: 'Workout in progress',
        channelDescription: 'Keeps your workout and rest timer running.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _initialized = true;
  }

  /// Starts the foreground service if it's not already running. Idempotent.
  Future<void> start() async {
    if (!_supported) return;
    _ensureInitialized();
    // Request the POST_NOTIFICATIONS permission that Android 13+ requires
    // for foreground service notifications. Idempotent — no-op when already granted.
    final permission = await FlutterForegroundTask.requestNotificationPermission();
    if (permission == NotificationPermission.permanently_denied) {
      // Notification permission permanently denied — the service will start
      // but the persistent notification will not appear. The user needs to
      // re-enable it in device Settings.
      debugPrint('[WorkoutServiceController] Notification permission permanently denied.');
    }
    final running = await FlutterForegroundTask.isRunningService;
    if (running) return;
    await FlutterForegroundTask.startService(
      notificationTitle: 'Workout in progress',
      notificationText: 'Active',
      callback: workoutTaskCallback,
    );
  }

  /// Stops the foreground service if it's running. Idempotent / safe to call
  /// when no service is active.
  Future<void> stop() async {
    if (!_supported) return;
    final running = await FlutterForegroundTask.isRunningService;
    if (!running) return;
    await FlutterForegroundTask.stopService();
  }

  /// Poke the service isolate so it re-reads [SharedPreferences] on its next
  /// tick. Called after the UI isolate writes new rest-timer state so the
  /// ongoing notification reflects the change promptly.
  Future<void> nudge() async {
    if (!_supported) return;
    final running = await FlutterForegroundTask.isRunningService;
    if (!running) return;
    FlutterForegroundTask.sendDataToTask(
      <String, dynamic>{'command': 'hydrate'},
    );
  }

  /// Register a callback that receives data the service isolate pushes back
  /// to us via `sendDataToMain` — heartbeats, notification-button actions.
  void attachMainReceiver(void Function(Object data) onData) {
    if (!_supported) return;
    FlutterForegroundTask.addTaskDataCallback(onData);
  }

  /// Unregister a callback previously passed to [attachMainReceiver].
  void detachMainReceiver(void Function(Object data) onData) {
    if (!_supported) return;
    FlutterForegroundTask.removeTaskDataCallback(onData);
  }
}

/// Singleton controller used by the rest of the app. NOT auto-disposed —
/// the service outlives any single feature screen.
final workoutServiceControllerProvider = Provider<WorkoutServiceController>(
  (ref) => WorkoutServiceController(),
);
