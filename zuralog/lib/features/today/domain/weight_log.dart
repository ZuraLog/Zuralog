library;

class WeightLog {
  const WeightLog({
    required this.id,
    required this.valueKg,
    required this.timeOfDay,
    required this.logDate,
    required this.loggedAtTime,
    required this.recordedAt,
    this.bodyFatPct,
    this.synced = false,
  });

  final String id;

  /// Always stored in kilograms regardless of the panel's display unit.
  final double valueKg;

  /// One of 'morning', 'afternoon', or 'evening'.
  final String timeOfDay;

  /// Optional body fat percentage (1.0–80.0). Null when not entered.
  final double? bodyFatPct;

  /// ISO date string: 'YYYY-MM-DD'
  final String logDate;

  /// 24-hour time string: 'HH:mm'
  final String loggedAtTime;

  /// Full timestamp used when syncing to the backend.
  final DateTime recordedAt;

  final bool synced;

  Map<String, dynamic> toJson() => {
        'id': id,
        'valueKg': valueKg,
        'timeOfDay': timeOfDay,
        if (bodyFatPct != null) 'bodyFatPct': bodyFatPct,
        'logDate': logDate,
        'loggedAtTime': loggedAtTime,
        'recordedAt': recordedAt.toIso8601String(),
        'synced': synced,
      };

  factory WeightLog.fromJson(Map<String, dynamic> json) => WeightLog(
        id: json['id'] as String,
        valueKg: (json['valueKg'] as num).toDouble(),
        timeOfDay: (json['timeOfDay'] as String?) ?? 'morning',
        bodyFatPct: (json['bodyFatPct'] as num?)?.toDouble(),
        logDate: json['logDate'] as String,
        loggedAtTime: json['loggedAtTime'] as String,
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        synced: (json['synced'] as bool?) ?? false,
      );

  WeightLog copyWith({
    String? id,
    double? valueKg,
    String? timeOfDay,
    double? Function()? bodyFatPct,
    String? logDate,
    String? loggedAtTime,
    DateTime? recordedAt,
    bool? synced,
  }) =>
      WeightLog(
        id: id ?? this.id,
        valueKg: valueKg ?? this.valueKg,
        timeOfDay: timeOfDay ?? this.timeOfDay,
        bodyFatPct: bodyFatPct != null ? bodyFatPct() : this.bodyFatPct,
        logDate: logDate ?? this.logDate,
        loggedAtTime: loggedAtTime ?? this.loggedAtTime,
        recordedAt: recordedAt ?? this.recordedAt,
        synced: synced ?? this.synced,
      );
}
