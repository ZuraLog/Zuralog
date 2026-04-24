library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/body/domain/muscle_log.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

String _logsKey(String date) => 'muscle_logs_$date';

class MuscleLogRepository {
  const MuscleLogRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Returns all logs for [date] (ISO date string 'YYYY-MM-DD').
  List<MuscleLog> getLogsForDate(String date) {
    final raw = _prefs.getString(_logsKey(date));
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => MuscleLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns the log for a specific muscle on [date], or null.
  MuscleLog? getLogForMuscle(String date, MuscleGroup group) {
    return getLogsForDate(date)
        .where((l) => l.muscleGroup == group)
        .firstOrNull;
  }

  /// Saves (upserts) a [log]. Replaces any existing entry for the same
  /// muscle + date combination.
  Future<void> saveLog(MuscleLog log) async {
    final existing = getLogsForDate(log.logDate)
        .where((l) => l.muscleGroup != log.muscleGroup)
        .toList();
    existing.add(log);
    await _prefs.setString(
      _logsKey(log.logDate),
      jsonEncode(existing.map((e) => e.toJson()).toList()),
    );
  }

  /// Removes the log for [group] on [date].
  Future<void> removeLog(String date, MuscleGroup group) async {
    final updated = getLogsForDate(date)
        .where((l) => l.muscleGroup != group)
        .toList();
    if (updated.isEmpty) {
      await _prefs.remove(_logsKey(date));
    } else {
      await _prefs.setString(
        _logsKey(date),
        jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
    }
  }

  /// Deletes all logs for [date].
  Future<void> clearLogsForDate(String date) async {
    await _prefs.remove(_logsKey(date));
  }
}

final muscleLogRepositoryProvider = Provider<MuscleLogRepository>((ref) {
  final prefs = ref.watch(prefsProvider);
  return MuscleLogRepository(prefs);
});
