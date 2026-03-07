/// Zuralog Design System — Theme Mode Provider.
///
/// Manages the app's [ThemeMode] via a persisted [AsyncNotifier].
///
/// ## Persistence hierarchy
/// 1. [userPreferencesProvider] is the authoritative source (loaded from API).
///    When it resolves, [themeModeProvider] reflects that value.
/// 2. SharedPreferences (`theme_mode`) is the offline fallback and is written
///    on every change so the correct theme is applied before the API loads.
///
/// ## Migration from StateProvider
/// Previous code used a plain `StateProvider<ThemeMode>` that reset to
/// `ThemeMode.system` on every cold start. The new provider reads from
/// SharedPreferences immediately so there is no flash-of-wrong-theme.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart'
    show userPreferencesProvider;

// ── Constants ──────────────────────────────────────────────────────────────────

const _kThemeModeKey = 'theme_mode';

// ── Notifier ───────────────────────────────────────────────────────────────────

/// Manages the persisted [ThemeMode] preference.
///
/// Build reads only from SharedPreferences so it resolves immediately on
/// cold start (no flash of wrong theme) without creating a dependency on
/// [userPreferencesProvider] that would cause a rebuild loop.
///
/// The API value is pulled in once after login via [syncFromApi], which is
/// called by [UserPreferencesNotifier] after a successful fetch.
class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    // Read local cache first — fast, available before API responds.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kThemeModeKey);
    if (raw != null) return _fromString(raw) ?? ThemeMode.system;

    // No local value yet — check if the API has already loaded.
    final apiTheme = ref.read(userPreferencesProvider).valueOrNull?.appTheme;
    if (apiTheme != null) {
      final mode = _fromAppTheme(apiTheme);
      _persistLocally(mode);
      return mode;
    }

    return ThemeMode.system;
  }

  /// Called after [userPreferencesProvider] loads to sync the API value.
  ///
  /// Only updates if the API returns a non-system theme AND the local cache
  /// has not been set by the user (i.e., still at the default).
  Future<void> syncFromApi(AppTheme apiTheme) async {
    final prefs = await SharedPreferences.getInstance();
    final hasLocalValue = prefs.containsKey(_kThemeModeKey);
    if (!hasLocalValue) {
      final mode = _fromAppTheme(apiTheme);
      state = AsyncData(mode);
      _persistLocally(mode);
    }
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Sets the theme mode, persists locally, and syncs to the API via
  /// [userPreferencesProvider].
  Future<void> setTheme(ThemeMode mode) async {
    state = AsyncData(mode);
    _persistLocally(mode);
    await ref.read(userPreferencesProvider.notifier).mutate(
          (p) => p.copyWith(appTheme: _toAppTheme(mode)),
        );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _persistLocally(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeModeKey, _toString(mode));
    } catch (_) {
      // Non-fatal — ignore.
    }
  }

  static ThemeMode? _fromString(String? s) => switch (s) {
        'dark'   => ThemeMode.dark,
        'light'  => ThemeMode.light,
        'system' => ThemeMode.system,
        _        => null,
      };

  static String _toString(ThemeMode m) => switch (m) {
        ThemeMode.dark   => 'dark',
        ThemeMode.light  => 'light',
        ThemeMode.system => 'system',
      };

  static AppTheme _toAppTheme(ThemeMode m) => switch (m) {
        ThemeMode.dark   => AppTheme.dark,
        ThemeMode.light  => AppTheme.light,
        ThemeMode.system => AppTheme.system,
      };

  static ThemeMode _fromAppTheme(AppTheme a) => switch (a) {
        AppTheme.dark   => ThemeMode.dark,
        AppTheme.light  => ThemeMode.light,
        AppTheme.system => ThemeMode.system,
      };
}

/// The persisted theme mode provider consumed by [MaterialApp.themeMode].
///
/// Falls back to [ThemeMode.system] while loading — no flash of wrong theme
/// because SharedPreferences resolves synchronously on first frame.
final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
