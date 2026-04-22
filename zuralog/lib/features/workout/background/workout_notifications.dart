/// Zuralog — Workout Notifications.
///
/// Cross-platform local notification plumbing for the rest-end alert.
/// Complements the Android foreground service (Phase 4) which owns the
/// ongoing "workout in progress" notification while the app is alive.
///
/// On iOS we have no foreground-service equivalent, so we schedule a
/// one-off local notification at `restStartedAt + duration` that fires
/// at T-0 whether or not the app is foregrounded. On Android this
/// service is also available as a fallback / secondary channel; the
/// primary rest-end surface stays the ongoing notification.
///
/// Action buttons on the scheduled notification (Skip / +30s / Finish)
/// are wired into the same [WorkoutNotificationActions] identifiers the
/// Android foreground service uses, so the UI-isolate side has a single
/// action router in `workoutServiceBridgeProvider`.
///
/// Phase 5 of `docs/superpowers/plans/2026-04-22-workout-background-system.md`.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Semantic action IDs shared across the Android foreground-service
/// notification buttons and the iOS scheduled-notification category.
///
/// These MUST stay in lock-step with the switch in
/// `workoutServiceBridgeProvider` — adding a new action here without
/// handling it there means the button does nothing on tap.
class WorkoutNotificationActions {
  const WorkoutNotificationActions._();

  /// Skip the current rest timer (dismiss, move on).
  static const String restSkip = 'rest_skip';

  /// Extend the current rest timer by 30 seconds.
  static const String restAdd30 = 'rest_add30';

  /// Finish the entire workout from the notification. Phase 5 treats this
  /// the same as "skip rest" — the full finish flow lives in the app UI.
  static const String workoutFinish = 'workout_finish';
}

/// Thin singleton wrapper around `flutter_local_notifications`.
///
/// All platform work is behind [initialize]; callers that are not yet
/// initialized silently no-op so test environments and the foreground
/// isolate don't trip over missing plugin channels.
class WorkoutNotifications {
  WorkoutNotifications._();

  /// Singleton instance. Intentionally not auto-disposed — the plugin and
  /// its pending scheduled notifications live for the process lifetime.
  static final WorkoutNotifications instance = WorkoutNotifications._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Receives `actionId` (one of [WorkoutNotificationActions]) when the
  /// user taps an action button, or `null` when they tap the notification
  /// body itself. Set from `workoutServiceBridgeProvider` so taps can
  /// drive Riverpod mutations.
  void Function(String? actionId)? onAction;

  // IDs and channel names are stable strings — do not rename once shipped.
  static const int _kRestEndNotificationId = 420001;
  static const String _channelId = 'zuralog_workout_rest_end';
  static const String _categoryId = 'zuralog.workout.rest';

  /// One-time initialization. Safe to call multiple times; subsequent
  /// calls are no-ops.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Factories (`DarwinNotificationAction.plain`) aren't const-constructible,
    // so the Darwin settings tree has to be an ordinary runtime value.
    final DarwinInitializationSettings darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          _categoryId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              WorkoutNotificationActions.restSkip,
              'Skip',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              WorkoutNotificationActions.restAdd30,
              '+30s',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              WorkoutNotificationActions.workoutFinish,
              'Finish',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.destructive,
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );

    // Permission prompts: iOS asks up-front; Android 13+ needs an explicit
    // POST_NOTIFICATIONS request. On older platforms both are no-ops.
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true, badge: true);
    }
    if (!kIsWeb && Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  void _onResponse(NotificationResponse r) {
    onAction?.call(r.actionId);
  }

  /// Background-isolate entry point for notification taps. Must be a
  /// top-level / static function annotated with `@pragma('vm:entry-point')`
  /// so the VM preserves it for the dispatcher.
  ///
  /// The UI isolate owns all mutations, so here we intentionally do
  /// nothing beyond letting the plugin launch the app — the foreground
  /// [_onResponse] path picks up the action on resume.
  @pragma('vm:entry-point')
  static void _onBackgroundResponse(NotificationResponse r) {
    // No-op: see docstring. The dedicated action router pattern
    // described in the plan (`notification_router.dart`) can be layered
    // in later without changing this entry point's signature.
  }

  /// Schedules a one-off "rest complete" notification at [fireAt].
  ///
  /// Cancels any previously scheduled rest-end notification first so
  /// re-scheduling (after `+30s`) always reflects the latest end-time.
  /// Silently no-ops if the service hasn't been initialized (e.g. unit
  /// tests that don't wire up the platform channel).
  Future<void> scheduleRestEnd({
    required DateTime fireAt,
    String title = 'Rest complete',
    String body = 'Back to work!',
  }) async {
    if (!_initialized) return;
    await _plugin.cancel(_kRestEndNotificationId);

    final tz.TZDateTime tzTime = tz.TZDateTime.from(fireAt, tz.local);

    await _plugin.zonedSchedule(
      _kRestEndNotificationId,
      title,
      body,
      tzTime,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          categoryIdentifier: _categoryId,
          presentAlert: true,
          presentSound: true,
        ),
        android: AndroidNotificationDetails(
          _channelId,
          'Rest completion',
          channelDescription: 'Alerts when your rest timer finishes.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
        ),
      ),
      // Use inexact scheduling to avoid the SCHEDULE_EXACT_ALARM permission
      // (Play Store scrutiny on exact alarms). Rest-end UX tolerates the
      // few-second jitter the OS may add.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Shows an immediate "rest complete" notification. Use this on Android
  /// where the foreground service bridge can detect expiry live via
  /// [restTimerProvider]. Replaces the unreliable [scheduleRestEnd] approach
  /// for Android — [scheduleRestEnd] is kept as the iOS background fallback.
  Future<void> showRestComplete({
    String title = 'Rest complete',
    String body = 'Back to work!',
  }) async {
    if (!_initialized) return;
    await _plugin.show(
      _kRestEndNotificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Rest completion',
          channelDescription: 'Alerts when your rest timer finishes.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: _categoryId,
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Cancels any scheduled rest-end notification. No-op when not scheduled.
  Future<void> cancelRestEnd() async {
    if (!_initialized) return;
    await _plugin.cancel(_kRestEndNotificationId);
  }
}

/// Riverpod handle for the singleton [WorkoutNotifications] instance.
///
/// Not auto-disposed — the notifications plumbing outlives any single
/// feature screen. Consumers should `ref.read` it once (typically from
/// the service bridge provider) and hold on to the reference.
final Provider<WorkoutNotifications> workoutNotificationsProvider =
    Provider<WorkoutNotifications>((ref) => WorkoutNotifications.instance);
