library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/today/domain/supplement_taken_log.dart';

String _logsKey(String date) => 'supplement_logs_$date';

class SupplementLogLocalRepository {
  const SupplementLogLocalRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Returns all supplement taken logs for [date] (ISO date string 'YYYY-MM-DD').
  List<SupplementTakenLog> getLogsForDate(String date) {
    final raw = _prefs.getString(_logsKey(date));
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SupplementTakenLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Appends [log] to the stored list for its date.
  Future<void> saveLog(SupplementTakenLog log) async {
    final existing = getLogsForDate(log.logDate);
    if (existing.any((l) => l.id == log.id)) return;
    existing.add(log);
    await _prefs.setString(
      _logsKey(log.logDate),
      jsonEncode(existing.map((e) => e.toJson()).toList()),
    );
  }

  /// Marks the log with [localId] on [date] as synced, storing [serverLogId].
  ///
  /// The [serverLogId] is the server-assigned quick_logs UUID needed for undo
  /// (DELETE /api/v1/ingest/<serverLogId>).
  Future<void> markSynced(String localId, String date,
      {required String serverLogId}) async {
    final logs = getLogsForDate(date);
    final idx = logs.indexWhere((l) => l.id == localId);
    if (idx == -1) return;
    logs[idx] = logs[idx].copyWith(synced: true, logId: () => serverLogId);
    await _prefs.setString(
      _logsKey(date),
      jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }

  /// Removes the log with [localId] on [date] from local storage.
  ///
  /// Called when the user unchecks / undoes a supplement tap.
  Future<void> removeLog(String localId, String date) async {
    final logs = getLogsForDate(date)..removeWhere((l) => l.id == localId);
    await _prefs.setString(
      _logsKey(date),
      jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }
}

final supplementLogLocalRepositoryProvider =
    Provider<SupplementLogLocalRepository>((ref) {
  return SupplementLogLocalRepository(ref.watch(prefsProvider));
});
