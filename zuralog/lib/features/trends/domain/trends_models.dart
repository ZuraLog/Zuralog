/// Zuralog — Trends Tab Domain Models.
///
/// Covers all data structures for:
///   - Trends Home (correlation highlights, time-machine summaries)
///   - Correlations Explorer (metric pairs, scatter data, Pearson coefficient)
///   - Reports (monthly generated reports, category summaries)
///   - Data Sources (per-integration provenance info)
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
  });

  /// Top AI-surfaced correlation cards (up to 5).
  final List<CorrelationHighlight> correlationHighlights;

  /// Time-machine strips — most recent first (up to 12 periods).
  final List<TimePeriodSummary> timePeriods;

  /// Whether the user has enough data for correlations to be meaningful.
  final bool hasEnoughData;

  /// AI-suggested data gaps that would unlock new correlations.
  final List<CorrelationSuggestion> suggestionCards;

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

// ── Correlation Explorer Models ───────────────────────────────────────────────

/// A selectable metric for the two-metric picker.
class AvailableMetric {
  const AvailableMetric({
    required this.id,
    required this.label,
    required this.category,
    required this.unit,
  });

  /// Metric identifier (e.g., "steps", "sleep_score").
  final String id;

  /// Display label (e.g., "Daily Steps").
  final String label;

  /// Health category (e.g., "activity", "sleep").
  final String category;

  /// Unit string.
  final String unit;

  factory AvailableMetric.fromJson(Map<String, dynamic> json) {
    return AvailableMetric(
      id: json['id'] as String,
      label: json['label'] as String,
      category: json['category'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
    );
  }
}

/// A single data point in a scatter plot (x = metric A, y = metric B).
class ScatterPoint {
  const ScatterPoint({required this.x, required this.y, required this.date});

  final double x;
  final double y;

  /// ISO-8601 date string for this observation.
  final String date;

  factory ScatterPoint.fromJson(Map<String, dynamic> json) {
    return ScatterPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      date: json['date'] as String,
    );
  }
}

/// Result of a correlation analysis between two metrics.
class CorrelationAnalysis {
  const CorrelationAnalysis({
    required this.metricA,
    required this.metricB,
    required this.coefficient,
    required this.interpretation,
    required this.aiAnnotation,
    required this.scatterPoints,
    required this.lagDays,
    required this.timeRange,
  });

  final AvailableMetric metricA;
  final AvailableMetric metricB;

  /// Pearson coefficient [-1.0, 1.0].
  final double coefficient;

  /// Plain-language interpretation (e.g., "Strong positive correlation").
  final String interpretation;

  /// AI explanation of the relationship.
  final String aiAnnotation;

  /// Scatter plot data points.
  final List<ScatterPoint> scatterPoints;

  /// Lag offset applied (0-3 days).
  final int lagDays;

  /// Time range used for analysis.
  final CorrelationTimeRange timeRange;

  factory CorrelationAnalysis.fromJson(Map<String, dynamic> json) {
    return CorrelationAnalysis(
      metricA:
          AvailableMetric.fromJson(json['metric_a'] as Map<String, dynamic>),
      metricB:
          AvailableMetric.fromJson(json['metric_b'] as Map<String, dynamic>),
      coefficient: (json['coefficient'] as num).toDouble(),
      interpretation: json['interpretation'] as String,
      aiAnnotation: json['ai_annotation'] as String,
      scatterPoints: (json['scatter_points'] as List<dynamic>? ?? [])
          .map((e) => ScatterPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      lagDays: json['lag_days'] as int? ?? 0,
      timeRange: CorrelationTimeRange.fromString(
          json['time_range'] as String? ?? '30d'),
    );
  }
}

/// Time range selector for correlation analysis.
enum CorrelationTimeRange {
  sevenDays,
  thirtyDays,
  ninetyDays,
  custom;

  static CorrelationTimeRange fromString(String value) {
    switch (value) {
      case '7d':
        return CorrelationTimeRange.sevenDays;
      case '90d':
        return CorrelationTimeRange.ninetyDays;
      case 'custom':
        return CorrelationTimeRange.custom;
      default:
        return CorrelationTimeRange.thirtyDays;
    }
  }

