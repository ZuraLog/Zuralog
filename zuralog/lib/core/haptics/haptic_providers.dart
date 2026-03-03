/// Zuralog — Haptic Feedback Riverpod Providers.
///
/// Exposes a [hapticServiceProvider] that wires the [HapticService] to
/// the user's haptic-enabled preference. The preference is stored in
/// SharedPreferences under [_kHapticEnabledKey] and defaults to `true`.
///
/// When the UserPreferences API (Phase 2) is available, the backing store
/// can be swapped to read from the preferences endpoint without changing
/// call sites — the provider interface remains identical.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'haptic_service.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// SharedPreferences key for the haptic toggle.
const String _kHapticEnabledKey = 'haptic_enabled';

// ── Providers ─────────────────────────────────────────────────────────────────

/// A [StateNotifierProvider] that manages whether haptic feedback is enabled.
///
/// Reads the stored preference on first access, defaults to `true`.
/// Persists changes to [SharedPreferences] whenever the state is toggled.
final hapticEnabledProvider =
    AsyncNotifierProvider<HapticEnabledNotifier, bool>(
  HapticEnabledNotifier.new,
);

/// Notifier that manages the haptic-enabled boolean preference.
class HapticEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to enabled if the key hasn't been set yet.
    return prefs.getBool(_kHapticEnabledKey) ?? true;
  }

  /// Toggles haptic feedback and persists the new value.
  Future<void> toggle() async {
    final current = state.valueOrNull ?? true;
    await setEnabled(!current);
  }

  /// Sets haptic feedback to [value] and persists the change.
  Future<void> setEnabled(bool value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHapticEnabledKey, value);
  }
}

/// Synchronous [Provider] that returns a ready-to-use [HapticService].
///
/// Falls back to `enabled: true` while the async preference is loading,
/// so the first few taps are haptic-enabled by default.
final hapticServiceProvider = Provider<HapticService>((ref) {
  final enabledAsync = ref.watch(hapticEnabledProvider);
  final enabled = enabledAsync.valueOrNull ?? true;
  return HapticService(enabled: enabled);
});
