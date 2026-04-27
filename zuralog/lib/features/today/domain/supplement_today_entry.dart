library;

/// A single entry from `GET /api/v1/supplements/today-log`.
///
/// Tells the UI which supplement was taken today and what log row
/// backs it (used for the delete / undo operation).
class SupplementTodayLogEntry {
  const SupplementTodayLogEntry({
    required this.supplementId,
    required this.logId,
  });

  final String supplementId;
  final String logId;
}

/// Parses the `{ "entries": [...] }` response body from the today-log endpoint.
List<SupplementTodayLogEntry> parseTodayLogResponse(
    Map<String, dynamic> json) {
  final raw = json['entries'] as List<dynamic>? ?? [];
  return raw
      .map((e) => SupplementTodayLogEntry(
            supplementId: e['supplement_id'] as String,
            logId: e['log_id'] as String,
          ))
      .toList();
}
