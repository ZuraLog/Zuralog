/// Zuralog — Data Tab Tile Models.
///
/// Domain models for the tile-based data dashboard.
///
/// Model overview:
/// - [TileId]                 — enum of 31 supported metric tiles
/// - [TileDataState]          — enum of 5 tile data states
/// - [TileVisualizationData]  — sealed class hierarchy for tile visualizations
/// - [TileData]               — full tile data including state and visualization
/// - [TileConfig]             — extension on TileId for display/layout metadata
library;

import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

// ── TileId ────────────────────────────────────────────────────────────────────

/// The 31 supported metric tile identifiers.
enum TileId {
  steps,
  activeCalories,
  workouts,
  sleepDuration,
  sleepStages,
  restingHeartRate,
  hrv,
  vo2Max,
  weight,
  bodyFat,
  bloodPressure,
  spo2,
  calories,
  water,
  mood,
  energy,
  stress,
  cycle,
  environment,
  mobility,
  // ── New tiles (Phase 8 expansion) ─────────────────────────────────────────
  distance,
  floorsClimbed,
  exerciseMinutes,
  walkingSpeed,
  runningPace,
  respiratoryRate,
  bodyTemperature,
  wristTemperature,
  macros,
  bloodGlucose,
  mindfulMinutes;

  /// Deserializes from a raw string slug.
  ///
  /// Returns `null` for unknown, null, or empty values.
  static TileId? fromString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return TileId.values.byName(raw);
    } catch (_) {
      return null;
    }
  }
}

// ── TileDataState ─────────────────────────────────────────────────────────────

/// The 5 possible states for a tile's data.
enum TileDataState {
  /// Data is loaded and ready to display.
  loaded,

  /// Data is being synced from the source.
  syncing,

  /// No data source is connected for this metric.
  noSource,

  /// No data is available for the selected time range.
  noDataForRange,

  /// The tile is hidden by the user.
  hidden,
}

// ── TileVisualizationData ─────────────────────────────────────────────────────

/// Sealed base class for all tile visualization data.
///
/// Each subtype carries exactly the data needed for one visualization variant.
/// Callers should use pattern matching (switch/when) to handle all subtypes.
sealed class TileVisualizationData {
  const TileVisualizationData();
}

/// Bar chart with daily values and optional average/delta.
final class BarChartData extends TileVisualizationData {
  BarChartData({
    required this.dailyValues,
    required this.dayLabels,
    this.average,
    this.delta,
  });

  final List<double> dailyValues;
  final List<String> dayLabels;
  final double? average;
  final double? delta;
}

/// Ring/donut chart with a current value and max.
final class RingData extends TileVisualizationData {
  const RingData({
    required this.value,
    required this.max,
    this.goalLabel,
  });

  final double value;
  final double max;
  final String? goalLabel;
}

/// Line chart with optional range bands and delta.
final class LineChartData extends TileVisualizationData {
  const LineChartData({
    required this.values,
    this.rangeLow,
    this.rangeHigh,
    this.delta,
  });

  final List<double> values;
  final double? rangeLow;
  final double? rangeHigh;
  final double? delta;
}

/// Stacked bar representing segments (e.g. sleep stages).
final class StackedBarData extends TileVisualizationData {
  const StackedBarData({required this.segments});

  final List<({String label, double hours})> segments;
}

/// Area chart with optional target line and delta.
final class AreaChartData extends TileVisualizationData {
  const AreaChartData({
    required this.values,
    this.targetValue,
    this.delta,
  });

  final List<double> values;
  final double? targetValue;
  final double? delta;
}

/// Gauge with a normalized percentage (0.0–1.0) and optional label.
final class GaugeData extends TileVisualizationData {
  const GaugeData({required this.percent, this.label})
      : assert(percent >= 0.0 && percent <= 1.0,
            'GaugeData.percent must be in [0.0, 1.0], got $percent');

  /// Normalized value between 0.0 and 1.0.
  final double percent;
  final String? label;
}

