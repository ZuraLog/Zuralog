/// Zuralog — Metric Grid data models.
///
/// [MetricTileData] is the data model for a single user-pinned metric tile
/// in the Today tab's adaptive metric grid.
library;

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
    required this.emoji,
    required this.categoryColor,
    this.value,   // defaults to null
    this.unit,    // defaults to null
  });

  /// The canonical metric type string (e.g. 'water', 'steps', 'sleep').
  final String metricType;

  /// Display label shown below the value (e.g. 'Water', 'Steps').
  final String label;

  /// Emoji representing this metric (e.g. '💧', '👣', '😴').
  final String emoji;

  /// ARGB integer of the category colour (e.g. 0xFF64D2FF for body blue).
  /// Stored as int so this model is pure Dart with no Flutter dependency.
  final int categoryColor;

  /// Today's formatted value string (e.g. '2.1L', '8,432', '7h 40m').
  /// Null when the metric has not been logged or synced today.
  final String? value;

  /// Optional unit string shown alongside the value (e.g. 'kcal', 'bpm').
  /// Null for self-describing values like sleep duration.
  final String? unit;

  /// True when [value] is non-null — tile is fully lit in colour.
  /// False when [value] is null — tile is greyscale.
  bool get isLit => value != null;

  /// Returns a copy of this tile with the given fields replaced.
  ///
  /// To explicitly clear [value] or [unit] back to null, pass
  /// [clearValue] or [clearUnit] as true.
  MetricTileData copyWith({
    String? metricType,
    String? label,
    String? emoji,
    int? categoryColor,
    Object? value = _absent,
    Object? unit = _absent,
  }) {
    return MetricTileData(
      metricType: metricType ?? this.metricType,
      label: label ?? this.label,
      emoji: emoji ?? this.emoji,
      categoryColor: categoryColor ?? this.categoryColor,
      value: value == _absent ? this.value : value as String?,
      unit: unit == _absent ? this.unit : unit as String?,
    );
  }

  static const Object _absent = Object();
}
