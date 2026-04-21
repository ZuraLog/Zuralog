/// Zuralog — Live Activity Bridge.
///
/// Dart-side façade over the native iOS ActivityKit MethodChannel.
/// No-op on Android and web.
///
/// The Widget Extension target that actually renders the Live Activity
/// must be added manually in Xcode — see `docs/ios-live-activity-setup.md`.
/// Until it's installed, `MissingPluginException` is caught here so app
/// logic continues unaffected.
///
/// Phase 6 of `docs/superpowers/plans/2026-04-22-workout-background-system.md`.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Payload passed to the native side for start / update calls.
///
/// Times are serialized as millisecond epochs so the Swift side can
/// reconstruct `Date` instances without format negotiation.
class LiveActivityPayload {
  const LiveActivityPayload({
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

/// Dart-side façade over the iOS ActivityKit MethodChannel.
///
/// All methods silently return on non-iOS platforms and swallow
/// `MissingPluginException` / `PlatformException` so callers don't have
/// to guard every call. This is deliberate: the Live Activity is a
/// nice-to-have surface; a crash here must never break the workout.
class LiveActivityBridge {
  static const _channel = MethodChannel('com.zuralog/workout_live_activity');

  bool get _supported => !kIsWeb && Platform.isIOS;

  Future<void> start(LiveActivityPayload payload) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('start', payload.toMap());
    } on PlatformException {
      // Activity may not be supported on this device / iOS version.
    } on MissingPluginException {
      // Widget Extension target not installed yet — see
      // docs/ios-live-activity-setup.md.
    }
  }

  Future<void> update(LiveActivityPayload payload) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('update', payload.toMap());
    } on PlatformException {
      // Swallow — see docstring on [start].
    } on MissingPluginException {
      // Swallow — see docstring on [start].
    }
  }

  Future<void> end() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('end');
    } on PlatformException {
      // Swallow — see docstring on [start].
    } on MissingPluginException {
      // Swallow — see docstring on [start].
    }
  }
}

/// Riverpod handle for the process-wide [LiveActivityBridge].
///
/// Safe to `ref.watch` from the bridge provider; the instance holds no
/// state of its own so recreation across hot-reload is harmless.
final liveActivityBridgeProvider = Provider<LiveActivityBridge>((ref) {
  return LiveActivityBridge();
});