/// Single primary value with optional secondary label and status color.
final class ValueData extends TileVisualizationData {
  const ValueData({
    required this.primaryValue,
    this.secondaryLabel,
    this.statusColor,
  });

  final String primaryValue;
  final String? secondaryLabel;

  /// ARGB color int, or null to use the default theme color.
  final int? statusColor;
}

/// Two values side-by-side (e.g. systolic/diastolic blood pressure).
final class DualValueData extends TileVisualizationData {
  const DualValueData({
    required this.topValue,
    required this.bottomValue,
    required this.topLabel,
    required this.bottomLabel,
  });

  final String topValue;
  final String bottomValue;
  final String topLabel;
  final String bottomLabel;
}

/// Macro nutrition bars with calorie total and per-macro progress.
final class MacroBarsData extends TileVisualizationData {
  const MacroBarsData({
    required this.totalCalories,
    required this.macros,
  });

  final String totalCalories;
  final List<({String label, double current, double goal})> macros;
}

/// Fill gauge showing current vs goal (e.g. water intake).
final class FillGaugeData extends TileVisualizationData {
  const FillGaugeData({
    required this.current,
    required this.goal,
    this.unit,
  });

  final double current;
  final double goal;
  final String? unit;
}

/// Row of dots representing a 7-day pattern (e.g. mood/energy/stress).
///
/// Not const because [List] is not a compile-time constant.
final class DotsData extends TileVisualizationData {
  DotsData({
    required this.values,
    this.todayLabel,
  });

  final List<double> values;
  final String? todayLabel;
}

/// Count badge showing total workouts with last workout metadata.
final class CountBadgeData extends TileVisualizationData {
  const CountBadgeData({
    required this.count,
    this.lastWorkoutType,
    this.lastWorkoutDuration,
  });

  final int count;
  final String? lastWorkoutType;
  final String? lastWorkoutDuration;
}

/// Cycle calendar with phase label and dot states.
final class CalendarDotsData extends TileVisualizationData {
  const CalendarDotsData({
    required this.cycleDay,
    required this.phaseLabel,
    required this.dotStates,
  });

  final int cycleDay;
  final String phaseLabel;
  final List<bool> dotStates;
}

/// Air quality and UV index for the environment tile.
final class EnvironmentData extends TileVisualizationData {
  const EnvironmentData({
    required this.aqiValue,
    required this.aqiLabel,
    required this.uvIndex,
    required this.uvLabel,
  });

  final int aqiValue;
  final String aqiLabel;
  final int uvIndex;
  final String uvLabel;
}

// ── TileData ──────────────────────────────────────────────────────────────────

/// Full tile data: identity, state, last-updated timestamp, visualization,
/// and optional pre-computed stats for footer/expanded-view display.
class TileData {
  const TileData({
    required this.tileId,
    required this.dataState,
    this.lastUpdated,
    this.primaryValue,
    this.unit,
    this.visualization,
    this.vizConfig,
    this.avgLabel,
    this.deltaLabel,
    this.avgValue,
    this.bestValue,
    this.worstValue,
    this.changeValue,
  });

  final TileId tileId;
  final TileDataState dataState;

  /// ISO-8601 timestamp of last successful data sync. Null if never synced.
  final String? lastUpdated;

  /// Primary display value string (e.g. "8,432", "7h 22m"). Null when not loaded.
  final String? primaryValue;

  /// Unit label (e.g. "steps", "bpm"). Null when not applicable or embedded in value.
  final String? unit;

  /// Visualization payload (legacy) — null unless [dataState] == [TileDataState.loaded].
  final TileVisualizationData? visualization;

  /// New typed visualization config — null unless [dataState] == [TileDataState.loaded].
  final TileVisualizationConfig? vizConfig;

  // ── Stats footer (MetricTile, tall/wide only) ──────────────────────────────

  /// Formatted average label (e.g. "Avg 8.2k"). Null if no trend data.
  final String? avgLabel;

