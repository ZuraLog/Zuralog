library;

/// A locally-stored record of one supplement "taken" tap.
///
/// Written to SharedPreferences immediately on tap (write-first pattern).
/// [synced] becomes true after the backend confirms the log via POST /api/v1/ingest.
/// [logId] is the server-assigned UUID of the quick_logs row (needed for undo/delete).
class SupplementTakenLog {
  const SupplementTakenLog({
    required this.id,
    required this.supplementId,
    required this.logDate,
    required this.recordedAt,
    this.logId,
    this.synced = false,
  });

  /// Local UUID generated at tap time (not the server's log row ID).
  final String id;
  final String supplementId;

  /// ISO date string: 'YYYY-MM-DD' — used as part of the SharedPreferences key.
  final String logDate;

  /// Full timestamp used when syncing to the backend.
  final DateTime recordedAt;

  /// Server-assigned log row UUID. Null until successfully synced.
  final String? logId;

  final bool synced;

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplementId': supplementId,
        'logDate': logDate,
        'recordedAt': recordedAt.toIso8601String(),
        if (logId != null) 'logId': logId,
        'synced': synced,
      };

  factory SupplementTakenLog.fromJson(Map<String, dynamic> json) =>
      SupplementTakenLog(
        id: json['id'] as String,
        supplementId: json['supplementId'] as String,
        logDate: json['logDate'] as String,
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        logId: json['logId'] as String?,
        synced: (json['synced'] as bool?) ?? false,
      );

  SupplementTakenLog copyWith({
    String? id,
    String? supplementId,
    String? logDate,
    DateTime? recordedAt,
    String? Function()? logId,
    bool? synced,
  }) =>
      SupplementTakenLog(
        id: id ?? this.id,
        supplementId: supplementId ?? this.supplementId,
        logDate: logDate ?? this.logDate,
        recordedAt: recordedAt ?? this.recordedAt,
        logId: logId != null ? logId() : this.logId,
        synced: synced ?? this.synced,
      );
}
