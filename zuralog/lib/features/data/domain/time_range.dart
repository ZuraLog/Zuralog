/// Zuralog — Dashboard time range enum.
///
/// Used by [dashboardTimeRangeProvider] and the global time range selector
/// on the data dashboard grid (spec §3.4).
///
/// Distinct from the widget-local [TimeRange] in
/// `shared/widgets/time_range_selector.dart`, which serves the category /
/// metric detail screens with a different set of options.
library;

// ── TimeRange ─────────────────────────────────────────────────────────────────

/// The five supported time range selections for the data dashboard grid.
enum TimeRange {
  today,
  sevenDays,
  thirtyDays,
  ninetyDays,
  custom;

  /// API string used in query parameters.
  String get apiKey {
    switch (this) {
      case TimeRange.today:
        return 'today';
      case TimeRange.sevenDays:
        return '7D';
      case TimeRange.thirtyDays:
        return '30D';
      case TimeRange.ninetyDays:
        return '90D';
      case TimeRange.custom:
        return 'custom';
    }
  }

  /// Display label for the UI segmented control.
  String get label {
    switch (this) {
      case TimeRange.today:
        return 'Today';
      case TimeRange.sevenDays:
        return '7D';
      case TimeRange.thirtyDays:
        return '30D';
      case TimeRange.ninetyDays:
        return '90D';
      case TimeRange.custom:
        return 'Custom';
    }
  }
}