  /// Formatted delta label (e.g. "↑ 12%"). Null if no delta available.
  final String? deltaLabel;

  // ── Stats row (TileExpandedView) ───────────────────────────────────────────

  /// Formatted average value string. Null if no trend data.
  final String? avgValue;

  /// Formatted best (max) value string. Null if no trend data.
  final String? bestValue;

  /// Formatted worst (min) value string. Null if no trend data.
  final String? worstValue;

  /// Formatted change value string (e.g. "+12%"). Null if no delta.
  final String? changeValue;
}

// ── TileConfig ────────────────────────────────────────────────────────────────

/// Display and layout metadata for each [TileId].
extension TileConfig on TileId {
  /// Human-readable display name for the tile.
  String get displayName {
    switch (this) {
      case TileId.steps:
        return 'Steps';
      case TileId.activeCalories:
        return 'Active Calories';
      case TileId.workouts:
        return 'Workouts';
      case TileId.sleepDuration:
        return 'Sleep Duration';
      case TileId.sleepStages:
        return 'Sleep Stages';
      case TileId.restingHeartRate:
        return 'Resting Heart Rate';
      case TileId.hrv:
        return 'HRV';
      case TileId.vo2Max:
        return 'VO₂ Max';
      case TileId.weight:
        return 'Weight';
      case TileId.bodyFat:
        return 'Body Fat';
      case TileId.bloodPressure:
        return 'Blood Pressure';
      case TileId.spo2:
        return 'SpO2';
      case TileId.calories:
        return 'Calories';
      case TileId.water:
        return 'Water';
      case TileId.mood:
        return 'Mood';
      case TileId.energy:
        return 'Energy';
      case TileId.stress:
        return 'Stress';
      case TileId.cycle:
        return 'Cycle';
      case TileId.environment:
        return 'Environment';
      case TileId.mobility:
        return 'Mobility';
      case TileId.distance:         return 'Distance';
      case TileId.floorsClimbed:    return 'Floors Climbed';
      case TileId.exerciseMinutes:  return 'Exercise Minutes';
      case TileId.walkingSpeed:     return 'Walking Speed';
      case TileId.runningPace:      return 'Running Pace';
      case TileId.respiratoryRate:  return 'Respiratory Rate';
      case TileId.bodyTemperature:  return 'Body Temperature';
      case TileId.wristTemperature: return 'Wrist Temperature';
      case TileId.macros:           return 'Macros';
      case TileId.bloodGlucose:     return 'Blood Glucose';
      case TileId.mindfulMinutes:   return 'Mindful Minutes';
    }
  }

  /// The [HealthCategory] this tile belongs to.
  HealthCategory get category {
    switch (this) {
      case TileId.steps:
      case TileId.activeCalories:
      case TileId.workouts:
        return HealthCategory.activity;
      case TileId.sleepDuration:
      case TileId.sleepStages:
        return HealthCategory.sleep;
      case TileId.restingHeartRate:
      case TileId.hrv:
      case TileId.vo2Max:
        return HealthCategory.heart;
      case TileId.weight:
      case TileId.bodyFat:
        return HealthCategory.body;
      case TileId.bloodPressure:
      case TileId.spo2:
        return HealthCategory.vitals;
      case TileId.calories:
      case TileId.water:
        return HealthCategory.nutrition;
      case TileId.mood:
      case TileId.energy:
      case TileId.stress:
        return HealthCategory.wellness;
      case TileId.cycle:
        return HealthCategory.cycle;
      case TileId.environment:
        return HealthCategory.environment;
      case TileId.mobility:
        return HealthCategory.mobility;
      case TileId.distance:
      case TileId.floorsClimbed:
      case TileId.exerciseMinutes:
      case TileId.walkingSpeed:
      case TileId.runningPace:
        return HealthCategory.activity;
      case TileId.respiratoryRate:
        return HealthCategory.heart;
      case TileId.bodyTemperature:
      case TileId.wristTemperature:
        return HealthCategory.body;
      case TileId.macros:
        return HealthCategory.nutrition;
      case TileId.bloodGlucose:
        return HealthCategory.vitals;
      case TileId.mindfulMinutes:
        return HealthCategory.wellness;
    }
  }