  String get apiSlug {
    switch (this) {
      case CorrelationTimeRange.sevenDays:
        return '7d';
      case CorrelationTimeRange.thirtyDays:
        return '30d';
      case CorrelationTimeRange.ninetyDays:
        return '90d';
      case CorrelationTimeRange.custom:
        return 'custom';
    }
  }

  String get label {
    switch (this) {
      case CorrelationTimeRange.sevenDays:
        return '7D';
      case CorrelationTimeRange.thirtyDays:
        return '30D';
      case CorrelationTimeRange.ninetyDays:
        return '90D';
      case CorrelationTimeRange.custom:
        return 'Custom';
    }
  }
}

/// Container for the list of available metrics.
class AvailableMetricList {
  const AvailableMetricList({required this.metrics});

  final List<AvailableMetric> metrics;

  factory AvailableMetricList.fromJson(Map<String, dynamic> json) {
    return AvailableMetricList(
      metrics: (json['metrics'] as List<dynamic>? ?? [])
          .map((e) => AvailableMetric.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── Reports Models ────────────────────────────────────────────────────────────

/// A single generated monthly report.
class GeneratedReport {
  const GeneratedReport({
    required this.id,
    required this.title,
    required this.periodStart,
    required this.periodEnd,
    required this.generatedAt,
    required this.categorySummaries,
    required this.topCorrelations,
    required this.aiRecommendations,
    required this.trendDirections,
    this.goalAdherence = const [],
  });

  final String id;

  /// e.g., "February 2026 Health Report".
  final String title;

  final String periodStart;
  final String periodEnd;
  final String generatedAt;

  /// Per-category summaries.
  final List<ReportCategorySummary> categorySummaries;

  /// Top correlations found in the period.
  final List<CorrelationHighlight> topCorrelations;

  /// AI-generated recommendations.
  final List<String> aiRecommendations;

  /// Metric trend directions (up/down/flat).
  final List<TrendDirection> trendDirections;

  /// Goal adherence breakdown for the period.
  final List<GoalAdherenceItem> goalAdherence;

  factory GeneratedReport.fromJson(Map<String, dynamic> json) {
    return GeneratedReport(
      id: json['id'] as String,
      title: json['title'] as String,
      periodStart: json['period_start'] as String,
      periodEnd: json['period_end'] as String,
      generatedAt: json['generated_at'] as String,
      categorySummaries:
          (json['category_summaries'] as List<dynamic>? ?? [])
              .map((e) =>
                  ReportCategorySummary.fromJson(e as Map<String, dynamic>))
              .toList(),
      topCorrelations: (json['top_correlations'] as List<dynamic>? ?? [])
          .map((e) =>
              CorrelationHighlight.fromJson(e as Map<String, dynamic>))
          .toList(),
      aiRecommendations:
          (json['ai_recommendations'] as List<dynamic>? ?? [])
              .map((e) => e as String)
              .toList(),
      trendDirections: (json['trend_directions'] as List<dynamic>? ?? [])
          .map((e) => TrendDirection.fromJson(e as Map<String, dynamic>))
          .toList(),
      goalAdherence: (json['goal_adherence'] as List<dynamic>? ?? [])
          .map((e) => GoalAdherenceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Category-level summary within a monthly report.
class ReportCategorySummary {
  const ReportCategorySummary({
    required this.category,
    required this.categoryLabel,
    required this.averageScore,
    required this.deltaVsPrior,
    required this.keyMetric,
    required this.keyMetricValue,
  });

  final String category;
  final String categoryLabel;
  final int averageScore;
  final double deltaVsPrior;
  final String keyMetric;
  final String keyMetricValue;

  factory ReportCategorySummary.fromJson(Map<String, dynamic> json) {
    return ReportCategorySummary(
      category: json['category'] as String,
      categoryLabel: json['category_label'] as String,
      averageScore: json['average_score'] as int? ?? 0,
      deltaVsPrior: (json['delta_vs_prior'] as num? ?? 0).toDouble(),
      keyMetric: json['key_metric'] as String? ?? '',
      keyMetricValue: json['key_metric_value'] as String? ?? '',
    );
  }
}

/// Direction of a metric trend.
class TrendDirection {
  const TrendDirection({
    required this.metricLabel,
    required this.direction,
    required this.changePercent,
  });

  final String metricLabel;

  /// "up", "down", or "flat".
  final String direction;
  final double changePercent;

  factory TrendDirection.fromJson(Map<String, dynamic> json) {
    return TrendDirection(
      metricLabel: json['metric_label'] as String,
      direction: json['direction'] as String? ?? 'flat',
      changePercent: (json['change_percent'] as num? ?? 0).toDouble(),
    );
  }
}

/// Goal adherence entry within a monthly report.
class GoalAdherenceItem {
  const GoalAdherenceItem({
    required this.goalLabel,
    required this.targetValue,
    required this.unit,
    required this.achievedPercent,
    required this.streakDays,
  });

  /// Display label for the goal (e.g., "10,000 Steps Daily").
  final String goalLabel;

  /// Target value as a string (e.g., "10000").
  final String targetValue;

  /// Unit string (e.g., "steps", "hrs").
  final String unit;

  /// How often the goal was hit, 0.0–1.0.
  final double achievedPercent;

  /// Consecutive days goal was met at end of period.
  final int streakDays;

  factory GoalAdherenceItem.fromJson(Map<String, dynamic> json) {
    return GoalAdherenceItem(
      goalLabel: json['goal_label'] as String,
      targetValue: json['target_value'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      achievedPercent: (json['achieved_percent'] as num? ?? 0).toDouble(),
      streakDays: json['streak_days'] as int? ?? 0,
    );
  }
}

/// Paginated list of generated reports.
class ReportList {
  const ReportList({required this.reports, required this.hasMore});

  final List<GeneratedReport> reports;
  final bool hasMore;

  factory ReportList.fromJson(Map<String, dynamic> json) {
    return ReportList(
      reports: (json['reports'] as List<dynamic>? ?? [])
          .map((e) => GeneratedReport.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

// ── Data Sources Models ───────────────────────────────────────────────────────

/// Staleness level for an integration's data freshness.
enum DataFreshness {
  fresh,
  stale,
  error;

  static DataFreshness fromString(String value) {
    switch (value) {
      case 'fresh':
        return DataFreshness.fresh;
      case 'stale':
        return DataFreshness.stale;
      default:
        return DataFreshness.error;
    }
  }
}

/// Per-integration data provenance info for the Data Sources screen.
class DataSource {
  const DataSource({
    required this.integrationId,
    required this.name,
    required this.isConnected,
    required this.lastSyncedAt,
    required this.freshness,
    required this.dataTypes,
    required this.hasError,
    this.errorMessage,
  });

  /// Unique integration ID (e.g., "strava", "apple_health").
  final String integrationId;

  /// Display name (e.g., "Strava", "Apple Health").
  final String name;

  final bool isConnected;

  /// ISO-8601 timestamp of last successful sync (null if never synced).
  final String? lastSyncedAt;

  final DataFreshness freshness;

  /// List of data types contributed (e.g., ["Running", "Cycling"]).
  final List<String> dataTypes;

  final bool hasError;

  /// Error message if [hasError] is true.
  final String? errorMessage;

  factory DataSource.fromJson(Map<String, dynamic> json) {
    return DataSource(
      integrationId: json['integration_id'] as String,
      name: json['name'] as String,
      isConnected: json['is_connected'] as bool? ?? false,
      lastSyncedAt: json['last_synced_at'] as String?,
      freshness: DataFreshness.fromString(json['freshness'] as String? ?? 'error'),
      dataTypes: (json['data_types'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      hasError: json['has_error'] as bool? ?? false,
      errorMessage: json['error_message'] as String?,
    );
  }
}

/// Container for the full list of data sources.
class DataSourceList {
  const DataSourceList({required this.sources});

  final List<DataSource> sources;

  factory DataSourceList.fromJson(Map<String, dynamic> json) {
    return DataSourceList(
      sources: (json['sources'] as List<dynamic>? ?? [])
          .map((e) => DataSource.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
