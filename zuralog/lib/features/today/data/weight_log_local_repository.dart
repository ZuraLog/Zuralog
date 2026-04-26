library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/today/domain/weight_log.dart';

String _logsKey(String date) => 'weight_logs_$date';

class WeightLogLocalRepository {
  const WeightLogLocalRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Returns all weight logs for [date] (ISO date string 'YYYY-MM-DD').
  List<WeightLog> getLogsForDate(String date) {
    final raw = _prefs.getString(_logsKey(date));
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => WeightLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Appends [log] to the stored list for its date.
  Future<void> saveLog(WeightLog log) async {
    final existing = getLogsForDate(log.logDate);
    existing.add(log);
    await _prefs.setString(
      _logsKey(log.logDate),
      jsonEncode(existing.map((e) => e.toJson()).toList()),
    );
  }

  /// Marks the log with [logId] on [date] as synced.
  Future<void> markSynced(String logId, String date) async {
    final logs = getLogsForDate(date);
    final idx = logs.indexWhere((l) => l.id == logId);
    if (idx == -1) return;
    logs[idx] = logs[idx].copyWith(synced: true);
    await _prefs.setString(
      _logsKey(date),
      jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }
}

final weightLogLocalRepositoryProvider =
    Provider<WeightLogLocalRepository>((ref) {
  return WeightLogLocalRepository(ref.watch(prefsProvider));
});
