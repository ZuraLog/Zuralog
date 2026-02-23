/// Zuralog Edge Agent — Dashboard Insight Domain Model.
///
/// Represents the AI-generated insight returned by the Cloud Brain
/// endpoint `/analytics/dashboard-insight`. Contains a natural-language
/// summary plus optional structured goal and trend metadata.
library;

/// Domain model for the AI-generated dashboard insight.
///
/// The [insight] field is the primary text displayed to the user.
/// [goals] and [trends] carry supplementary structured data that the
/// dashboard can use for badges, progress bars, or trend indicators.
class DashboardInsight {
  /// Creates a [DashboardInsight].
  ///
  /// [insight] is required; [goals] defaults to an empty list and
  /// [trends] defaults to an empty map when not provided.
  const DashboardInsight({
    required this.insight,
    this.goals = const [],
    this.trends = const {},
  });

  /// Deserializes a [DashboardInsight] from a JSON map.
  ///
  /// [json] must contain an `insight` key of type [String].
  /// `goals` (a JSON array of objects) and `trends` (a JSON object)
  /// are optional and default to empty collections when absent.
  ///
  /// Throws a [TypeError] if `insight` is missing or not a [String].
  factory DashboardInsight.fromJson(Map<String, dynamic> json) {
    return DashboardInsight(
      insight: json['insight'] as String,
      goals: (json['goals'] as List<dynamic>?)
              ?.map((g) => g as Map<String, dynamic>)
              .toList() ??
          [],
      trends: (json['trends'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Natural-language AI-generated insight text for display on the dashboard.
  final String insight;

  /// Structured goal metadata (e.g. progress towards daily targets).
  ///
  /// Each element is an untyped map — the exact schema depends on the
  /// Cloud Brain response version. An empty list when no goals are returned.
  final List<Map<String, dynamic>> goals;

  /// Structured trend metadata (e.g. `{"steps": "up", "sleep": "stable"}`).
  ///
  /// An empty map when no trends are returned.
  final Map<String, dynamic> trends;
}
