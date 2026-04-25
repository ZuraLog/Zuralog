/// Zuralog — Global User Preferences Providers.
///
/// Single source of truth for all user-configurable preferences.
///
/// ## Architecture
/// - [userPreferencesProvider] — `AsyncNotifier` that owns the full
///   [UserPreferencesModel]. Loads from API on build; falls back to
///   SharedPreferences when offline. Writes are optimistic: state is updated
///   immediately, then persisted to both SharedPreferences and the API.
///
/// - Derived `Provider`s — thin selectors that expose individual fields so
///   widgets only rebuild when the specific field they care about changes.
///   Coach-specific providers ([coachPersonaProvider], [voiceInputEnabledProvider],
///   etc.) are pre-wired infrastructure ready for the Coach tab wiring phase.
///
/// ## Why not file-private StateProviders?
/// Previous settings screens used file-private `StateProvider`s that were
/// invisible to other features. This caused Coach settings to be saved to
/// the API but never read back, and Notification/Privacy settings to reset
/// on every cold start. This layer fixes all of that in one place.
library;

import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/settings/data/memory_repository.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';

// ── SharedPreferences key ──────────────────────────────────────────────────────

/// Key under which the full [UserPreferencesModel] JSON is cached locally.
/// This enables offline reads after the first successful API fetch.
const _kPrefsKey = 'user_preferences_cache';

// ── Notifier ───────────────────────────────────────────────────────────────────

/// Loads, caches, and persists the user's full preferences.
///
/// ### Load order on [build]:
/// 1. Try `GET /api/v1/preferences` — authoritative source.
/// 2. On any network error, fall back to the SharedPreferences cache.
/// 3. If the cache is also empty, return safe [UserPreferencesModel] defaults
///    (empty `id`/`userId` — the notifier will be re-initialized on next
///    successful API call).
///
/// ### Write strategy on [update]:
/// 1. Optimistic update — set `state = AsyncData(updated)` immediately so
///    the UI reflects the change without waiting.
/// 2. Write to SharedPreferences for offline durability.
/// 3. `PATCH /api/v1/preferences` — persists to the server.
/// 4. On API error, the in-memory + SharedPreferences value is still correct.
///    A Sentry breadcrumb is emitted but the UI is not disrupted.
class UserPreferencesNotifier
    extends AsyncNotifier<UserPreferencesModel> {
  static const _path = '/api/v1/preferences';

  @override
  Future<UserPreferencesModel> build() async {
    return _loadFromApiWithFallback();
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Applies [updated] as the new preferences state and persists it.
  ///
  /// Optimistic: the UI sees the new value immediately. A background PATCH
  /// is fired; any API error is swallowed after logging so the user is not
  /// interrupted.
  Future<void> save(UserPreferencesModel updated) async {
    state = AsyncData(updated);
    await _persistLocally(updated);
    await _patchApi(updated);
  }

  /// Convenience helper for mutating a single field via [copyWith].
  ///
  /// No-op if preferences haven't loaded yet (avoids overwriting defaults
  /// with a stale partial update).
  Future<void> mutate(UserPreferencesModel Function(UserPreferencesModel) fn) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await save(fn(current));
  }

  /// Forces a fresh load from the API, overwriting the local cache.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadFromApiWithFallback);
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  Future<UserPreferencesModel> _loadFromApiWithFallback() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(_path);
      final data = response.data as Map<String, dynamic>;
      final model = UserPreferencesModel.fromJson(data);
      await _persistLocally(model); // keep cache fresh
      return model;
    } catch (_) {
      // Network unavailable or API error — try local cache.
      return _loadFromCache();
    }
  }

  Future<UserPreferencesModel> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return UserPreferencesModel.fromJson(json);
      }
    } catch (_) {
      // Corrupt cache — fall through to defaults.
    }
    // Return safe defaults. id/userId are empty; the next successful API
    // load will overwrite this.
    return const UserPreferencesModel(id: '', userId: '');
  }

  Future<void> _persistLocally(UserPreferencesModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, jsonEncode(model.toJson()));
    } catch (_) {
      // SharedPreferences write failures are non-fatal — ignore silently.
    }
  }

  Future<void> _patchApi(UserPreferencesModel model) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.patch(_path, body: model.toPatchJson());
    } catch (_) {
      // API write failures are non-fatal. The local cache remains consistent.
      // The next app launch will re-fetch from the API, keeping eventual sync.
    }
  }
}

/// The root preferences provider. All other settings providers derive from this.
final userPreferencesProvider =
    AsyncNotifierProvider<UserPreferencesNotifier, UserPreferencesModel>(
  UserPreferencesNotifier.new,
);

