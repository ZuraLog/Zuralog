/// Zuralog — Score History Domain Models.
///
/// Models for the health score history endpoint response.
/// Used by the ScoreTrendHero widget on the Data tab.
library;

// ── ScoreHistoryRange ─────────────────────────────────────────────────────────

/// Available time range options for the score trend hero.
enum ScoreHistoryRange {
  sevenDays,
  thirtyDays,
  ninetyDays;

  String get label {
    switch (this) {
      case ScoreHistoryRange.sevenDays:
        return '7D';
      case ScoreHistoryRange.thirtyDays:
        return '30D';
      case ScoreHistoryRange.ninetyDays:
        return '90D';
    }
  }

  String get apiParam {
    switch (this) {
      case ScoreHistoryRange.sevenDays:
        return '7d';
      case ScoreHistoryRange.thirtyDays:
        return '30d';
      case ScoreHistoryRange.ninetyDays:
        return '90d';
    }
  }
}

// ── ScoreHistoryData ──────────────────────────────────────────────────────────

/// History data for a single time range.
class ScoreHistoryData {
  const ScoreHistoryData({
    required this.range,
    required this.scores,
    this.average,
    this.min,
    this.max,
    this.trendDirection = 'stable',
  });

  final String range;

  /// Ordered score entries (oldest first).
  final List<ScoreEntry> scores;

  final int? average;
  final int? min;
  final int? max;

  /// One of 'improving', 'declining', 'stable'.
  final String trendDirection;

  /// Convenience: extract score values as doubles for sparkline.
  List<double> get trendValues =>
      scores.map((e) => e.score != null ? e.score!.toDouble() : 0.0).toList();

  factory ScoreHistoryData.fromJson(Map<String, dynamic> json) {
    final rawScores = json['scores'] as List<dynamic>? ?? [];
    return ScoreHistoryData(
      range: json['range'] as String? ?? '30d',
      scores: rawScores
          .map((e) => ScoreEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      average: (json['average'] as num?)?.toInt(),
      min: (json['min'] as num?)?.toInt(),
      max: (json['max'] as num?)?.toInt(),
      trendDirection: json['trend_direction'] as String? ?? 'stable',
    );
  }

  /// Empty placeholder used during loading or on error.
  static const ScoreHistoryData empty = ScoreHistoryData(
    range: '30d',
    scores: [],
    trendDirection: 'stable',
  );
}

// ── ScoreEntry ────────────────────────────────────────────────────────────────

/// A single date-score pair.
class ScoreEntry {
  const ScoreEntry({required this.date, this.score});

  final String date;
  final int? score;

  factory ScoreEntry.fromJson(Map<String, dynamic> json) {
    return ScoreEntry(
      date: json['date'] as String? ?? '',
      score: (json['score'] as num?)?.toInt(),
    );
  }
}
