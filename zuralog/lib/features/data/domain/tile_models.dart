/// Zuralog — Data Tab Tile Models.
///
/// Domain models for the tile-based data dashboard.
///
/// Model overview:
/// - [TileId]                 — enum of 31 supported metric tiles
/// - [TileDataState]          — enum of 5 tile data states
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

  /// Resolves a snake_case metric slug or camelCase enum name to a [TileId].
  ///
  /// Tries camelCase enum name first (via [fromString]), then matches against
  /// each value's [metricSlug]. Returns `null` for unrecognised slugs.
  static TileId? fromSlug(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final direct = fromString(raw);
    if (direct != null) return direct;
    for (final id in TileId.values) {
      if (id.metricSlug == raw) return id;
    }
    return null;
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

  /// Typed visualization config — null unless [dataState] == [TileDataState.loaded].
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
  /// Snake_case metric slug for API calls.
  ///
  /// Converts the camelCase Dart enum name to snake_case so it matches the
  /// API / mock repository key format.
  ///
  /// Examples: `sleepDuration` → `sleep_duration`, `vo2Max` → `vo2_max`,
  /// `spo2` → `spo2`, `hrv` → `hrv`.
  String get metricSlug => name.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (m) => '_${m.group(0)!.toLowerCase()}',
      );

  /// The metric_id used for Cloud Brain API lookups.
  ///
  /// For most tiles this is identical to [metricSlug]. The two overrides
  /// below exist because the backend stores data under a different name than
  /// the Dart enum implies:
  /// - [TileId.workouts]  → workouts arrive as `exercise_minutes` events
  /// - [TileId.mobility]  → closest single metric is `floors_climbed`
  /// Blood pressure is a special case handled in the provider (two metrics → one tile).
  String get backendMetricId => switch (this) {
    TileId.workouts => 'exercise_minutes',
    // NOTE: TileId.floorsClimbed also resolves to 'floors_climbed' via metricSlug.
    // If both tiles are visible simultaneously they will share the same series data.
    TileId.mobility => 'floors_climbed',
    _ => metricSlug,
  };

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

  /// Allowed sizes for this tile — all tiles support all three sizes.
  List<TileSize> get allowedSizes =>
      const [TileSize.square, TileSize.wide, TileSize.tall];

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