  /// Default [TileSize] for this tile.
  ///
  /// - [TileId.steps] → [TileSize.tall]
  /// - [TileId.sleepStages] → [TileSize.wide]
  /// - [TileId.weight] → [TileSize.wide]
  /// - All others → [TileSize.square]
  TileSize get defaultSize {
    switch (this) {
      case TileId.steps:
        return TileSize.tall;
      case TileId.sleepStages:
        return TileSize.wide;
      case TileId.weight:
        return TileSize.wide;
      case TileId.cycle:
        return TileSize.wide;
      // All 11 new IDs default to square (handled by default:)
      default:
        return TileSize.square;
    }
  }

  /// Allowed sizes for this tile (per spec §5.4).
  List<TileSize> get allowedSizes {
    switch (this) {
      case TileId.steps:
        return const [TileSize.square, TileSize.tall];
      case TileId.sleepStages:
        return const [TileSize.wide, TileSize.tall];
      case TileId.restingHeartRate:
      case TileId.hrv:
        return const [TileSize.square, TileSize.wide];
      case TileId.weight:
        return const [TileSize.wide, TileSize.tall];
      case TileId.calories:
        return const [TileSize.square, TileSize.tall];
      case TileId.mood:
      case TileId.energy:
      case TileId.stress:
        return const [TileSize.square, TileSize.wide];
      case TileId.cycle:
        return const [TileSize.wide, TileSize.tall];
      case TileId.wristTemperature:
        return const [TileSize.square];
      case TileId.walkingSpeed:
      case TileId.runningPace:
      case TileId.bodyTemperature:
      case TileId.respiratoryRate:
        return const [TileSize.square, TileSize.wide];
      case TileId.distance:
      case TileId.floorsClimbed:
      case TileId.exerciseMinutes:
      case TileId.macros:
      case TileId.bloodGlucose:
      case TileId.mindfulMinutes:
        return const [TileSize.square, TileSize.tall];
      default:
        return const [TileSize.square];
    }
  }

  /// Emoji icon representing this metric tile.
  String get icon {
    return switch (this) {
      TileId.steps            => '👟',
      TileId.activeCalories   => '🔥',
      TileId.workouts         => '💪',
      TileId.sleepDuration    => '🌙',
      TileId.sleepStages      => '😴',
      TileId.restingHeartRate => '❤️',
      TileId.hrv              => '💓',
      TileId.vo2Max           => '🫁',
      TileId.weight           => '⚖️',
      TileId.bodyFat          => '📉',
      TileId.bloodPressure    => '🩺',
      TileId.spo2             => '🫧',
      TileId.calories         => '🥗',
      TileId.water            => '💧',
      TileId.mood             => '😊',
      TileId.energy           => '⚡',
      TileId.stress           => '🧠',
      TileId.cycle            => '🌸',
      TileId.environment      => '🌿',
      TileId.mobility         => '🦵',
      TileId.distance         => '📍',
      TileId.floorsClimbed    => '🏢',
      TileId.exerciseMinutes  => '⏱️',
      TileId.walkingSpeed     => '🚶',
      TileId.runningPace      => '🏃',
      TileId.respiratoryRate  => '🫀',
      TileId.bodyTemperature  => '🌡️',
      TileId.wristTemperature => '⌚',
      TileId.macros           => '🥦',
      TileId.bloodGlucose     => '🩸',
      TileId.mindfulMinutes   => '🧘',
    };
  }

  /// Returns the next [TileSize] in [allowedSizes], cycling back to the first.
  TileSize nextSize(TileSize current) {
    final sizes = allowedSizes;
    final idx = sizes.indexOf(current);
    if (idx == -1) return sizes.first;
    return sizes[(idx + 1) % sizes.length];
  }
}
