library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/core/storage/prefs_service.dart';

const _kCheckinSeenKey = 'checkin_seen_date';

class CheckInNotifier extends StateNotifier<String?> {
  CheckInNotifier(this._prefs) : super(_prefs.getString(_kCheckinSeenKey));

  final SharedPreferences _prefs;

  /// Call when the user taps the check-in button to dismiss for today.
  Future<void> markSeen(String date) async {
    await _prefs.setString(_kCheckinSeenKey, date);
    state = date;
  }
}

final checkInProvider =
    StateNotifierProvider<CheckInNotifier, String?>((ref) {
  final prefs = ref.watch(prefsProvider);
  return CheckInNotifier(prefs);
});
