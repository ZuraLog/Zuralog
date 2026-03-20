/// Zuralog — Data Tab Domain Models.
///
/// Strongly-typed DTOs for all Data-tab API responses.
///
/// Model overview:
/// - [HealthCategory]       — enum of 10 health categories
/// - [CategorySummary]      — card-level summary for dashboard
/// - [DashboardData]        — aggregated dashboard payload
/// - [MetricDataPoint]      — single time-series data point
/// - [MetricSeries]         — named series of data points
/// - [CategoryDetail]       — full detail for one category
/// - [MetricDetail]         — deep-dive into one metric
/// - [DashboardLayout]      — persisted card order + visibility
library;

import 'package:flutter/foundation.dart';

// ── TileSize ──────────────────────────────────────────────────────────────────

/// The three supported tile sizes for the data dashboard grid.
enum TileSize { square, tall, wide }

// ── HealthCategory ────────────────────────────────────────────────────────────

/// The 10 supported health categories.
enum HealthCategory {
  activity,
  sleep,
  body,
  heart,
  vitals,
  nutrition,
  cycle,
  wellness,
  mobility,
  environment;

  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case HealthCategory.activity:
        return 'Activity';
      case HealthCategory.sleep:
        return 'Sleep';
      case HealthCategory.body:
        return 'Body';
      case HealthCategory.heart:
        return 'Heart';
      case HealthCategory.vitals:
        return 'Vitals';
      case HealthCategory.nutrition:
        return 'Nutrition';
      case HealthCategory.cycle:
        return 'Cycle';
      case HealthCategory.wellness:
        return 'Wellness';
      case HealthCategory.mobility:
        return 'Mobility';
      case HealthCategory.environment:
        return 'Environment';
    }
  }

  /// Deserializes from a raw API string slug.
  ///
  /// Returns `null` for unrecognised slugs so callers can filter them out
  /// rather than silently mapping unknown data to a wrong category.
  static HealthCategory? fromString(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'activity':
        return HealthCategory.activity;
      case 'sleep':
        return HealthCategory.sleep;
      case 'body':
        return HealthCategory.body;
      case 'heart':
        return HealthCategory.heart;
      case 'vitals':
        return HealthCategory.vitals;
      case 'nutrition':
        return HealthCategory.nutrition;
      case 'cycle':
        return HealthCategory.cycle;
      case 'wellness':
        return HealthCategory.wellness;
      case 'mobility':
        return HealthCategory.mobility;
      case 'environment':
        return HealthCategory.environment;
      default:
        debugPrint('[HealthCategory] Unknown category slug: "$raw" — skipping.');
        return null;
    }
  }
}

// ── CategorySummary ───────────────────────────────────────────────────────────

/// Card-level summary for a health category on the dashboard.
class CategorySummary {
  /// Creates a [CategorySummary].
  const CategorySummary({
    required this.category,
    required this.primaryValue,
    this.unit,
    this.deltaPercent,
    this.trend,
    this.lastUpdated,
  });

  /// The health category.
  final HealthCategory category;

  /// Primary metric value string (e.g. "7h 22m", "8,432").
  final String primaryValue;

  /// Unit label (e.g. "steps", "bpm"). Null when unit is embedded in value.
  final String? unit;

  /// Week-over-week delta as a percentage. Null when unavailable.
  final double? deltaPercent;

  /// 7-day trend values, oldest first. Used for sparkline.
  final List<double>? trend;

  /// ISO-8601 timestamp of last data update. Null when not provided.
  final String? lastUpdated;

  /// Deserializes from a JSON map. Returns `null` for unrecognised categories.
  static CategorySummary? fromJson(Map<String, dynamic> json) {
    final category = HealthCategory.fromString(json['category'] as String?);
    if (category == null) return null;
    final rawTrend = json['trend'] as List<dynamic>?;
    return CategorySummary(
      category: category,
      primaryValue: json['primary_value'] as String? ?? '—',
      unit: json['unit'] as String?,
      deltaPercent: (json['delta_percent'] as num?)?.toDouble(),
      trend: rawTrend?.map((e) => (e as num).toDouble()).toList(),
      lastUpdated: json['last_updated'] as String?,
    );
  }
}

// ── DashboardData ─────────────────────────────────────────────────────────────

/// Aggregated payload for the Health Dashboard screen.
class DashboardData {
  /// Creates a [DashboardData].
  const DashboardData({
    required this.categories,
    required this.visibleOrder,
  });

  /// All category summaries (all 10 categories, including hidden ones).
  final List<CategorySummary> categories;

  /// Ordered list of category names representing dashboard layout.
  final List<String> visibleOrder;

