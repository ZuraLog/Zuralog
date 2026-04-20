library;

class HeartSource {
  const HeartSource({
    required this.name,
    required this.icon,
    required this.brandColor,
  });

  final String name;
  final String icon;
  final String brandColor;

  factory HeartSource.fromJson(Map<String, dynamic> json) => HeartSource(
        name: json['name'] as String,
        icon: json['icon'] as String,
        brandColor: json['brand_color'] as String,
      );
}

class HeartDaySummary {
  const HeartDaySummary({
    required this.hasData,
    this.restingHr,
    this.hrvMs,
    this.avgHr,
    this.respiratoryRate,
    this.vo2Max,
    this.spo2,
    this.bpSystolic,
    this.bpDiastolic,
    this.restingHrVs7Day,
    this.hrvVs7Day,
    this.aiSummary,
    this.aiGeneratedAt,
    this.sources = const [],
  });

  final bool hasData;
  final double? restingHr;
  final double? hrvMs;
  final double? avgHr;
  final double? respiratoryRate;
  final double? vo2Max;
  final double? spo2;
  final double? bpSystolic;
  final double? bpDiastolic;
  final double? restingHrVs7Day;
  final double? hrvVs7Day;
  final String? aiSummary;
  final DateTime? aiGeneratedAt;
  final List<HeartSource> sources;

  static const HeartDaySummary empty = HeartDaySummary(hasData: false);

  factory HeartDaySummary.fromJson(Map<String, dynamic> json) =>
      HeartDaySummary(
        hasData: json['has_data'] as bool,
        restingHr: (json['resting_hr'] as num?)?.toDouble(),
        hrvMs: (json['hrv_ms'] as num?)?.toDouble(),
        avgHr: (json['avg_hr'] as num?)?.toDouble(),
        respiratoryRate: (json['respiratory_rate'] as num?)?.toDouble(),
        vo2Max: (json['vo2_max'] as num?)?.toDouble(),
        spo2: (json['spo2'] as num?)?.toDouble(),
        bpSystolic: (json['bp_systolic'] as num?)?.toDouble(),
        bpDiastolic: (json['bp_diastolic'] as num?)?.toDouble(),
        restingHrVs7Day: (json['resting_hr_vs_7day'] as num?)?.toDouble(),
        hrvVs7Day: (json['hrv_vs_7day'] as num?)?.toDouble(),
        aiSummary: json['ai_summary'] as String?,
        aiGeneratedAt: json['ai_generated_at'] != null
            ? DateTime.tryParse(json['ai_generated_at'] as String)
            : null,
        sources: (json['sources'] as List<dynamic>? ?? [])
            .map((e) => HeartSource.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class HeartTrendDay {
  const HeartTrendDay({
    required this.date,
    required this.isToday,
    this.restingHr,
    this.hrvMs,
  });

  final String date;
  final bool isToday;
  final double? restingHr;
  final double? hrvMs;

  factory HeartTrendDay.fromJson(Map<String, dynamic> json) => HeartTrendDay(
        date: json['date'] as String,
        isToday: json['is_today'] as bool,
        restingHr: (json['resting_hr'] as num?)?.toDouble(),
        hrvMs: (json['hrv_ms'] as num?)?.toDouble(),
      );
}
