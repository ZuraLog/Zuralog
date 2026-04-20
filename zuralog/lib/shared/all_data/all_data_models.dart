library;

import 'package:flutter/material.dart';

enum AllDataChartType { bar, line }

/// One day of data for the All-Data screen. Values are keyed by metric id
/// (e.g. 'duration', 'calories'). A null value means no data for that metric
/// on that day.
class AllDataDay {
  const AllDataDay({
    required this.date,
    required this.isToday,
    required this.values,
  });

  /// ISO-8601 date string, e.g. '2026-04-20'.
  final String date;
  final bool isToday;
  final Map<String, double?> values;
}

/// Describes a single metric tab on the All-Data screen.
class AllDataMetricTab {
  const AllDataMetricTab({
    required this.id,
    required this.label,
    required this.chartType,
    required this.unit,
    required this.valueExtractor,
    this.emptyStateSource,
  });

  final String id;
  final String label;
  final AllDataChartType chartType;

  /// Unit suffix displayed on chart axes (e.g. 'h', 'kcal', 'bpm', '%').
  final String unit;

  /// Pulls this tab's value from a day row.
  final double? Function(AllDataDay day) valueExtractor;

  /// Human-readable data source prompt shown when the user has no data for
  /// this metric (e.g. 'Connect a wearable'). Null means generic empty state.
  final String? emptyStateSource;
}

/// All configuration that varies per section. Passed into [AllDataScreen] by
/// each section-specific entry point (e.g. [SleepAllDataScreen]).
///
/// Not `const` — [fetchData] is a closure and prevents const construction.
class AllDataSectionConfig {
  AllDataSectionConfig({
    required this.sectionTitle,
    required this.categoryColor,
    required this.tabs,
    required this.fetchData,
  });

  final String sectionTitle;
  final Color categoryColor;
  final List<AllDataMetricTab> tabs;

  /// Fetches per-day rows for the given range string ('7d', '30d', '3m',
  /// '6m', '1y'). Called by [AllDataScreen] whenever the range changes.
  final Future<List<AllDataDay>> Function(String range) fetchData;
}
