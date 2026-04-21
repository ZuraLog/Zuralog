/// Zuralog — Workout Companion Bridge.
///
/// Scaffolding for future Apple Watch / Wear OS companion apps.
/// All methods gracefully no-op when no companion is present.
///
/// Channel: com.zuralog/workout_companion
/// Methods:
///   - broadcast(payload) — state change
///   - isPaired() — returns bool
/// Callbacks:
///   - onCompanionAction(actionId) — called from native when companion sends a command
///
/// Phase 10 of `docs/superpowers/plans/2026-04-22-workout-background-system.md`.
/// Native sides (iOS `WorkoutCompanionBridge.swift`, Android `MainActivity.kt`)
/// are stubs that always report "no companion present" today. Full companion
/// app behavior is deliberately out of scope for this phase.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Payload sent to a paired companion when workout/rest state changes.
///
/// Mirrors [LiveActivityPayload] so the companion surface can share the
/// same time-anchored wall-clock math. Serialized as millisecond epochs
/// for platform-agnostic decoding on watchOS / Wear OS.
class CompanionPayload {
  const CompanionPayload({
    required this.workoutStartedAt,
    this.restStartedAt,
    this.plannedRestDurationSeconds = 0,
    this.addedRestSeconds = 0,
    this.exerciseName = '',
    this.setLabel = '',
  });

  final DateTime workoutStartedAt;
  final DateTime? restStartedAt;
  final int plannedRestDurationSeconds;
  final int addedRestSeconds;
  final String exerciseName;
  final String setLabel;

  Map<String, Object?> toMap() => {
        'workoutStartedAtMs': workoutStartedAt.millisecondsSinceEpoch,
        'restStartedAtMs': restStartedAt?.millisecondsSinceEpoch,
        'plannedRestDurationSeconds': plannedRestDurationSeconds,
        'addedRestSeconds': addedRestSeconds,
        'exerciseName': exerciseName,
        'setLabel': setLabel,
      };
}

/// Stable action identifiers the companion may send back to the phone.
///
/// These are intentionally aligned with the existing notification-button
/// action ids so the dispatch logic in `active_workout_provider.dart`
/// can reuse the same switch statement without translation.
class CompanionActions {
  static const restSkip = 'rest_skip';
  static const restAdd30 = 'rest_add30';
  static const workoutFinish = 'workout_finish';
}

/// Dart-side façade over the companion MethodChannel.
///
/// All methods silently return on non-mobile platforms and swallow
/// `MissingPluginException` / `PlatformException` so callers don't have
/// to guard every call. A companion app is strictly a nice-to-have
/// surface; a crash here must never break the in-phone workout.
class WorkoutCompanionBridge {
  WorkoutCompanionBridge() {
    _channel.setMethodCallHandler(_handleIncoming);
  }

  static const _channel = MethodChannel('com.zuralog/workout_companion');

  /// Callback fired when the native side reports that the companion
  /// (watch) sent an action the phone should act on — e.g. Skip rest.
  void Function(String actionId)? onAction;

  bool get _supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// True iff a companion device is paired and reachable. Always false
  /// on platforms without a companion API (web, desktop, older OS).
  Future<bool> isPaired() async {
    if (!_supported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isPaired');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Push the latest workout state to the companion. Returns quickly
  /// regardless of whether delivery succeeded — errors are swallowed.
  Future<void> broadcast(CompanionPayload payload) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('broadcast', payload.toMap());
    } on PlatformException {
      // No companion, or channel error. Swallow.
    } on MissingPluginException {
      // Native side not registered. Normal until companion apps ship.
    }
  }

  Future<void> _handleIncoming(MethodCall call) async {
    if (call.method == 'onAction' && call.arguments is String) {
      onAction?.call(call.arguments as String);
    }
  }
}

/// Riverpod handle for the process-wide [WorkoutCompanionBridge].
///
/// Safe to `ref.watch` from other providers; the instance holds no
/// state of its own so recreation across hot-reload is harmless.
final workoutCompanionBridgeProvider = Provider<WorkoutCompanionBridge>((ref) {
  return WorkoutCompanionBridge();
});
