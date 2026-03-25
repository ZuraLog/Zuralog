/// Zuralog — Trends Tab Domain Models.
///
/// Covers all data structures for:
///   - Trends Home (correlation highlights, time-machine summaries)
///   - Pattern card expansion (chart series, AI explanation)
library;

// ── Correlation Models ────────────────────────────────────────────────────────

/// A single AI-surfaced correlation between two health metrics.
class CorrelationHighlight {
  const CorrelationHighlight({
    required this.id,
    required this.metricA,
    required this.metricB,
    required this.coefficient,
    required this.direction,
    required this.headline,
    required this.body,
    required this.categoryColorHex,
    this.category = 'activity',
    this.discoveredAt = '',
  });

  /// Unique identifier.
  final String id;

  /// Display name of the first metric (e.g., "Running Distance").
  final String metricA;

  /// Display name of the second metric (e.g., "Sleep Quality").
  final String metricB;

  /// Pearson correlation coefficient [-1.0, 1.0].
  final double coefficient;

  /// Whether the relationship is positive or negative.
  final CorrelationDirection direction;

  /// Short headline (e.g., "Sleep improves after run days").
  final String headline;

  /// AI explanation body text.
  final String body;

  /// Hex string for the category accent color (e.g., "#30D158").
  final String categoryColorHex;

  /// Health category slug (e.g., "sleep", "activity", "heart").
  final String category;

  /// ISO-8601 date string when this pattern was first discovered.
  final String discoveredAt;

  /// True if this pattern was discovered within the last 7 days.
  bool get isNew {
    if (discoveredAt.isEmpty) return false;
    final discovered = DateTime.tryParse(discoveredAt);
    if (discovered == null) return false;
    return DateTime.now().difference(discovered).inDays <= 7;
  }

  factory CorrelationHighlight.fromJson(Map<String, dynamic> json) {
    return CorrelationHighlight(
      id: json['id'] as String,
      metricA: json['metric_a'] as String,
      metricB: json['metric_b'] as String,
      coefficient: (json['coefficient'] as num).toDouble(),
      direction: CorrelationDirection.fromString(json['direction'] as String),
      headline: json['headline'] as String,
      body: json['body'] as String,
      categoryColorHex: json['category_color_hex'] as String? ?? '#CFE1B9',
      category: json['category'] as String? ?? 'activity',
      discoveredAt: json['discovered_at'] as String? ?? '',
    );
  }
}

/// Direction of a correlation relationship.
enum CorrelationDirection {
  positive,
  negative,
  neutral;

  static CorrelationDirection fromString(String value) {
    switch (value) {
      case 'positive':
        return CorrelationDirection.positive;
      case 'negative':
        return CorrelationDirection.negative;
      default:
        return CorrelationDirection.neutral;
    }
  }

  String get label {
    switch (this) {
      case CorrelationDirection.positive:
        return 'Positive';
      case CorrelationDirection.negative:
        return 'Negative';
      case CorrelationDirection.neutral:
        return 'Neutral';
    }
  }
}

// ── Time Machine ─────────────────────────────────────────────────────────────

/// A single period summary for the time-machine strip.
class TimePeriodSummary {
  const TimePeriodSummary({
    required this.label,
    required this.periodStart,
    required this.periodEnd,
    required this.highlights,
    required this.overallScore,
  });

  /// Human-readable label (e.g., "Feb 24 – Mar 2").
  final String label;

  /// ISO-8601 start date string.
  final String periodStart;

  /// ISO-8601 end date string.
  final String periodEnd;

  /// Up to 3 metric highlights for this period.
  final List<MetricHighlight> highlights;

  /// Overall health score for this period [0-100].
  final int overallScore;

  factory TimePeriodSummary.fromJson(Map<String, dynamic> json) {
    return TimePeriodSummary(
      label: json['label'] as String,
      periodStart: json['period_start'] as String,
      periodEnd: json['period_end'] as String,
      highlights: (json['highlights'] as List<dynamic>? ?? [])
          .map((e) => MetricHighlight.fromJson(e as Map<String, dynamic>))
          .toList(),
      overallScore: json['overall_score'] as int? ?? 0,
    );
  }
}

/// A single metric highlight within a time-period summary.
class MetricHighlight {
  const MetricHighlight({
    required this.label,
    required this.value,
    required this.unit,
    required this.deltaPercent,
  });

  /// Metric display name (e.g., "Steps").
  final String label;

  /// Formatted metric value string (e.g., "8,240").
  final String value;

  /// Unit string (e.g., "steps", "hrs").
  final String unit;

  /// Percent change vs prior period (positive = improvement).
  final double deltaPercent;

  factory MetricHighlight.fromJson(Map<String, dynamic> json) {
    return MetricHighlight(
      label: json['label'] as String,
      value: json['value'] as String,
      unit: json['unit'] as String? ?? '',
      deltaPercent: (json['delta_percent'] as num? ?? 0).toDouble(),
    );
  }
}

// ── Trends Home Aggregated ────────────────────────────────────────────────────