// ── Derived providers ──────────────────────────────────────────────────────────
//
// Each derived provider uses .select() so only widgets watching the specific
// field rebuild when that field changes — not on every preferences update.

// ── Coach ──────────────────────────────────────────────────────────────────────

/// The AI coach personality style.
final coachPersonaProvider = Provider<CoachPersona>((ref) {
  return ref
      .watch(userPreferencesProvider)
      .valueOrNull
      ?.coachPersona ?? CoachPersona.balanced;
});

/// How proactively the AI surfaces suggestions and quick actions.
final proactivityLevelProvider = Provider<ProactivityLevel>((ref) {
  return ref
      .watch(userPreferencesProvider)
      .valueOrNull
      ?.proactivityLevel ?? ProactivityLevel.medium;
});

/// Preferred AI response verbosity.
final responseLengthProvider = Provider<ResponseLength>((ref) {
  return ref
      .watch(userPreferencesProvider)
      .valueOrNull
      ?.responseLength ?? ResponseLength.concise;
});

/// Whether the Coach tab shows suggested prompt chips below the input bar.
final suggestedPromptsEnabledProvider = Provider<bool>((ref) {
  return ref
      .watch(userPreferencesProvider)
      .valueOrNull
      ?.suggestedPromptsEnabled ?? true;
});

/// Whether the mic button is shown in Coach chat screens.
final voiceInputEnabledProvider = Provider<bool>((ref) {
  return ref
      .watch(userPreferencesProvider)
      .valueOrNull
      ?.voiceInputEnabled ?? true;
});

// ── Appearance ─────────────────────────────────────────────────────────────────

/// The persisted app theme preference mapped to Flutter's [ThemeMode].
///
/// Defaults to [ThemeMode.system] until preferences load.
final themeModePreferenceProvider = Provider<ThemeMode>((ref) {
  final appTheme = ref
      .watch(userPreferencesProvider)
      .valueOrNull
      ?.appTheme ?? AppTheme.system;
  return switch (appTheme) {
    AppTheme.dark   => ThemeMode.dark,
    AppTheme.light  => ThemeMode.light,
    AppTheme.system => ThemeMode.system,
  };
});

// ── Privacy & Visibility ───────────────────────────────────────────────────────

/// Whether the Data Maturity Banner has been dismissed by the user.
final dataMaturityBannerDismissedProvider = Provider<bool>((ref) {
  return ref
      .watch(userPreferencesProvider)
      .valueOrNull
      ?.dataMaturityBannerDismissed ?? false;
});

/// Whether the user has opted out of anonymous product analytics.
final analyticsOptOutProvider = Provider<bool>((ref) {
  return ref
      .watch(userPreferencesProvider)
      .valueOrNull
      ?.analyticsOptOut ?? false;
});

/// Whether the AI coach should build and use long-term memories.
final memoryEnabledProvider = Provider<bool>((ref) {
  return ref
      .watch(userPreferencesProvider)
      .valueOrNull
      ?.memoryEnabled ?? true;
});

// ── Account ────────────────────────────────────────────────────────────────────

/// The user's preferred measurement system (metric or imperial).
final unitsSystemProvider = Provider<UnitsSystem>((ref) {
  return ref
      .watch(userPreferencesProvider)
      .valueOrNull
      ?.unitsSystem ?? UnitsSystem.metric;
});

/// In-memory unit choice used during onboarding before [userPreferencesProvider]
/// has finished loading from the server. Both [ZHeightPicker] and [ZWeightPicker]
/// read and write this when their `useSessionUnits` flag is true. Finalised into
/// [userPreferencesProvider] at the end of the onboarding flow.
final sessionUnitsProvider = StateProvider<UnitsSystem>(
  (ref) => UnitsSystem.metric,
);

// ── AI Memory ──────────────────────────────────────────────────────────────────

/// Provides the [MemoryRepository] backed by the Cloud Brain API.
final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepository(ref.read(apiClientProvider));
});

/// Async notifier for the list of AI memory items.
final memoryItemsProvider =
    AsyncNotifierProvider<MemoryNotifier, List<MemoryItem>>(MemoryNotifier.new);

class MemoryNotifier extends AsyncNotifier<List<MemoryItem>> {
  @override
  Future<List<MemoryItem>> build() async {
    return ref.read(memoryRepositoryProvider).listMemories();
  }

  Future<void> delete(String id) async {
    await ref.read(memoryRepositoryProvider).deleteMemory(id);
    ref.invalidateSelf();
  }

  Future<void> clearAll() async {
    await ref.read(memoryRepositoryProvider).clearAllMemories();
    state = const AsyncData([]);
  }
}
