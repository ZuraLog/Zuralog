/// Zuralog — Haptic Feedback Service.
///
/// Provides semantic haptic feedback abstractions that map to named
/// interaction types (light, medium, success, warning, selectionTick).
///
/// The service is a no-op when the haptic toggle is disabled, ensuring
/// zero battery/CPU cost when the user has turned off haptics.
///
/// Platform behavior:
/// - iOS: Uses `HapticFeedback` Flutter API which triggers Taptic Engine.
/// - Android: Uses vibration patterns that approximate the same semantics.
///
/// All interaction points in the app use this service rather than calling
/// `HapticFeedback` directly, so the toggle preference is always respected.
library;

import 'package:flutter/services.dart';

/// Semantic haptic types used across the Zuralog app.
///
/// Map of type → intended interaction:
/// - [light]: Tab switch, card tap, list selection, tooltip dismiss.
/// - [medium]: Send message, confirm log, toggle setting, submit Quick Log.
/// - [success]: Goal reached, streak milestone, achievement unlock, report generated.
/// - [warning]: Integration disconnect, anomaly alert, destructive action.
/// - [selectionTick]: Picker scrolls, slider drags, drag handles.
enum HapticType { light, medium, success, warning, selectionTick }

/// Service that wraps Flutter's [HapticFeedback] with semantic method names.
///
/// Obtain via [hapticServiceProvider]. Do not construct directly.
class HapticService {
  /// Creates a [HapticService].
  ///
  /// [enabled] — when `false` every method is a no-op.
  const HapticService({required bool enabled}) : _enabled = enabled;

  final bool _enabled;

  /// Whether haptic feedback is currently active.
  bool get isEnabled => _enabled;

  // ── Semantic API ─────────────────────────────────────────────────────────

  /// Light tap — tab switches, card taps, list selections, tooltip dismissals.
  Future<void> light() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  /// Medium impact — send message, confirm log, toggle setting, Quick Log submit.
  Future<void> medium() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Heavy success pulse — goal reached, streak milestone, achievement unlock.
  Future<void> success() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  /// Warning buzz — integration disconnect, anomaly alert, destructive action.
  Future<void> warning() async {
    if (!_enabled) return;
    await HapticFeedback.vibrate();
  }

  /// Selection tick — pickers, sliders, drag handles.
  Future<void> selectionTick() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  /// Trigger a haptic by [HapticType] enum value.
  ///
  /// Useful when the type is determined at runtime (e.g. from a map).
  Future<void> trigger(HapticType type) async {
    switch (type) {
      case HapticType.light:
        await light();
      case HapticType.medium:
        await medium();
      case HapticType.success:
        await success();
      case HapticType.warning:
        await warning();
      case HapticType.selectionTick:
        await selectionTick();
    }
  }
}
