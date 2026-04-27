library;

/// A locally-stored record of one supplement "taken" tap.
///
/// Written to SharedPreferences immediately on tap (write-first pattern).
/// [synced] becomes true after the backend confirms the log via POST /api/v1/ingest.
/// [logId] is the server-assigned UUID of the quick_logs row (needed for undo/delete).
///
/// Ad-hoc logs (one-off supplements not in the user's stack) are identified
/// by a [supplementId] prefixed with 'adhoc_'. The [isAdHoc] getter
/// reflects this. Ad-hoc logs carry name/dose metadata inline.
class SupplementTakenLog {
  const SupplementTakenLog({
    required this.id,
    required this.supplementId,
    required this.logDate,
    required this.recordedAt,
    this.logId,
    this.synced = false,
    this.adHocName,
    this.adHocDoseAmount,
    this.adHocDoseUnit,
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

  /// For ad-hoc one-off logs: the supplement name the user typed.
  final String? adHocName;

  /// For ad-hoc one-off logs: numeric dose amount (e.g. 18.0).
  final double? adHocDoseAmount;

  /// For ad-hoc one-off logs: dose unit string (e.g. 'mg', 'IU').
  final String? adHocDoseUnit;

  /// True when this log is a one-off ad-hoc entry (not from the user's stack).
  bool get isAdHoc => supplementId.startsWith('adhoc_');

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplementId': supplementId,
        'logDate': logDate,
        'recordedAt': recordedAt.toIso8601String(),
        if (logId != null) 'logId': logId,
        'synced': synced,
        if (adHocName != null) 'adHocName': adHocName,
        if (adHocDoseAmount != null) 'adHocDoseAmount': adHocDoseAmount,
        if (adHocDoseUnit != null) 'adHocDoseUnit': adHocDoseUnit,
      };

  factory SupplementTakenLog.fromJson(Map<String, dynamic> json) =>
      SupplementTakenLog(
        id: json['id'] as String,
        supplementId: json['supplementId'] as String,
        logDate: json['logDate'] as String,
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        logId: json['logId'] as String?,
        synced: (json['synced'] as bool?) ?? false,
        adHocName: json['adHocName'] as String?,
        adHocDoseAmount: (json['adHocDoseAmount'] as num?)?.toDouble(),
        adHocDoseUnit: json['adHocDoseUnit'] as String?,
      );

  SupplementTakenLog copyWith({
    String? id,
    String? supplementId,
    String? logDate,
    DateTime? recordedAt,
    String? Function()? logId,
    bool? synced,
    String? Function()? adHocName,
    double? Function()? adHocDoseAmount,
    String? Function()? adHocDoseUnit,
  }) =>
      SupplementTakenLog(
        id: id ?? this.id,
        supplementId: supplementId ?? this.supplementId,
        logDate: logDate ?? this.logDate,
        recordedAt: recordedAt ?? this.recordedAt,
        logId: logId != null ? logId() : this.logId,
        synced: synced ?? this.synced,
        adHocName: adHocName != null ? adHocName() : this.adHocName,
        adHocDoseAmount: adHocDoseAmount != null ? adHocDoseAmount() : this.adHocDoseAmount,
        adHocDoseUnit: adHocDoseUnit != null ? adHocDoseUnit() : this.adHocDoseUnit,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplementTakenLog &&
          id == other.id &&
          supplementId == other.supplementId &&
          logDate == other.logDate &&
          recordedAt == other.recordedAt &&
          logId == other.logId &&
          synced == other.synced &&
          adHocName == other.adHocName &&
          adHocDoseAmount == other.adHocDoseAmount &&
          adHocDoseUnit == other.adHocDoseUnit;

  @override
  int get hashCode => Object.hash(
        id,
        supplementId,
        logDate,
        recordedAt,
        logId,
        synced,
        adHocName,
        adHocDoseAmount,
        adHocDoseUnit,
      );
}
