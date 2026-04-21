import 'package:flutter/foundation.dart';
import 'package:zuralog/features/data/domain/data_models.dart' show HealthCategory;

/// Metric IDs whose intensity should be inverted (lower value = brighter spoke).
/// Copied verbatim from the previous matrix implementation.
const Set<String> kInvertedMetricIds = <String>{
  'resting_heart_rate',
  'stress',
  'body_fat',
  'body_fat_percent',
  'respiratory_rate',
  'awake_time',
};

/// One spoke in the mandala — one metric in one category.
@immutable
class MandalaSpoke {
  const MandalaSpoke({
    required this.metricId,
    required this.displayName,
    required this.todayValue,
    required this.baseline30d,
    required this.inverted,
  });

  final String metricId;
  final String displayName;

  /// Today's reading. Null = no data today.
  final double? todayValue;

  /// 30-day average. Null = not enough history yet.
  final double? baseline30d;

  /// True for metrics where lower is better (RHR, stress, etc.).
  final bool inverted;

  /// Convenience: `null` baseline means we cannot draw a spoke at all.
  bool get hasBaseline => baseline30d != null && baseline30d! > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MandalaSpoke &&
          other.metricId == metricId &&
          other.todayValue == todayValue &&
          other.baseline30d == baseline30d &&
          other.inverted == inverted;

  @override
  int get hashCode =>
      Object.hash(metricId, todayValue, baseline30d, inverted);
}

/// One wedge — one health category and its spokes.
@immutable
class MandalaWedge {
  const MandalaWedge({required this.category, required this.spokes});
  final HealthCategory category;
  final List<MandalaSpoke> spokes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MandalaWedge &&
          other.category == category &&
          listEquals(other.spokes, spokes);

  @override
  int get hashCode => Object.hash(category, Object.hashAll(spokes));
}

/// The whole mandala — six wedges in clockwise display order.
@immutable
class MandalaData {
  const MandalaData({required this.wedges});
  final List<MandalaWedge> wedges;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MandalaData && listEquals(other.wedges, wedges);

  @override
  int get hashCode => Object.hashAll(wedges);
}

/// Computes the dimensionless spoke-length ratio for one spoke.
///
/// Returns `null` when the math is undefined (no data, no baseline,
/// non-finite values).
///
/// For regular metrics: `ratio = todayValue / baseline`, clamped to [0.5, 1.5].
/// For inverted metrics: `ratio = baseline / todayValue`, same clamp. This
/// flips the encoding so a long spoke ALWAYS means "good day".
///
/// The painter multiplies this ratio by the baseline radius (`R_baseline`)
/// to produce the actual spoke length in pixels.
double? computeSpokeRatio({
  required double? todayValue,
  required double? baseline,
  required bool inverted,
}) {
  if (todayValue == null || baseline == null) return null;
  if (!todayValue.isFinite || !baseline.isFinite) return null;
  if (baseline == 0 || todayValue == 0) return null;

  final raw = inverted ? (baseline / todayValue) : (todayValue / baseline);
  return raw.clamp(0.5, 1.5);
}
