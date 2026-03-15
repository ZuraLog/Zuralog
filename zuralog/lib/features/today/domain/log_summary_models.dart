/// Zuralog — Today Tab Log Summary Domain Models.
///
/// Data classes powering the Log Ring, Snapshot Cards, and Daily Goals sections.
library;

// ── TodayLogSummary ───────────────────────────────────────────────────────────

/// Aggregated summary of what the user has logged today.
///
/// [loggedTypes] — set of metric type strings logged at least once today
///   (e.g. {'water', 'mood', 'sleep'}).
///
/// [latestValues] — most recent value per type logged today. Keys match
///   [loggedTypes]. Value semantics per type:
///   - 'water'         → cumulative ml today (double)
///   - 'mood'          → latest rating 1.0–10.0 (double)
///   - 'energy'        → latest rating 1.0–10.0 (double)
///   - 'stress'        → latest rating 1.0–10.0 (double)
///   - 'weight'        → latest value in kg (double)
///   - 'steps'         → total steps today (double, treated as int)
///   - 'sleep'         → duration in minutes (double)
///   - 'run'           → distance in km (double)
///   - 'meal'          → cumulative calories today (double, may be 0)
///   - 'supplement'    → count of items taken today (double, treated as int)
///   - 'symptom_severity' → severity string (e.g. 'moderate')
///   - 'run_logged_at' → ISO8601 string of last run log timestamp
class TodayLogSummary {
  const TodayLogSummary({
    required this.loggedTypes,
    required this.latestValues,
  });

  /// Metric type strings logged at least once today.
  final Set<String> loggedTypes;

  /// Most recent value per type (see class doc for semantics).
  final Map<String, dynamic> latestValues;

  /// Empty summary — nothing logged today.
  static const empty = TodayLogSummary(
    loggedTypes: <String>{},
    latestValues: <String, dynamic>{},
  );
}

// ── LogRingState ──────────────────────────────────────────────────────────────

/// State for the Log Ring widget.
class LogRingState {
  const LogRingState({
    required this.loggedCount,
    required this.totalCount,
  });

  /// Number of distinct metric types logged today.
  final int loggedCount;

  /// Total number of active metric types for this user.
  final int totalCount;

  /// Fill fraction 0.0–1.0 for the ring animation.
  double get fraction =>
      totalCount == 0 ? 0.0 : (loggedCount / totalCount).clamp(0.0, 1.0);
}

// ── SnapshotCardData ──────────────────────────────────────────────────────────

/// Data for a single metric snapshot card on the Today screen.
class SnapshotCardData {
  const SnapshotCardData({
    required this.metricType,
    required this.label,
    required this.icon,
    this.value,
    this.unit,
    this.isEmpty = false,
  });

  /// Metric type key (e.g. 'water', 'steps', 'mood').
  final String metricType;

  /// Human-readable label (e.g. 'Water', 'Steps', 'Mood').
  final String label;

  /// Emoji icon to display (e.g. '💧', '👟').
  final String icon;

  /// Today's value as a display string (e.g. '750', '8,200', '7.5').
  /// Null when [isEmpty] is true.
  final String? value;

  /// Unit label (e.g. 'ml', 'steps', '/10'). Null when [isEmpty] is true.
  final String? unit;

  /// True when the user has never logged this metric type.
  final bool isEmpty;
}
