/// Zuralog — OnboardingTooltip Riverpod Providers.
///
/// Manages tooltip seen/unseen state backed by [SharedPreferences].
///
/// ## State model
/// - `tooltipSeenProvider` — `Map<String, bool>` where each key is
///   `'{screenKey}.{tooltipKey}'` and the value is `true` when seen.
/// - `tooltipsEnabledProvider` — global master toggle (default: `true`).
///
/// ## Settings integration
/// The Settings screen calls `TooltipSeenNotifier.reset()` for
/// "Reset Tooltips" and `tooltipsEnabledProvider.notifier.state = false`
/// for "Disable Tooltips".
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const String _kTooltipsEnabledKey = 'tooltips_enabled';
const String _kSeenPrefix = 'tooltip_seen.';

// ── tooltipsEnabledProvider ───────────────────────────────────────────────────

/// Master toggle: when `false`, no tooltips are shown.
///
/// Backed by SharedPreferences. Defaults to `true`.
final tooltipsEnabledProvider =
    AsyncNotifierProvider<TooltipsEnabledNotifier, bool>(
  TooltipsEnabledNotifier.new,
);

/// Notifier that manages the global tooltip-enabled preference.
class TooltipsEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kTooltipsEnabledKey) ?? true;
  }

  /// Sets the enabled state and persists it.
  Future<void> setEnabled(bool value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTooltipsEnabledKey, value);
  }
}

// ── tooltipSeenProvider ───────────────────────────────────────────────────────

/// Map of persistence keys → seen state.
///
/// Keys have the format `'{screenKey}.{tooltipKey}'`.
/// `true` means the user has dismissed that tooltip.
final tooltipSeenProvider =
    AsyncNotifierProvider<TooltipSeenNotifier, Map<String, bool>>(
  TooltipSeenNotifier.new,
);

/// Notifier that manages the per-tooltip seen state.
class TooltipSeenNotifier extends AsyncNotifier<Map<String, bool>> {
  @override
  Future<Map<String, bool>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_kSeenPrefix));
    return {
      for (final k in keys)
        k.substring(_kSeenPrefix.length): prefs.getBool(k) ?? false,
    };
  }

  /// Marks a tooltip as seen and persists the state.
  ///
  /// [persistenceKey] — combined key in the format `'{screenKey}.{tooltipKey}'`.
  Future<void> markSeen(String persistenceKey) async {
    final current = Map<String, bool>.from(state.valueOrNull ?? {});
    current[persistenceKey] = true;
    state = AsyncData(current);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kSeenPrefix$persistenceKey', true);
  }

  /// Resets all seen tooltips (makes every tooltip visible again).
  ///
  /// Called from "Reset Tooltips" in Appearance Settings.
  Future<void> reset() async {
    state = const AsyncData({});
    final prefs = await SharedPreferences.getInstance();
    final keysToRemove =
        prefs.getKeys().where((k) => k.startsWith(_kSeenPrefix)).toList();
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }
}