/// Aggregated data for the Trends Home screen.
class TrendsHomeData {
  const TrendsHomeData({
    required this.correlationHighlights,
    required this.timePeriods,
    required this.hasEnoughData,
    this.suggestionCards = const [],
    this.patternCount = 0,
  });

  /// Top AI-surfaced correlation cards (up to 5).
  final List<CorrelationHighlight> correlationHighlights;

  /// Time-machine strips — most recent first (up to 12 periods).
  final List<TimePeriodSummary> timePeriods;

  /// Whether the user has enough data for correlations to be meaningful.
  final bool hasEnoughData;

  /// AI-suggested data gaps that would unlock new correlations.
  final List<CorrelationSuggestion> suggestionCards;

  /// Total number of patterns found across all categories.
  final int patternCount;

  factory TrendsHomeData.fromJson(Map<String, dynamic> json) {
    return TrendsHomeData(
      correlationHighlights:
          (json['correlation_highlights'] as List<dynamic>? ?? [])
              .map((e) =>
                  CorrelationHighlight.fromJson(e as Map<String, dynamic>))
              .toList(),
      timePeriods: (json['time_periods'] as List<dynamic>? ?? [])
          .map((e) => TimePeriodSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasEnoughData: json['has_enough_data'] as bool? ?? false,
      suggestionCards: (json['suggestion_cards'] as List<dynamic>? ?? [])
          .map((e) => CorrelationSuggestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      patternCount: json['pattern_count'] as int? ?? 0,
    );
  }
}

/// A suggestion card shown when the AI detects a data gap that would unlock
/// a new correlation (e.g., "Start tracking stress to see how it affects sleep").
class CorrelationSuggestion {
  const CorrelationSuggestion({
    required this.id,
    required this.metricNeeded,
    required this.description,
    required this.ctaLabel,
    required this.ctaRoute,
  });

  /// Unique suggestion ID.
  final String id;

  /// Metric the user needs to start tracking.
  final String metricNeeded;

  /// One-sentence explanation of the value.
  final String description;

  /// Call-to-action label (e.g., "Connect App", "Start Logging").
  final String ctaLabel;

  /// Route to navigate to on CTA tap (e.g., settings integrations path).
  final String ctaRoute;

  factory CorrelationSuggestion.fromJson(Map<String, dynamic> json) {
    return CorrelationSuggestion(
      id: json['id'] as String,
      metricNeeded: json['metric_needed'] as String,
      description: json['description'] as String,
      ctaLabel: json['cta_label'] as String? ?? 'Connect App',
      ctaRoute: json['cta_route'] as String? ?? '/settings/integrations',
    );
  }
}

// ── Pattern Expand Models ─────────────────────────────────────────────────────

/// A single data point in a time-series chart (date + value).
class ChartSeriesPoint {
  const ChartSeriesPoint({required this.date, required this.value});

  /// ISO-8601 date string.
  final String date;

  /// Numeric value for this data point.
  final double value;

  factory ChartSeriesPoint.fromJson(Map<String, dynamic> json) {
    return ChartSeriesPoint(
      date: json['date'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }
}

/// Full detail data loaded when a pattern card is expanded in-place.
class PatternExpandData {
  const PatternExpandData({
    required this.id,
    required this.seriesA,
    required this.seriesB,
    required this.seriesALabel,
    required this.seriesBLabel,
    required this.aiExplanation,
    required this.dataSources,
    required this.dataDays,
    required this.timeRange,
  });

  /// Pattern identifier — matches [CorrelationHighlight.id].
  final String id;

  /// Time-series data points for metric A.
  final List<ChartSeriesPoint> seriesA;

  /// Time-series data points for metric B.
  final List<ChartSeriesPoint> seriesB;

  /// Display label for series A (e.g., "Running Distance").
  final String seriesALabel;

  /// Display label for series B (e.g., "Sleep Quality").
  final String seriesBLabel;

  /// AI-generated explanation of the relationship.
  final String aiExplanation;

  /// Integration names that contributed data (e.g., ["Strava", "Apple Health"]).
  final List<String> dataSources;

  /// Number of days of data used in the analysis.
  final int dataDays;

  /// Time range slug used for the analysis (e.g., "30d", "90d").
  final String timeRange;

  factory PatternExpandData.fromJson(Map<String, dynamic> json) {
    return PatternExpandData(
      id: json['id'] as String,
      seriesA: (json['series_a'] as List<dynamic>? ?? [])
          .map((e) => ChartSeriesPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      seriesB: (json['series_b'] as List<dynamic>? ?? [])
          .map((e) => ChartSeriesPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      seriesALabel: json['series_a_label'] as String? ?? '',
      seriesBLabel: json['series_b_label'] as String? ?? '',
      aiExplanation: json['ai_explanation'] as String? ?? '',
      dataSources: (json['data_sources'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      dataDays: json['data_days'] as int? ?? 0,
      timeRange: json['time_range'] as String? ?? '30d',
    );
  }
}
