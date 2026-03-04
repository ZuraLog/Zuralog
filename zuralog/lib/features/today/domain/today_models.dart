/// Zuralog — Today Tab Domain Models.
///
/// Strongly-typed data transfer objects (DTOs) for all Today-tab API
/// responses. All models are immutable and serialize from JSON.
///
/// Model overview:
/// - [HealthScoreData]   — composite health score + 7-day trend
/// - [InsightCard]       — summary card shown in the Today feed
/// - [InsightDetail]     — full detail view with charts + AI reasoning
/// - [InsightDataPoint]  — single chart data point inside [InsightDetail]
/// - [InsightSource]     — integration that contributed to an insight
/// - [QuickAction]       — contextual action tile
/// - [StreakData]        — current streak count + freeze status
/// - [TodayFeedData]     — aggregated feed payload (insights + actions + streak)
/// - [NotificationItem]  — single notification row
/// - [NotificationPage]  — paginated notification history
library;

// ── HealthScoreData ───────────────────────────────────────────────────────────

/// Composite health score returned by `GET /api/v1/health-score`.
class HealthScoreData {
  /// Creates a [HealthScoreData].
  const HealthScoreData({
    required this.score,
    required this.trend,
    this.commentary,
  });

  /// Current health score (0–100).
  final int score;

  /// 7-day trend values, oldest first (used for sparkline).
  final List<double> trend;

  /// Optional AI-generated commentary string.
  final String? commentary;

  /// Deserializes from a JSON map.
  factory HealthScoreData.fromJson(Map<String, dynamic> json) {
    final rawTrend = json['trend'] as List<dynamic>? ?? [];
    return HealthScoreData(
      score: (json['score'] as num).toInt(),
      trend: rawTrend.map((e) => (e as num).toDouble()).toList(),
      commentary: json['commentary'] as String?,
    );
  }
}

// ── InsightType ───────────────────────────────────────────────────────────────

/// Categorises the nature of an AI insight.
enum InsightType {
  anomaly,
  correlation,
  trend,
  recommendation,
  achievement,
  unknown,
}

/// Maps a raw string from the API to [InsightType].
InsightType _insightTypeFromString(String? raw) {
  switch (raw) {
    case 'anomaly':
      return InsightType.anomaly;
    case 'correlation':
      return InsightType.correlation;
    case 'trend':
      return InsightType.trend;
    case 'recommendation':
      return InsightType.recommendation;
    case 'achievement':
      return InsightType.achievement;
    default:
      return InsightType.unknown;
  }
}

// ── InsightCard ───────────────────────────────────────────────────────────────

/// Summary card displayed in the Today feed.
///
/// Tapping a card navigates to [InsightDetailScreen] via [id].
class InsightCard {
  /// Creates an [InsightCard].
  const InsightCard({
    required this.id,
    required this.title,
    required this.summary,
    required this.type,
    required this.category,
    required this.isRead,
    this.priorityScore,
    this.createdAt,
  });

  /// Unique insight identifier.
  final String id;

  /// Short headline for the card.
  final String title;

  /// 1–2 sentence summary shown on the card.
  final String summary;

  /// Insight classification.
  final InsightType type;

  /// Health category (e.g. `sleep`, `activity`, `heart`).
  final String category;

  /// Whether the user has already read this insight.
  final bool isRead;

  /// Optional relevance score (0–1) used for feed ordering.
  final double? priorityScore;

  /// When the insight was generated.
  final DateTime? createdAt;

