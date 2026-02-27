/// Zuralog Dashboard — Metric Data Point Model.
///
/// Represents a single timestamped measurement in a health metric's time
/// series. Supports simple scalar readings as well as range data (min/max)
/// and multi-component breakdowns (e.g. sleep stages, blood pressure).
library;

/// A single timestamped measurement within a health metric's time series.
///
/// The [value] field always holds the primary reading. For metrics that
/// report a range (e.g. heart-rate min/max over an hour), [min] and [max]
/// carry the extremes. For multi-component data (e.g. sleep stages where
/// each stage has its own duration), [components] maps component names to
/// their numeric values.
///
/// Examples:
/// - Steps: `MetricDataPoint(timestamp: ..., value: 8432)`
/// - Heart rate range: `MetricDataPoint(timestamp: ..., value: 72, min: 58, max: 142)`
/// - Sleep stages: `MetricDataPoint(timestamp: ..., value: 7.5, components: {'deep': 1.2, 'rem': 1.8, 'light': 3.5, 'awake': 1.0})`
class MetricDataPoint {
  /// Creates a [MetricDataPoint].
  ///
  /// [timestamp] is the moment the reading was taken or the period it
  /// represents.
  ///
  /// [value] is the primary scalar value.
  ///
  /// [min] and [max] are optional range bounds, used when the metric
  /// aggregates over a period (e.g. hourly heart-rate min/max).
  ///
  /// [components] is an optional breakdown map for multi-part data such as
  /// sleep stages or blood-pressure systolic/diastolic.
  const MetricDataPoint({
    required this.timestamp,
    required this.value,
    this.min,
    this.max,
    this.components,
  });

  /// The instant or period start this data point represents.
  final DateTime timestamp;

  /// The primary scalar reading (e.g. step count, weight in kg, bpm).
  final double value;

  /// Optional lower bound of a range reading (e.g. minimum heart rate).
  final double? min;

  /// Optional upper bound of a range reading (e.g. maximum heart rate).
  final double? max;

  /// Optional named sub-values for multi-component metrics.
  ///
  /// Keys are component identifiers (e.g. `'deep'`, `'rem'`, `'systolic'`).
  /// Values are the numeric measurement for each component.
  final Map<String, double>? components;

  @override
  String toString() =>
      'MetricDataPoint(timestamp: $timestamp, value: $value'
      '${min != null ? ', min: $min' : ''}'
      '${max != null ? ', max: $max' : ''}'
      '${components != null ? ', components: $components' : ''}'
      ')';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetricDataPoint &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          value == other.value &&
          min == other.min &&
          max == other.max;

  @override
  int get hashCode => Object.hash(timestamp, value, min, max);
}
