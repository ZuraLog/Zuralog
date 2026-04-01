/// Zuralog — Coach Draft Service.
///
/// Persists the user's in-progress message draft for each conversation so
/// that switching away and back does not lose what they were typing.
///
/// Drafts are stored in [SharedPreferences] under the key
/// `coach_draft_{conversationId}`. After the initial async load in
/// [main.dart], [SharedPreferences] caches all values in memory, making
/// [getString] effectively synchronous on subsequent reads.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/storage/prefs_service.dart';

// ── Key helper ────────────────────────────────────────────────────────────────

String _key(String conversationId) => 'coach_draft_$conversationId';

// ── CoachDraftService ─────────────────────────────────────────────────────────

/// Thin wrapper around [SharedPreferences] for reading and writing per-
/// conversation message drafts.
final class CoachDraftService {
  /// Creates a [CoachDraftService] backed by [prefs].
  const CoachDraftService(this._prefs);

  final SharedPreferences _prefs;

  /// Returns the saved draft for [conversationId], or `null` if none exists.
  ///
  /// This read is synchronous — [SharedPreferences] caches values in memory
  /// after the async initialisation that happens before [runApp].
  String? loadDraft(String conversationId) {
    return _prefs.getString(_key(conversationId));
  }

  /// Saves [text] as the draft for [conversationId].
  ///
  /// If [text] is blank after trimming, the stored key is removed instead of
  /// writing an empty string, keeping storage clean.
  Future<void> saveDraft(String conversationId, String text) async {
    if (text.trim().isEmpty) {
      await _prefs.remove(_key(conversationId));
    } else {
      await _prefs.setString(_key(conversationId), text);
    }
  }

  /// Removes any saved draft for [conversationId].
  Future<void> clearDraft(String conversationId) async {
    await _prefs.remove(_key(conversationId));
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Provides a singleton [CoachDraftService] backed by the app-wide
/// [SharedPreferences] instance.
final coachDraftServiceProvider = Provider<CoachDraftService>((ref) {
  return CoachDraftService(ref.read(prefsProvider));
});