  /// Deserializes from a JSON map.
  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final rawCats = json['categories'] as List<dynamic>? ?? [];
    final rawOrder = json['visible_order'] as List<dynamic>? ?? [];
    return DashboardData(
      categories: rawCats
          .map((e) => CategorySummary.fromJson(e as Map<String, dynamic>))
          .whereType<CategorySummary>()
          .toList(),
      visibleOrder: rawOrder.map((e) => e as String).toList(),
    );
  }
}

// ── MetricDataPoint ───────────────────────────────────────────────────────────

/// A single time-series data point for a chart.
class MetricDataPoint {
  /// Creates a [MetricDataPoint].
  const MetricDataPoint({
    required this.timestamp,
    required this.value,
  });

  /// ISO-8601 date or datetime string.
  final String timestamp;

  /// Numeric value for the metric at this point in time.
  final double value;

  /// Deserializes from a JSON map.
  factory MetricDataPoint.fromJson(Map<String, dynamic> json) {
    return MetricDataPoint(
      timestamp: json['timestamp'] as String? ?? json['date'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ── MetricSeries ──────────────────────────────────────────────────────────────

/// A named time series of metric data points.
class MetricSeries {
  /// Creates a [MetricSeries].
  const MetricSeries({
    required this.metricId,
    required this.displayName,
    required this.unit,
    required this.dataPoints,
    this.sourceIntegration,
    this.currentValue,
    this.deltaPercent,
    this.average,
  });

  /// Unique metric identifier (e.g. "steps", "heart_rate_resting").
  final String metricId;

  /// Human-readable metric name.
  final String displayName;

  /// Unit label (e.g. "bpm", "kg", "hours").
  final String unit;

  /// Ordered data points (oldest first).
  final List<MetricDataPoint> dataPoints;

  /// Source integration slug (e.g. "fitbit", "apple_health").
  final String? sourceIntegration;

  /// Latest value string for display.
  final String? currentValue;

  /// Week-over-week delta percentage.
  final double? deltaPercent;

  /// Average over the selected time range.
  final double? average;

  /// Deserializes from a JSON map.
  factory MetricSeries.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['data_points'] as List<dynamic>? ?? [];
    return MetricSeries(
      metricId: json['metric_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Metric',
      unit: json['unit'] as String? ?? '',
      dataPoints: rawPoints
          .map((e) => MetricDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      sourceIntegration: json['source_integration'] as String?,
      currentValue: json['current_value'] as String?,
      deltaPercent: (json['delta_percent'] as num?)?.toDouble(),
      average: (json['average'] as num?)?.toDouble(),
    );
  }
}

// ── CategoryDetailData ────────────────────────────────────────────────────────

/// Full detail data for a single health category.
class CategoryDetailData {
  /// Creates a [CategoryDetailData].
  const CategoryDetailData({
    required this.category,
    required this.metrics,
    required this.timeRange,
  });

  /// The health category.
  final HealthCategory category;

  /// All metrics within this category with their time-series data.
  final List<MetricSeries> metrics;

  /// The selected time range key (e.g. "7D", "30D").
  final String timeRange;

  /// Deserializes from a JSON map.
  factory CategoryDetailData.fromJson(Map<String, dynamic> json) {
    final rawMetrics = json['metrics'] as List<dynamic>? ?? [];
    return CategoryDetailData(
      // Fall back to activity for a category-level unknown — this shouldn't
      // happen in practice since the server validates the slug.
      category: HealthCategory.fromString(json['category'] as String?) ?? HealthCategory.activity,
      metrics: rawMetrics
          .map((e) => MetricSeries.fromJson(e as Map<String, dynamic>))
          .toList(),
      timeRange: json['time_range'] as String? ?? '7D',
    );
  }
}

// ── MetricDetailData ──────────────────────────────────────────────────────────

/// Deep-dive data for a single metric.
class MetricDetailData {
  /// Creates a [MetricDetailData].
  const MetricDetailData({
    required this.series,
    required this.category,
    this.aiInsight,
  });

  /// The metric's time-series data.
  final MetricSeries series;

  /// The parent health category.
  final HealthCategory category;

  /// Optional AI-generated insight for this specific metric.
  final String? aiInsight;

  /// Deserializes from a JSON map.
  factory MetricDetailData.fromJson(Map<String, dynamic> json) {
    return MetricDetailData(
      series: MetricSeries.fromJson(json['series'] as Map<String, dynamic>),
      category: HealthCategory.fromString(json['category'] as String?) ?? HealthCategory.activity,
      aiInsight: json['ai_insight'] as String?,
    );
  }
}

// ── DashboardLayout ───────────────────────────────────────────────────────────

/// Persisted user dashboard layout — card order, visibility, and color overrides.
class DashboardLayout {
  /// Creates a [DashboardLayout].
  const DashboardLayout({
    required this.orderedCategories,
    required this.hiddenCategories,
    this.categoryColorOverrides = const {},
    this.bannerDismissed = false,
    this.tileOrder = const [],
    this.tileVisibility = const {},
    this.tileSizes = const {},
    this.tileColorOverrides = const {},
  });

  /// Category names in display order (all categories, including hidden).
  final List<String> orderedCategories;

  /// Set of category names the user has hidden.
  final Set<String> hiddenCategories;

  /// User-selected color overrides per category name.
  /// Key: category.name (e.g. 'activity'), Value: ARGB int (Color.value).
  final Map<String, int> categoryColorOverrides;

  /// Whether the user has dismissed the [DataMaturityBanner].
  final bool bannerDismissed;

  /// Ordered list of tile IDs (TileId.name strings). Empty = smart ordering.
  final List<String> tileOrder;

  /// Per-tile visibility overrides. Key: TileId.name. Absent = visible.
  final Map<String, bool> tileVisibility;

  /// Per-tile size overrides. Key: TileId.name. Absent = use TileId.defaultSize.
  final Map<String, TileSize> tileSizes;

  /// Per-tile ARGB color overrides (separate from category color overrides).
  /// Key: TileId.name, Value: ARGB int (Color.value).
  final Map<String, int> tileColorOverrides;

  /// Default layout: all 10 categories visible in canonical order.
  static DashboardLayout get defaultLayout => const DashboardLayout(
        orderedCategories: [],
        hiddenCategories: {},
        categoryColorOverrides: {},
      );

  /// Deserializes from the user preferences JSON.
  ///
  /// **Backward migration:** If `tile_order` key is absent this is an old
  /// layout — tileOrder is left as `[]` (smart ordering will apply).
  factory DashboardLayout.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['ordered_categories'] as List<dynamic>? ?? [];
    final rawHidden = json['hidden_categories'] as List<dynamic>? ?? [];
    final rawColors =
        json['category_color_overrides'] as Map<String, dynamic>? ?? {};

    // Tile order — absent key means old format, leave empty.
    final rawTileOrder = json['tile_order'] as List<dynamic>?;
    final tileOrder =
        rawTileOrder != null ? rawTileOrder.map((e) => e as String).toList() : <String>[];

    final rawTileVisibility =
        json['tile_visibility'] as Map<String, dynamic>? ?? {};
    final rawTileSizes = json['tile_sizes'] as Map<String, dynamic>? ?? {};
    final rawTileColorOverrides =
        json['tile_color_overrides'] as Map<String, dynamic>? ?? {};

    return DashboardLayout(
      orderedCategories: rawOrder.map((e) => e as String).toList(),
      hiddenCategories: rawHidden.map((e) => e as String).toSet(),
      categoryColorOverrides:
          rawColors.map((k, v) => MapEntry(k, (v as num).toInt())),
      bannerDismissed: json['banner_dismissed'] as bool? ?? false,
      tileOrder: tileOrder,
      tileVisibility:
          rawTileVisibility.map((k, v) => MapEntry(k, v as bool)),
      tileSizes: rawTileSizes.map(
          (k, v) => MapEntry(k, TileSize.values.byName(v as String))),
      tileColorOverrides: rawTileColorOverrides
          .map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }

  /// Serializes to JSON for the preferences API.
  ///
  /// [tileSizes] values are serialized as string names (e.g. `'tall'`).
  Map<String, dynamic> toJson() => {
        'ordered_categories': orderedCategories,
        'hidden_categories': hiddenCategories.toList(),
        'category_color_overrides': categoryColorOverrides,
        'banner_dismissed': bannerDismissed,
        'tile_order': tileOrder,
        'tile_visibility': tileVisibility,
        'tile_sizes': tileSizes.map((k, v) => MapEntry(k, v.name)),
        'tile_color_overrides': tileColorOverrides,
      };

  /// Returns a copy with the given fields replaced.
  DashboardLayout copyWith({
    List<String>? orderedCategories,
    Set<String>? hiddenCategories,
    Map<String, int>? categoryColorOverrides,
    bool? bannerDismissed,
    List<String>? tileOrder,
    Map<String, bool>? tileVisibility,
    Map<String, TileSize>? tileSizes,
    Map<String, int>? tileColorOverrides,
  }) =>
      DashboardLayout(
        orderedCategories: orderedCategories ?? this.orderedCategories,
        hiddenCategories: hiddenCategories ?? this.hiddenCategories,
        categoryColorOverrides:
            categoryColorOverrides ?? this.categoryColorOverrides,
        bannerDismissed: bannerDismissed ?? this.bannerDismissed,
        tileOrder: tileOrder ?? this.tileOrder,
        tileVisibility: tileVisibility ?? this.tileVisibility,
        tileSizes: tileSizes ?? this.tileSizes,
        tileColorOverrides: tileColorOverrides ?? this.tileColorOverrides,
      );
}
