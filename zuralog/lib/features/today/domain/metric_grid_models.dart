/// Zuralog — Metric Grid data models.
///
/// [MetricTileData] is the data model for a single user-pinned metric tile
/// in the Today tab's adaptive metric grid.
library;

import 'package:flutter/widgets.dart';

// ── MetricTileData ────────────────────────────────────────────────────────────

/// Data for one pinned metric tile in the Today tab grid.
///
/// [isLit] is derived from [value] — a tile is lit (full colour) when a
/// value has been logged or synced for today, and greyscale when no value
/// exists yet.
class MetricTileData {
  const MetricTileData({
    required this.metricType,
    required this.label,
    required this.icon,
    required this.categoryColor,
    this.value,
    this.unit,
    this.lastValue,
    this.lastLoggedAt,
  });

  /// The canonical metric type string (e.g. 'water', 'steps', 'sleep').
  final String metricType;

  /// Display label shown below the value (e.g. 'Water', 'Steps').
  final String label;

  /// Icon representing this metric.
  final IconData icon;

  /// ARGB integer of the category colour (e.g. 0xFF64D2FF for body blue).
  /// Stored as int so this model is pure Dart with no Flutter dependency.
  final int categoryColor;

  /// Today's formatted value string (e.g. '2.1L', '8,432', '7h 40m').
  /// Null when the metric has not been logged or synced today.
  final String? value;

  /// Optional unit string shown alongside the value (e.g. 'kcal', 'bpm').
  /// Null for self-describing values like sleep duration.
  final String? unit;

  /// The most recent ever-logged formatted value for this metric (across all
  /// time, not just today). Shown on greyscale tiles as a faint hint.
  /// Null when the user has never logged this metric.
  final String? lastValue;

  /// UTC timestamp of [lastValue]'s log entry. Used to derive the relative
  /// "X days ago" label shown beneath the last value on greyscale tiles.
  final DateTime? lastLoggedAt;

  /// True when [value] is non-null — tile is fully lit in colour.
  /// False when [value] is null — tile is greyscale.
  bool get isLit => value != null;

  /// Returns a copy of this tile with the given fields replaced.
  ///
  /// To explicitly clear nullable fields back to null, pass them as null
  /// explicitly — omitting a parameter preserves the existing value.
  MetricTileData copyWith({
    String? metricType,
    String? label,
    IconData? icon,
    int? categoryColor,
    Object? value = _absent,
    Object? unit = _absent,
    Object? lastValue = _absent,
    Object? lastLoggedAt = _absent,
  }) {
    return MetricTileData(
      metricType: metricType ?? this.metricType,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      categoryColor: categoryColor ?? this.categoryColor,
      value: value == _absent ? this.value : value as String?,
      unit: unit == _absent ? this.unit : unit as String?,
      lastValue: lastValue == _absent ? this.lastValue : lastValue as String?,
      lastLoggedAt: lastLoggedAt == _absent
          ? this.lastLoggedAt
          : lastLoggedAt as DateTime?,
    );
  }

  static const Object _absent = Object();
}
