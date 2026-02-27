/// Zuralog Dashboard — Graph Type Enum.
///
/// Enumerates every chart visualisation style available in the metric detail
/// screens. Each [HealthMetric] specifies its preferred [GraphType] so that
/// the charting layer can pick the correct renderer without branching logic
/// scattered across the UI.
library;

/// The visual chart style used to render a metric's time-series data.
///
/// Graph type selection is driven by the nature of the underlying data:
/// - Cumulative daily totals → [bar] or [stackedBar].
/// - Continuous sensor readings → [line], [rangeLine], or [dualLine].
/// - Threshold-bounded physiological ranges → [thresholdLine].
/// - Calendar-oriented events → [calendarHeatmap] or [calendarMarker].
/// - Subjective mood/scale entries → [moodTimeline].
/// - Rarely-changing static values → [singleValue].
/// - Compound overlays → [combo].
enum GraphType {
  /// Vertical bars for daily totals (steps, calories, nutrients).
  bar,

  /// Continuous line for time-varying data (weight, heart rate, temperature).
  line,

  /// Line chart with a shaded min/max band (e.g. heart rate range).
  rangeLine,

  /// Two overlaid lines for paired readings (systolic / diastolic BP).
  dualLine,

  /// Stacked vertical bars with coloured segments (sleep stages, intensity).
  stackedBar,

  /// Line chart with a horizontal threshold / normal-range band (SpO2, glucose).
  thresholdLine,

  /// Month-view calendar grid with colour-intensity cells (workouts, mucus).
  calendarHeatmap,

  /// Month-view calendar with dot / icon markers (menstruation, ovulation).
  calendarMarker,

  /// Emoji or numeric scatter for subjective ratings (state of mind).
  moodTimeline,

  /// Single large value display for rarely-changing metrics (height).
  singleValue,

  /// Bar + line overlay for compound data (insulin delivery).
  combo,
}
