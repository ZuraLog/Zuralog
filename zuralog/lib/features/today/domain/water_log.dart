library;

class WaterLog {
  const WaterLog({
    required this.id,
    required this.amountMl,
    required this.logDate,
    required this.loggedAtTime,
    required this.recordedAt,
    this.vesselKey,
    this.synced = false,
  });

  final String id;
  final double amountMl;
  final String? vesselKey;

  /// ISO date string: 'YYYY-MM-DD'
  final String logDate;

  /// 24-hour time string: 'HH:mm'
  final String loggedAtTime;

  /// Full timestamp used when syncing to the backend.
  final DateTime recordedAt;

  final bool synced;

  Map<String, dynamic> toJson() => {
        'id': id,
        'amountMl': amountMl,
        if (vesselKey != null) 'vesselKey': vesselKey,
        'logDate': logDate,
        'loggedAtTime': loggedAtTime,
        'recordedAt': recordedAt.toIso8601String(),
        'synced': synced,
      };

  factory WaterLog.fromJson(Map<String, dynamic> json) => WaterLog(
        id: json['id'] as String,
        amountMl: (json['amountMl'] as num).toDouble(),
        vesselKey: json['vesselKey'] as String?,
        logDate: json['logDate'] as String,
        loggedAtTime: json['loggedAtTime'] as String,
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        synced: (json['synced'] as bool?) ?? false,
      );

  WaterLog copyWith({
    String? id,
    double? amountMl,
    String? Function()? vesselKey,
    String? logDate,
    String? loggedAtTime,
    DateTime? recordedAt,
    bool? synced,
  }) =>
      WaterLog(
        id: id ?? this.id,
        amountMl: amountMl ?? this.amountMl,
        vesselKey: vesselKey != null ? vesselKey() : this.vesselKey,
        logDate: logDate ?? this.logDate,
        loggedAtTime: loggedAtTime ?? this.loggedAtTime,
        recordedAt: recordedAt ?? this.recordedAt,
        synced: synced ?? this.synced,
      );
}
