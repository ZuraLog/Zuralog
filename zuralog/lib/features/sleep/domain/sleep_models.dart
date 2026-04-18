// zuralog/lib/features/sleep/domain/sleep_models.dart
library;

class SleepSource {
  const SleepSource({
    required this.name,
    required this.icon,
    required this.brandColor,
  });

  final String name;
  final String icon;
  final String brandColor;

  factory SleepSource.fromJson(Map<String, dynamic> json) => SleepSource(
        name: json['name'] as String,
        icon: json['icon'] as String,
        brandColor: json['brand_color'] as String,
      );
}

class HRPoint {
  const HRPoint({required this.time, required this.bpm});

  final DateTime time;
  final double bpm;

  factory HRPoint.fromJson(Map<String, dynamic> json) => HRPoint(
        time: DateTime.parse(json['time'] as String),
        bpm: (json['bpm'] as num).toDouble(),
      );
}

class SleepingHR {
  const SleepingHR({
    this.avgBpm,
    this.lowBpm,
    this.highBpm,
    this.curve = const [],
  });

  final double? avgBpm;
  final double? lowBpm;
  final double? highBpm;
  final List<HRPoint> curve;

  factory SleepingHR.fromJson(Map<String, dynamic> json) => SleepingHR(
        avgBpm: (json['avg_bpm'] as num?)?.toDouble(),
        lowBpm: (json['low_bpm'] as num?)?.toDouble(),
        highBpm: (json['high_bpm'] as num?)?.toDouble(),
        curve: (json['curve'] as List<dynamic>)
            .map((e) => HRPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SleepStages {
  const SleepStages({
    this.deepMinutes,
    this.remMinutes,
    this.lightMinutes,
    this.awakeMinutes,
  });

  final int? deepMinutes;
  final int? remMinutes;
  final int? lightMinutes;
  final int? awakeMinutes;

  bool get hasAnyData =>
      deepMinutes != null ||
      remMinutes != null ||
      lightMinutes != null ||
      awakeMinutes != null;

  int get totalMinutes =>
      (deepMinutes ?? 0) +
      (remMinutes ?? 0) +
      (lightMinutes ?? 0) +
      (awakeMinutes ?? 0);

  factory SleepStages.fromJson(Map<String, dynamic> json) => SleepStages(
        deepMinutes: json['deep_minutes'] as int?,
        remMinutes: json['rem_minutes'] as int?,
        lightMinutes: json['light_minutes'] as int?,
        awakeMinutes: json['awake_minutes'] as int?,
      );
}

class SleepDaySummary {
  const SleepDaySummary({
    required this.hasData,
    this.durationMinutes,
    this.bedtime,
    this.wakeTime,
    this.qualityRating,
    this.qualityLabel,
    this.sleepEfficiencyPct,
    this.avgVs7DayMinutes,
    this.stages,
    this.sleepingHr,
    this.factors = const [],
    this.interruptions,
    this.notes,
    this.aiSummary,
    this.aiGeneratedAt,
    this.sources = const [],
  });

  final bool hasData;
  final int? durationMinutes;
  final DateTime? bedtime;
  final DateTime? wakeTime;
  final int? qualityRating;
  final String? qualityLabel;
  final double? sleepEfficiencyPct;
  final int? avgVs7DayMinutes;
  final SleepStages? stages;
  final SleepingHR? sleepingHr;
  final List<String> factors;
  final int? interruptions;
  final String? notes;
  final String? aiSummary;
  final DateTime? aiGeneratedAt;
  final List<SleepSource> sources;

  static const SleepDaySummary empty = SleepDaySummary(hasData: false);

  factory SleepDaySummary.fromJson(Map<String, dynamic> json) =>
      SleepDaySummary(
        hasData: json['has_data'] as bool,
        durationMinutes: json['duration_minutes'] as int?,
        bedtime: json['bedtime'] != null
            ? DateTime.parse(json['bedtime'] as String)
            : null,
        wakeTime: json['wake_time'] != null
            ? DateTime.parse(json['wake_time'] as String)
            : null,
        qualityRating: json['quality_rating'] as int?,
        qualityLabel: json['quality_label'] as String?,
        sleepEfficiencyPct:
            (json['sleep_efficiency_pct'] as num?)?.toDouble(),
        avgVs7DayMinutes: json['avg_vs_7day_minutes'] as int?,
        stages: json['stages'] != null
            ? SleepStages.fromJson(json['stages'] as Map<String, dynamic>)
            : null,
        sleepingHr: json['sleeping_hr'] != null
            ? SleepingHR.fromJson(
                json['sleeping_hr'] as Map<String, dynamic>)
            : null,
        factors: (json['factors'] as List<dynamic>).cast<String>(),
        interruptions: json['interruptions'] as int?,
        notes: json['notes'] as String?,
        aiSummary: json['ai_summary'] as String?,
        aiGeneratedAt: json['ai_generated_at'] != null
            ? DateTime.parse(json['ai_generated_at'] as String)
            : null,
        sources: (json['sources'] as List<dynamic>)
            .map((e) => SleepSource.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SleepTrendDay {
  const SleepTrendDay({
    required this.date,
    this.durationMinutes,
    this.qualityRating,
    required this.isToday,
  });

  final String date;
  final int? durationMinutes;
  final int? qualityRating;
  final bool isToday;

  factory SleepTrendDay.fromJson(Map<String, dynamic> json) => SleepTrendDay(
        date: json['date'] as String,
        durationMinutes: json['duration_minutes'] as int?,
        qualityRating: json['quality_rating'] as int?,
        isToday: json['is_today'] as bool,
      );
}
