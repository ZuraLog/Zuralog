/// Zuralog Edge Agent — Sync Status Store.
///
/// Persists the last successful background sync timestamp using
/// SharedPreferences. Provides a lightweight way to display sync
/// status in the harness and future UI without requiring a full
/// database table.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Stores and retrieves the last successful sync timestamp.
///
/// Uses SharedPreferences for persistence across app restarts.
/// The timestamp is stored as milliseconds since epoch.
class SyncStatusStore {
  /// SharedPreferences key for the last sync timestamp.
  static const _lastSyncKey = 'last_sync_timestamp';

  /// SharedPreferences key for the sync-in-progress flag.
  static const _syncInProgressKey = 'sync_in_progress';

  /// Records the current time as the last successful sync.
  ///
  /// Call this after a background sync completes successfully.
  Future<void> recordSuccessfulSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setBool(_syncInProgressKey, false);
  }

  /// Marks a sync as currently in progress.
  Future<void> markSyncStarted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncInProgressKey, true);
  }

  /// Returns the last successful sync time, or `null` if never synced.
  ///
  /// Returns: [DateTime] of last sync, or `null` if no sync has occurred.
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastSyncKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Returns whether a sync is currently in progress.
  ///
  /// Returns: `true` if a sync was started but not completed.
  Future<bool> isSyncInProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncInProgressKey) ?? false;
  }
}
