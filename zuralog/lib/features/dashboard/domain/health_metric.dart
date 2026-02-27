/// Zuralog Dashboard — Health Metric Definition Model.
///
/// Describes a single trackable health metric — its identity, display
/// metadata, measurement unit, platform identifiers, and preferred chart
/// type. Instances are created once in [HealthMetricRegistry] and shared
/// across the entire app.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/features/dashboard/domain/graph_type.dart';
import 'package:zuralog/features/dashboard/domain/health_category.dart';

/// Immutable definition of a single health metric.
///
/// Each metric is uniquely identified by [id] and belongs to exactly one
/// [HealthCategory]. The [graphType] tells the chart renderer which
/// visualisation to use. Platform identifiers ([hcRecordType] for Android
/// Health Connect, [hkIdentifier] for Apple HealthKit) are nullable because
/// some metrics are platform-exclusive.
///
/// Example:
/// ```dart
/// const steps = HealthMetric(
///   id: 'steps',
///   displayName: 'Steps',
///   unit: 'steps',
///   category: HealthCategory.activity,
///   graphType: GraphType.bar,
///   hcRecordType: 'StepsRecord',
///   hkIdentifier: 'HKQuantityTypeIdentifierStepCount',
///   icon: Icons.directions_walk_rounded,
///   goalValue: 10000,
/// );
/// ```
class HealthMetric {
  /// Creates a [HealthMetric] definition.
  ///
  /// [id] — unique snake_case identifier (e.g. `'heart_rate'`).
  ///
  /// [displayName] — human-readable label for UI rendering.
  ///
  /// [unit] — measurement unit abbreviation (e.g. `'bpm'`, `'mg/dL'`).
  ///
  /// [category] — the [HealthCategory] this metric belongs to.
  ///
  /// [graphType] — preferred chart visualisation style.
  ///
  /// [hcRecordType] — Android Health Connect record class name,
  /// or `null` if the metric is Apple-only.
  ///
  /// [hkIdentifier] — Apple HealthKit type identifier string,
  /// or `null` if the metric is Android-only.
  ///
  /// [icon] — Material icon for lists, cards, and headers.
  ///
  /// [goalValue] — optional daily target (e.g. 10 000 for steps).
  const HealthMetric({
    required this.id,
    required this.displayName,
    required this.unit,
    required this.category,
    required this.graphType,
    this.hcRecordType,
    this.hkIdentifier,
    required this.icon,
    this.goalValue,
  });

  /// Unique snake_case identifier (e.g. `'steps'`, `'blood_glucose'`).
  final String id;

  /// Human-readable name shown in UI (e.g. "Steps", "Heart Rate").
  final String displayName;

  /// Measurement unit abbreviation (e.g. `'steps'`, `'bpm'`, `'mg/dL'`).
  final String unit;

  /// The category this metric belongs to.
  final HealthCategory category;

  /// The preferred chart visualisation for this metric.
  final GraphType graphType;

  /// Android Health Connect record class name (e.g. `'StepsRecord'`).
  ///
  /// `null` when the metric is Apple-only and has no Android equivalent.
  final String? hcRecordType;

  /// Apple HealthKit type identifier (e.g. `'HKQuantityTypeIdentifierStepCount'`).
  ///
  /// `null` when the metric is Android-only and has no iOS equivalent.
  final String? hkIdentifier;

  /// Material icon glyph used in metric lists, cards, and detail headers.
  final IconData icon;

  /// Optional daily goal / target value (e.g. 10 000 for steps, 8 for sleep hours).
  ///
  /// `null` when no standard daily goal applies to this metric.
  final double? goalValue;

  /// Whether this metric is available on iOS (has an Apple HealthKit identifier).
  bool get isAvailableOnIOS => hkIdentifier != null;

  /// Whether this metric is available on Android (has a Health Connect record type).
  bool get isAvailableOnAndroid => hcRecordType != null;

  @override
  String toString() => 'HealthMetric(id: $id, displayName: $displayName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthMetric &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