  /// Deserializes from a JSON map.
  factory InsightCard.fromJson(Map<String, dynamic> json) {
    return InsightCard(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      type: _insightTypeFromString(json['type'] as String?),
      category: json['category'] as String? ?? 'general',
      isRead: json['is_read'] as bool? ?? false,
      priorityScore: (json['priority_score'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

// ── InsightDataPoint ──────────────────────────────────────────────────────────

/// A single data point for charts inside [InsightDetail].
class InsightDataPoint {
  /// Creates an [InsightDataPoint].
  const InsightDataPoint({required this.label, required this.value});

  /// X-axis label (e.g. date string or time-of-day).
  final String label;

  /// Y-axis numeric value.
  final double value;

  /// Deserializes from a JSON map.
  factory InsightDataPoint.fromJson(Map<String, dynamic> json) {
    return InsightDataPoint(
      label: json['label'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }
}

// ── InsightSource ─────────────────────────────────────────────────────────────

/// An integration that contributed data to an insight.
class InsightSource {
  /// Creates an [InsightSource].
  const InsightSource({required this.name, required this.iconName});

  /// Human-readable integration name (e.g. "Apple Health", "Strava").
  final String name;

  /// Icon identifier used for display (e.g. "apple_health", "strava").
  final String iconName;

  /// Deserializes from a JSON map.
  factory InsightSource.fromJson(Map<String, dynamic> json) {
    return InsightSource(
      name: json['name'] as String,
      iconName: json['icon_name'] as String? ?? 'default',
    );
  }
}

// ── InsightDetail ─────────────────────────────────────────────────────────────

/// Full insight detail returned by `GET /api/v1/insights/:id`.
class InsightDetail {
  /// Creates an [InsightDetail].
  const InsightDetail({
    required this.id,
    required this.title,
    required this.summary,
    required this.reasoning,
    required this.type,
    required this.category,
    required this.dataPoints,
    required this.sources,
    this.chartTitle,
    this.chartUnit,
    this.createdAt,
  });

  /// Unique identifier.
  final String id;

  /// Headline.
  final String title;

  /// 1–2 sentence summary.
  final String summary;

  /// Extended AI reasoning / explanation text.
  final String reasoning;

  /// Classification.
  final InsightType type;

  /// Health category.
  final String category;

  /// Chart data points (may be empty for text-only insights).
  final List<InsightDataPoint> dataPoints;

  /// Integrations that contributed to this insight.
  final List<InsightSource> sources;

  /// Optional chart title (e.g. "7-day sleep duration").
  final String? chartTitle;

  /// Optional y-axis unit label (e.g. "hrs", "bpm").
  final String? chartUnit;

  /// When the insight was generated.
  final DateTime? createdAt;

  /// Deserializes from a JSON map.
  factory InsightDetail.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['data_points'] as List<dynamic>? ?? [];
    final rawSources = json['sources'] as List<dynamic>? ?? [];
    return InsightDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      reasoning: json['reasoning'] as String? ?? '',
      type: _insightTypeFromString(json['type'] as String?),
      category: json['category'] as String? ?? 'general',
      dataPoints: rawPoints
          .map((e) => InsightDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      sources: rawSources
          .map((e) => InsightSource.fromJson(e as Map<String, dynamic>))
          .toList(),
      chartTitle: json['chart_title'] as String?,
      chartUnit: json['chart_unit'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

// ── QuickAction ───────────────────────────────────────────────────────────────

/// A contextual action card shown in the Today feed.
class QuickAction {
  /// Creates a [QuickAction].
  const QuickAction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.actionType,
    this.route,
  });

  /// Unique identifier.
  final String id;

  /// Short action label.
  final String title;

  /// Supporting text describing the action.
  final String subtitle;

  /// Machine-readable action type (e.g. `log_workout`, `open_coach`).
  final String actionType;

  /// Optional deep-link route to navigate to.
  final String? route;

  /// Deserializes from a JSON map.
  factory QuickAction.fromJson(Map<String, dynamic> json) {
    return QuickAction(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      actionType: json['action_type'] as String? ?? 'generic',
      route: json['route'] as String?,
    );
  }
}

// ── StreakData ────────────────────────────────────────────────────────────────

/// Current streak data returned by `GET /api/v1/streaks`.
class StreakData {
  /// Creates a [StreakData].
  const StreakData({
    required this.currentStreak,
    required this.isFrozen,
    this.longestStreak,
  });

  /// Current consecutive-days streak.
  final int currentStreak;

  /// Whether a streak freeze is currently active.
  final bool isFrozen;

  /// All-time longest streak.
  final int? longestStreak;

  /// Deserializes from a JSON map.
  factory StreakData.fromJson(Map<String, dynamic> json) {
    return StreakData(
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      isFrozen: json['is_frozen'] as bool? ?? false,
      longestStreak: (json['longest_streak'] as num?)?.toInt(),
    );
  }
}

// ── TodayFeedData ─────────────────────────────────────────────────────────────

/// Aggregated Today feed payload (returned by [TodayRepository.getTodayFeed]).
class TodayFeedData {
  /// Creates a [TodayFeedData].
  const TodayFeedData({
    required this.insights,
    required this.quickActions,
    required this.streak,
  });

  /// AI insight cards, ordered by priority.
  final List<InsightCard> insights;

  /// Contextual quick action tiles.
  final List<QuickAction> quickActions;

  /// Current streak — may be null if the request failed.
  final StreakData? streak;
}

// ── NotificationItem ──────────────────────────────────────────────────────────

/// A single notification history entry.
class NotificationItem {
  /// Creates a [NotificationItem].
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    this.deepLinkRoute,
    this.deepLinkId,
    this.receivedAt,
  });

  /// Unique identifier.
  final String id;

  /// Notification headline.
  final String title;

  /// Notification body text.
  final String body;

  /// Whether the user has read this notification.
  final bool isRead;

  /// Optional named route for deep-linking.
  final String? deepLinkRoute;

  /// Optional entity ID for the deep-link (e.g. insight ID).
  final String? deepLinkId;

  /// When the notification was received.
  final DateTime? receivedAt;

  /// Deserializes from a JSON map.
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      isRead: json['read'] as bool? ?? false,
      deepLinkRoute: json['deep_link_route'] as String?,
      deepLinkId: json['deep_link_id'] as String?,
      receivedAt: json['received_at'] != null
          ? DateTime.tryParse(json['received_at'] as String)
          : null,
    );
  }
}

// ── NotificationPage ──────────────────────────────────────────────────────────

/// Paginated notification history response.
class NotificationPage {
  /// Creates a [NotificationPage].
  const NotificationPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.hasMore,
  });

  /// Notifications on this page.
  final List<NotificationItem> items;

  /// Total notification count across all pages.
  final int totalCount;

  /// Current page index (1-indexed).
  final int page;

  /// Whether more pages are available.
  final bool hasMore;

  /// Deserializes from a JSON map.
  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return NotificationPage(
      items: rawItems
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}
