/// Zuralog Dashboard — Health Metric Registry.
///
/// Static registry of **all 117 health metrics** supported across Google
/// Health Connect (Android) and Apple HealthKit (iOS). Each metric is
/// defined once here and referenced throughout the app via [HealthMetricRegistry.byId].
///
/// Organisation:
///   - Activity (23 metrics)
///   - Body (10 metrics)
///   - Heart (7 metrics)
///   - Vitals (17 metrics)
///   - Sleep (2 metrics)
///   - Nutrition (38 metrics)
///   - Cycle (8 metrics)
///   - Wellness (3 metrics)
///   - Mobility (8 metrics — all Apple-only)
///   - Environment (1 metric — Apple-only)
///
/// Platform identifiers:
///   - `hcRecordType` — Android Health Connect record class name (null if Apple-only).
///   - `hkIdentifier` — Apple HealthKit type identifier (null if Android-only).
library;

import 'package:flutter/material.dart';

import 'package:zuralog/features/dashboard/domain/graph_type.dart';
import 'package:zuralog/features/dashboard/domain/health_category.dart';
import 'package:zuralog/features/dashboard/domain/health_metric.dart';

/// Central registry of every health metric the app can track.
///
/// All metric definitions are created once as compile-time constants and
/// exposed through static accessors. No metric instance is ever created
/// outside this class.
///
/// Usage:
/// ```dart
/// final steps = HealthMetricRegistry.byId('steps');
/// final activityMetrics = HealthMetricRegistry.byCategory(HealthCategory.activity);
/// final iosMetrics = HealthMetricRegistry.forPlatform(true);
/// ```
abstract final class HealthMetricRegistry {
  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC ACCESSORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Every registered health metric (117 total).
  static final List<HealthMetric> all = List<HealthMetric>.unmodifiable([
    ..._activity,
    ..._body,
    ..._heart,
    ..._vitals,
    ..._sleep,
    ..._nutrition,
    ..._cycle,
    ..._wellness,
    ..._mobility,
    ..._environment,
  ]);

  /// Returns all metrics belonging to [category].
  static List<HealthMetric> byCategory(HealthCategory category) =>
      all.where((m) => m.category == category).toList();

  /// Looks up a single metric by its unique [id].
  ///
  /// Returns `null` if no metric with that ID exists in the registry.
  static HealthMetric? byId(String id) {
    // Build lookup map lazily on first access.
    _byIdCache ??= {for (final m in all) m.id: m};
    return _byIdCache![id];
  }

  /// Returns all metrics available on the given platform.
  ///
  /// When [isIOS] is `true`, returns metrics that have an Apple HealthKit
  /// identifier. When `false`, returns metrics that have an Android Health
  /// Connect record type.
  static List<HealthMetric> forPlatform({required bool isIOS}) => isIOS
      ? all.where((m) => m.isAvailableOnIOS).toList()
      : all.where((m) => m.isAvailableOnAndroid).toList();

  // Lazy-initialised lookup map for [byId].
  static Map<String, HealthMetric>? _byIdCache;

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIVITY (23)
  // ══════════════════════════════════════════════════════════════════════════

  static const List<HealthMetric> _activity = [
    HealthMetric(
      id: 'steps',
      displayName: 'Steps',
      unit: 'steps',
      category: HealthCategory.activity,
      graphType: GraphType.bar,
      hcRecordType: 'StepsRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierStepCount',
      icon: Icons.directions_walk_rounded,
      goalValue: 10000,
    ),
    HealthMetric(
      id: 'active_calories_burned',
      displayName: 'Active Calories',
      unit: 'kcal',
      category: HealthCategory.activity,
      graphType: GraphType.bar,
      hcRecordType: 'ActiveCaloriesBurnedRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierActiveEnergyBurned',
      icon: Icons.local_fire_department_rounded,
      goalValue: 500,
    ),
    HealthMetric(
      id: 'total_calories_burned',
      displayName: 'Total Calories Burned',
      unit: 'kcal',
      category: HealthCategory.activity,
      graphType: GraphType.bar,
      hcRecordType: 'TotalCaloriesBurnedRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierBasalEnergyBurned',
      icon: Icons.whatshot_rounded,
    ),
    HealthMetric(
      id: 'distance',
      displayName: 'Distance',
      unit: 'km',
      category: HealthCategory.activity,
      graphType: GraphType.bar,
      hcRecordType: 'DistanceRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDistanceWalkingRunning',
      icon: Icons.straighten_rounded,
    ),
    HealthMetric(
      id: 'distance_cycling',
      displayName: 'Cycling Distance',
      unit: 'km',
      category: HealthCategory.activity,
      graphType: GraphType.bar,
      hcRecordType: 'DistanceRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDistanceCycling',
      icon: Icons.directions_bike_rounded,
    ),
    HealthMetric(
      id: 'distance_swimming',
      displayName: 'Swimming Distance',
      unit: 'm',
      category: HealthCategory.activity,
      graphType: GraphType.bar,
      hcRecordType: 'DistanceRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDistanceSwimming',
      icon: Icons.pool_rounded,
    ),
    HealthMetric(
      id: 'distance_downhill_snow',
      displayName: 'Downhill Snow Distance',
      unit: 'km',
      category: HealthCategory.activity,
      graphType: GraphType.bar,
      hkIdentifier: 'HKQuantityTypeIdentifierDistanceDownhillSnowSports',
      icon: Icons.downhill_skiing_rounded,
    ),
    HealthMetric(
      id: 'floors_climbed',
      displayName: 'Floors Climbed',
      unit: 'floors',
      category: HealthCategory.activity,
      graphType: GraphType.bar,
      hcRecordType: 'FloorsClimbedRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierFlightsClimbed',
      icon: Icons.stairs_rounded,
    ),
    HealthMetric(
      id: 'elevation_gained',
      displayName: 'Elevation Gained',
      unit: 'm',
      category: HealthCategory.activity,
      graphType: GraphType.bar,
      hcRecordType: 'ElevationGainedRecord',
      icon: Icons.terrain_rounded,
    ),
    HealthMetric(
      id: 'exercise_sessions',
      displayName: 'Exercise Sessions',
      unit: 'sessions',
      category: HealthCategory.activity,
      graphType: GraphType.calendarHeatmap,
      hcRecordType: 'ExerciseSessionRecord',
      hkIdentifier: 'HKWorkoutType',
      icon: Icons.fitness_center_rounded,
    ),
    HealthMetric(
      id: 'steps_cadence',
      displayName: 'Steps Cadence',
      unit: 'spm',
      category: HealthCategory.activity,
      graphType: GraphType.line,
      hcRecordType: 'StepsCadenceRecord',
      icon: Icons.speed_rounded,
    ),
    HealthMetric(
      id: 'cycling_pedaling_cadence',
      displayName: 'Cycling Cadence',
      unit: 'rpm',
      category: HealthCategory.activity,
      graphType: GraphType.line,
      hcRecordType: 'CyclingPedalingCadenceRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierCyclingCadence',
      icon: Icons.rotate_right_rounded,
    ),
    HealthMetric(
      id: 'cycling_speed',
      displayName: 'Cycling Speed',
      unit: 'km/h',
      category: HealthCategory.activity,
      graphType: GraphType.line,
      hcRecordType: 'SpeedRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierCyclingSpeed',
      icon: Icons.speed_rounded,
    ),
    HealthMetric(
      id: 'cycling_power',
      displayName: 'Cycling Power',
      unit: 'W',
      category: HealthCategory.activity,
      graphType: GraphType.line,
      hcRecordType: 'PowerRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierCyclingPower',
      icon: Icons.bolt_rounded,
    ),
    HealthMetric(
      id: 'running_speed',
      displayName: 'Running Speed',
      unit: 'km/h',
      category: HealthCategory.activity,
      graphType: GraphType.line,
      hcRecordType: 'SpeedRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierRunningSpeed',
      icon: Icons.directions_run_rounded,
    ),
    HealthMetric(
      id: 'running_power',
      displayName: 'Running Power',
      unit: 'W',
      category: HealthCategory.activity,
      graphType: GraphType.line,
      hcRecordType: 'PowerRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierRunningPower',
      icon: Icons.bolt_rounded,
    ),
    HealthMetric(
      id: 'running_stride_length',
      displayName: 'Running Stride Length',
      unit: 'm',
      category: HealthCategory.activity,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierRunningStrideLength',
      icon: Icons.straighten_rounded,
    ),
    HealthMetric(
      id: 'running_vertical_oscillation',
      displayName: 'Vertical Oscillation',
      unit: 'cm',
      category: HealthCategory.activity,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierRunningVerticalOscillation',
      icon: Icons.swap_vert_rounded,
    ),
    HealthMetric(
      id: 'running_ground_contact_time',
      displayName: 'Ground Contact Time',
      unit: 'ms',
      category: HealthCategory.activity,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierRunningGroundContactTime',
      icon: Icons.timer_rounded,
    ),
    HealthMetric(
      id: 'wheelchair_pushes',
      displayName: 'Wheelchair Pushes',
      unit: 'pushes',
      category: HealthCategory.activity,
      graphType: GraphType.bar,
      hcRecordType: 'WheelchairPushesRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierPushCount',
      icon: Icons.accessible_rounded,
    ),
    HealthMetric(
      id: 'activity_intensity',
      displayName: 'Activity Intensity',
      unit: 'min',
      category: HealthCategory.activity,
      graphType: GraphType.stackedBar,
      hcRecordType: 'ExerciseSessionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierAppleExerciseTime',
      icon: Icons.trending_up_rounded,
      goalValue: 30,
    ),
    HealthMetric(
      id: 'swimming_stroke_count',
      displayName: 'Swimming Strokes',
      unit: 'strokes',
      category: HealthCategory.activity,
      graphType: GraphType.bar,
      hcRecordType: 'SwimmingStrokesRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierSwimmingStrokeCount',
      icon: Icons.pool_rounded,
    ),
    HealthMetric(
      id: 'physical_effort',
      displayName: 'Physical Effort',
      unit: 'kcal/hr·kg',
      category: HealthCategory.activity,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierPhysicalEffort',
      icon: Icons.fitness_center_rounded,
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // BODY (10)
  // ══════════════════════════════════════════════════════════════════════════

  static const List<HealthMetric> _body = [
    HealthMetric(
      id: 'weight',
      displayName: 'Weight',
      unit: 'kg',
      category: HealthCategory.body,
      graphType: GraphType.line,
      hcRecordType: 'WeightRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierBodyMass',
      icon: Icons.monitor_weight_rounded,
    ),
    HealthMetric(
      id: 'body_fat_percentage',
      displayName: 'Body Fat',
      unit: '%',
      category: HealthCategory.body,
      graphType: GraphType.line,
      hcRecordType: 'BodyFatRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierBodyFatPercentage',
      icon: Icons.pie_chart_rounded,
    ),
    HealthMetric(
      id: 'bmi',
      displayName: 'BMI',
      unit: 'kg/m²',
      category: HealthCategory.body,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierBodyMassIndex',
      icon: Icons.calculate_rounded,
    ),
    HealthMetric(
      id: 'height',
      displayName: 'Height',
      unit: 'cm',
      category: HealthCategory.body,
      graphType: GraphType.singleValue,
      hcRecordType: 'HeightRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierHeight',
      icon: Icons.height_rounded,
    ),
    HealthMetric(
      id: 'lean_body_mass',
      displayName: 'Lean Body Mass',
      unit: 'kg',
      category: HealthCategory.body,
      graphType: GraphType.line,
      hcRecordType: 'LeanBodyMassRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierLeanBodyMass',
      icon: Icons.accessibility_new_rounded,
    ),
    HealthMetric(
      id: 'basal_metabolic_rate',
      displayName: 'Basal Metabolic Rate',
      unit: 'kcal/day',
      category: HealthCategory.body,
      graphType: GraphType.line,
      hcRecordType: 'BasalMetabolicRateRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierBasalEnergyBurned',
      icon: Icons.local_fire_department_outlined,
    ),
    HealthMetric(
      id: 'body_water_mass',
      displayName: 'Body Water Mass',
      unit: 'kg',
      category: HealthCategory.body,
      graphType: GraphType.line,
      hcRecordType: 'BodyWaterMassRecord',
      icon: Icons.water_drop_outlined,
    ),
    HealthMetric(
      id: 'bone_mass',
      displayName: 'Bone Mass',
      unit: 'kg',
      category: HealthCategory.body,
      graphType: GraphType.line,
      hcRecordType: 'BoneMassRecord',
      icon: Icons.spoke_rounded,
    ),
    HealthMetric(
      id: 'waist_circumference',
      displayName: 'Waist Circumference',
      unit: 'cm',
      category: HealthCategory.body,
      graphType: GraphType.line,
      hcRecordType: 'WaistCircumferenceRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierWaistCircumference',
      icon: Icons.straighten_rounded,
    ),
    HealthMetric(
      id: 'hip_circumference',
      displayName: 'Hip Circumference',
      unit: 'cm',
      category: HealthCategory.body,
      graphType: GraphType.line,
      hcRecordType: 'HipCircumferenceRecord',
      icon: Icons.straighten_rounded,
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // HEART (7)
  // ══════════════════════════════════════════════════════════════════════════

  static const List<HealthMetric> _heart = [
    HealthMetric(
      id: 'heart_rate',
      displayName: 'Heart Rate',
      unit: 'bpm',
      category: HealthCategory.heart,
      graphType: GraphType.rangeLine,
      hcRecordType: 'HeartRateRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierHeartRate',
      icon: Icons.favorite_rounded,
    ),
    HealthMetric(
      id: 'resting_heart_rate',
      displayName: 'Resting Heart Rate',
      unit: 'bpm',
      category: HealthCategory.heart,
      graphType: GraphType.line,
      hcRecordType: 'RestingHeartRateRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierRestingHeartRate',
      icon: Icons.favorite_border_rounded,
    ),
    HealthMetric(
      id: 'heart_rate_variability',
      displayName: 'Heart Rate Variability',
      unit: 'ms',
      category: HealthCategory.heart,
      graphType: GraphType.line,
      hcRecordType: 'HeartRateVariabilityRmssdRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierHeartRateVariabilitySDNN',
      icon: Icons.monitor_heart_outlined,
    ),
    HealthMetric(
      id: 'vo2_max',
      displayName: 'VO2 Max',
      unit: 'mL/kg/min',
      category: HealthCategory.heart,
      graphType: GraphType.line,
      hcRecordType: 'Vo2MaxRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierVO2Max',
      icon: Icons.air_rounded,
    ),
    HealthMetric(
      id: 'walking_heart_rate_avg',
      displayName: 'Walking Heart Rate Avg',
      unit: 'bpm',
      category: HealthCategory.heart,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierWalkingHeartRateAverage',
      icon: Icons.directions_walk_rounded,
    ),
    HealthMetric(
      id: 'heart_rate_recovery',
      displayName: 'Heart Rate Recovery',
      unit: 'bpm',
      category: HealthCategory.heart,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierHeartRateRecoveryOneMinute',
      icon: Icons.replay_rounded,
    ),
    HealthMetric(
      id: 'peripheral_perfusion_index',
      displayName: 'Peripheral Perfusion Index',
      unit: '%',
      category: HealthCategory.heart,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierPeripheralPerfusionIndex',
      icon: Icons.bloodtype_rounded,
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // VITALS (17)
  // ══════════════════════════════════════════════════════════════════════════

  static const List<HealthMetric> _vitals = [
    HealthMetric(
      id: 'blood_pressure',
      displayName: 'Blood Pressure',
      unit: 'mmHg',
      category: HealthCategory.vitals,
      graphType: GraphType.dualLine,
      hcRecordType: 'BloodPressureRecord',
      hkIdentifier: 'HKCorrelationTypeIdentifierBloodPressure',
      icon: Icons.monitor_heart_rounded,
    ),
    HealthMetric(
      id: 'respiratory_rate',
      displayName: 'Respiratory Rate',
      unit: 'brpm',
      category: HealthCategory.vitals,
      graphType: GraphType.line,
      hcRecordType: 'RespiratoryRateRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierRespiratoryRate',
      icon: Icons.air_rounded,
    ),
    HealthMetric(
      id: 'oxygen_saturation',
      displayName: 'Blood Oxygen (SpO2)',
      unit: '%',
      category: HealthCategory.vitals,
      graphType: GraphType.thresholdLine,
      hcRecordType: 'OxygenSaturationRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierOxygenSaturation',
      icon: Icons.bubble_chart_rounded,
    ),
    HealthMetric(
      id: 'body_temperature',
      displayName: 'Body Temperature',
      unit: '°C',
      category: HealthCategory.vitals,
      graphType: GraphType.line,
      hcRecordType: 'BodyTemperatureRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierBodyTemperature',
      icon: Icons.thermostat_rounded,
    ),
    HealthMetric(
      id: 'blood_glucose',
      displayName: 'Blood Glucose',
      unit: 'mg/dL',
      category: HealthCategory.vitals,
      graphType: GraphType.thresholdLine,
      hcRecordType: 'BloodGlucoseRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierBloodGlucose',
      icon: Icons.bloodtype_rounded,
    ),
    HealthMetric(
      id: 'electrodermal_activity',
      displayName: 'Electrodermal Activity',
      unit: 'μS',
      category: HealthCategory.vitals,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierElectrodermalActivity',
      icon: Icons.electric_bolt_rounded,
    ),
    HealthMetric(
      id: 'forced_vital_capacity',
      displayName: 'Forced Vital Capacity',
      unit: 'L',
      category: HealthCategory.vitals,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierForcedVitalCapacity',
      icon: Icons.air_rounded,
    ),
    HealthMetric(
      id: 'forced_expiratory_volume',
      displayName: 'Forced Expiratory Volume',
      unit: 'L',
      category: HealthCategory.vitals,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierForcedExpiratoryVolume1',
      icon: Icons.air_rounded,
    ),
    HealthMetric(
      id: 'peak_expiratory_flow',
      displayName: 'Peak Expiratory Flow',
      unit: 'L/min',
      category: HealthCategory.vitals,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierPeakExpiratoryFlowRate',
      icon: Icons.air_rounded,
    ),
    HealthMetric(
      id: 'inhaler_usage',
      displayName: 'Inhaler Usage',
      unit: 'uses',
      category: HealthCategory.vitals,
      graphType: GraphType.bar,
      hkIdentifier: 'HKQuantityTypeIdentifierInhalerUsage',
      icon: Icons.medication_rounded,
    ),
    HealthMetric(
      id: 'insulin_delivery',
      displayName: 'Insulin Delivery',
      unit: 'IU',
      category: HealthCategory.vitals,
      graphType: GraphType.combo,
      hkIdentifier: 'HKQuantityTypeIdentifierInsulinDelivery',
      icon: Icons.medication_liquid_rounded,
    ),
    HealthMetric(
      id: 'blood_alcohol_content',
      displayName: 'Blood Alcohol Content',
      unit: '%',
      category: HealthCategory.vitals,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierBloodAlcoholContent',
      icon: Icons.local_bar_rounded,
    ),
    HealthMetric(
      id: 'falls_count',
      displayName: 'Falls',
      unit: 'falls',
      category: HealthCategory.vitals,
      graphType: GraphType.bar,
      hkIdentifier: 'HKQuantityTypeIdentifierNumberOfTimesFallen',
      icon: Icons.warning_rounded,
    ),
    HealthMetric(
      id: 'uv_exposure',
      displayName: 'UV Exposure',
      unit: 'UV index',
      category: HealthCategory.vitals,
      graphType: GraphType.bar,
      hkIdentifier: 'HKQuantityTypeIdentifierUVExposure',
      icon: Icons.wb_sunny_rounded,
    ),
    HealthMetric(
      id: 'environmental_audio_exposure',
      displayName: 'Environmental Sound',
      unit: 'dB',
      category: HealthCategory.vitals,
      graphType: GraphType.thresholdLine,
      hkIdentifier: 'HKQuantityTypeIdentifierEnvironmentalAudioExposure',
      icon: Icons.hearing_rounded,
    ),
    HealthMetric(
      id: 'headphone_audio_exposure',
      displayName: 'Headphone Audio',
      unit: 'dB',
      category: HealthCategory.vitals,
      graphType: GraphType.thresholdLine,
      hkIdentifier: 'HKQuantityTypeIdentifierHeadphoneAudioExposure',
      icon: Icons.headphones_rounded,
    ),
    HealthMetric(
      id: 'underwater_depth',
      displayName: 'Underwater Depth',
      unit: 'm',
      category: HealthCategory.vitals,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierUnderwaterDepth',
      icon: Icons.scuba_diving_rounded,
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // SLEEP (2)
  // ══════════════════════════════════════════════════════════════════════════

  static const List<HealthMetric> _sleep = [
    HealthMetric(
      id: 'sleep_duration',
      displayName: 'Sleep Duration',
      unit: 'hrs',
      category: HealthCategory.sleep,
      graphType: GraphType.bar,
      hcRecordType: 'SleepSessionRecord',
      hkIdentifier: 'HKCategoryTypeIdentifierSleepAnalysis',
      icon: Icons.bedtime_rounded,
      goalValue: 8,
    ),
    HealthMetric(
      id: 'sleep_stages',
      displayName: 'Sleep Stages',
      unit: 'hrs',
      category: HealthCategory.sleep,
      graphType: GraphType.stackedBar,
      hcRecordType: 'SleepSessionRecord',
      hkIdentifier: 'HKCategoryTypeIdentifierSleepAnalysis',
      icon: Icons.nights_stay_rounded,
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // NUTRITION (38)
  // ══════════════════════════════════════════════════════════════════════════

  static const List<HealthMetric> _nutrition = [
    HealthMetric(
      id: 'dietary_energy',
      displayName: 'Calories Consumed',
      unit: 'kcal',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryEnergyConsumed',
      icon: Icons.restaurant_rounded,
      goalValue: 2000,
    ),
    HealthMetric(
      id: 'protein',
      displayName: 'Protein',
      unit: 'g',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryProtein',
      icon: Icons.egg_rounded,
    ),
    HealthMetric(
      id: 'carbohydrates',
      displayName: 'Carbohydrates',
      unit: 'g',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryCarbohydrates',
      icon: Icons.bakery_dining_rounded,
    ),
    HealthMetric(
      id: 'fat_total',
      displayName: 'Total Fat',
      unit: 'g',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryFatTotal',
      icon: Icons.opacity_rounded,
    ),
    HealthMetric(
      id: 'saturated_fat',
      displayName: 'Saturated Fat',
      unit: 'g',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryFatSaturated',
      icon: Icons.opacity_rounded,
    ),
    HealthMetric(
      id: 'monounsaturated_fat',
      displayName: 'Monounsaturated Fat',
      unit: 'g',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryFatMonounsaturated',
      icon: Icons.opacity_rounded,
    ),
    HealthMetric(
      id: 'polyunsaturated_fat',
      displayName: 'Polyunsaturated Fat',
      unit: 'g',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryFatPolyunsaturated',
      icon: Icons.opacity_rounded,
    ),
    HealthMetric(
      id: 'sugar',
      displayName: 'Sugar',
      unit: 'g',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietarySugar',
      icon: Icons.cake_rounded,
    ),
    HealthMetric(
      id: 'fiber',
      displayName: 'Fiber',
      unit: 'g',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryFiber',
      icon: Icons.grass_rounded,
    ),
    HealthMetric(
      id: 'cholesterol',
      displayName: 'Cholesterol',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryCholesterol',
      icon: Icons.science_rounded,
    ),
    HealthMetric(
      id: 'sodium',
      displayName: 'Sodium',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietarySodium',
      icon: Icons.science_rounded,
    ),
    HealthMetric(
      id: 'calcium',
      displayName: 'Calcium',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryCalcium',
      icon: Icons.science_rounded,
    ),
    HealthMetric(
      id: 'iron',
      displayName: 'Iron',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryIron',
      icon: Icons.science_rounded,
    ),
    HealthMetric(
      id: 'potassium',
      displayName: 'Potassium',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryPotassium',
      icon: Icons.science_rounded,
    ),
    HealthMetric(
      id: 'magnesium',
      displayName: 'Magnesium',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryMagnesium',
      icon: Icons.science_rounded,
    ),
    HealthMetric(
      id: 'phosphorus',
      displayName: 'Phosphorus',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryPhosphorus',
      icon: Icons.science_rounded,
    ),
    HealthMetric(
      id: 'zinc',
      displayName: 'Zinc',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryZinc',
      icon: Icons.science_rounded,
    ),
    HealthMetric(
      id: 'copper',
      displayName: 'Copper',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryCopper',
      icon: Icons.science_rounded,
    ),
    HealthMetric(
      id: 'manganese',
      displayName: 'Manganese',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryManganese',
      icon: Icons.science_rounded,
    ),
    HealthMetric(
      id: 'selenium',
      displayName: 'Selenium',
      unit: 'mcg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietarySelenium',
      icon: Icons.science_rounded,
    ),
    HealthMetric(
      id: 'chromium',
      displayName: 'Chromium',
      unit: 'mcg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryChromium',
      icon: Icons.science_rounded,
    ),
    HealthMetric(
      id: 'molybdenum',
      displayName: 'Molybdenum',
      unit: 'mcg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryMolybdenum',
      icon: Icons.science_rounded,
    ),
    HealthMetric(
      id: 'iodine',
      displayName: 'Iodine',
      unit: 'mcg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryIodine',
      icon: Icons.science_rounded,
    ),
    HealthMetric(
      id: 'vitamin_a',
      displayName: 'Vitamin A',
      unit: 'mcg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryVitaminA',
      icon: Icons.medication_rounded,
    ),
    HealthMetric(
      id: 'vitamin_b6',
      displayName: 'Vitamin B6',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryVitaminB6',
      icon: Icons.medication_rounded,
    ),
    HealthMetric(
      id: 'vitamin_b12',
      displayName: 'Vitamin B12',
      unit: 'mcg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryVitaminB12',
      icon: Icons.medication_rounded,
    ),
    HealthMetric(
      id: 'vitamin_c',
      displayName: 'Vitamin C',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryVitaminC',
      icon: Icons.medication_rounded,
    ),
    HealthMetric(
      id: 'vitamin_d',
      displayName: 'Vitamin D',
      unit: 'mcg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryVitaminD',
      icon: Icons.medication_rounded,
    ),
    HealthMetric(
      id: 'vitamin_e',
      displayName: 'Vitamin E',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryVitaminE',
      icon: Icons.medication_rounded,
    ),
    HealthMetric(
      id: 'vitamin_k',
      displayName: 'Vitamin K',
      unit: 'mcg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryVitaminK',
      icon: Icons.medication_rounded,
    ),
    HealthMetric(
      id: 'biotin',
      displayName: 'Biotin',
      unit: 'mcg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryBiotin',
      icon: Icons.medication_rounded,
    ),
    HealthMetric(
      id: 'folate',
      displayName: 'Folate',
      unit: 'mcg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryFolate',
      icon: Icons.medication_rounded,
    ),
    HealthMetric(
      id: 'niacin',
      displayName: 'Niacin',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryNiacin',
      icon: Icons.medication_rounded,
    ),
    HealthMetric(
      id: 'pantothenic_acid',
      displayName: 'Pantothenic Acid',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryPantothenicAcid',
      icon: Icons.medication_rounded,
    ),
    HealthMetric(
      id: 'riboflavin',
      displayName: 'Riboflavin',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryRiboflavin',
      icon: Icons.medication_rounded,
    ),
    HealthMetric(
      id: 'thiamin',
      displayName: 'Thiamin',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryThiamin',
      icon: Icons.medication_rounded,
    ),
    HealthMetric(
      id: 'caffeine',
      displayName: 'Caffeine',
      unit: 'mg',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'NutritionRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryCaffeine',
      icon: Icons.coffee_rounded,
    ),
    HealthMetric(
      id: 'hydration',
      displayName: 'Hydration',
      unit: 'mL',
      category: HealthCategory.nutrition,
      graphType: GraphType.bar,
      hcRecordType: 'HydrationRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierDietaryWater',
      icon: Icons.water_drop_rounded,
      goalValue: 2500,
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // CYCLE (8)
  // ══════════════════════════════════════════════════════════════════════════

  static const List<HealthMetric> _cycle = [
    HealthMetric(
      id: 'basal_body_temperature',
      displayName: 'Basal Body Temperature',
      unit: '°C',
      category: HealthCategory.cycle,
      graphType: GraphType.line,
      hcRecordType: 'BasalBodyTemperatureRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierBasalBodyTemperature',
      icon: Icons.thermostat_rounded,
    ),
    HealthMetric(
      id: 'cervical_mucus',
      displayName: 'Cervical Mucus',
      unit: 'type',
      category: HealthCategory.cycle,
      graphType: GraphType.calendarHeatmap,
      hcRecordType: 'CervicalMucusRecord',
      hkIdentifier: 'HKCategoryTypeIdentifierCervicalMucusQuality',
      icon: Icons.water_drop_rounded,
    ),
    HealthMetric(
      id: 'menstruation_flow',
      displayName: 'Menstruation Flow',
      unit: 'level',
      category: HealthCategory.cycle,
      graphType: GraphType.calendarMarker,
      hcRecordType: 'MenstruationFlowRecord',
      hkIdentifier: 'HKCategoryTypeIdentifierMenstrualFlow',
      icon: Icons.water_drop_rounded,
    ),
    HealthMetric(
      id: 'menstruation_period',
      displayName: 'Menstruation Period',
      unit: 'days',
      category: HealthCategory.cycle,
      graphType: GraphType.calendarMarker,
      hcRecordType: 'MenstruationPeriodRecord',
      hkIdentifier: 'HKCategoryTypeIdentifierMenstrualFlow',
      icon: Icons.calendar_month_rounded,
    ),
    HealthMetric(
      id: 'intermenstrual_bleeding',
      displayName: 'Intermenstrual Bleeding',
      unit: 'event',
      category: HealthCategory.cycle,
      graphType: GraphType.calendarMarker,
      hcRecordType: 'IntermenstrualBleedingRecord',
      hkIdentifier: 'HKCategoryTypeIdentifierIntermenstrualBleeding',
      icon: Icons.warning_amber_rounded,
    ),
    HealthMetric(
      id: 'ovulation_test',
      displayName: 'Ovulation Test',
      unit: 'result',
      category: HealthCategory.cycle,
      graphType: GraphType.calendarMarker,
      hcRecordType: 'OvulationTestRecord',
      hkIdentifier: 'HKCategoryTypeIdentifierOvulationTestResult',
      icon: Icons.science_rounded,
    ),
    HealthMetric(
      id: 'sexual_activity',
      displayName: 'Sexual Activity',
      unit: 'event',
      category: HealthCategory.cycle,
      graphType: GraphType.calendarMarker,
      hcRecordType: 'SexualActivityRecord',
      hkIdentifier: 'HKCategoryTypeIdentifierSexualActivity',
      icon: Icons.favorite_rounded,
    ),
    HealthMetric(
      id: 'contraceptive',
      displayName: 'Contraceptive',
      unit: 'type',
      category: HealthCategory.cycle,
      graphType: GraphType.calendarMarker,
      hkIdentifier: 'HKCategoryTypeIdentifierContraceptive',
      icon: Icons.medication_rounded,
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // WELLNESS (3)
  // ══════════════════════════════════════════════════════════════════════════

  static const List<HealthMetric> _wellness = [
    HealthMetric(
      id: 'mindfulness_session',
      displayName: 'Mindfulness',
      unit: 'min',
      category: HealthCategory.wellness,
      graphType: GraphType.bar,
      hcRecordType: 'MindfulnessSessionRecord',
      hkIdentifier: 'HKCategoryTypeIdentifierMindfulSession',
      icon: Icons.self_improvement_rounded,
      goalValue: 10,
    ),
    HealthMetric(
      id: 'skin_temperature',
      displayName: 'Skin Temperature',
      unit: '°C',
      category: HealthCategory.wellness,
      graphType: GraphType.line,
      hcRecordType: 'SkinTemperatureRecord',
      hkIdentifier: 'HKQuantityTypeIdentifierAppleSleepingWristTemperature',
      icon: Icons.thermostat_rounded,
    ),
    HealthMetric(
      id: 'state_of_mind',
      displayName: 'State of Mind',
      unit: 'scale',
      category: HealthCategory.wellness,
      graphType: GraphType.moodTimeline,
      hkIdentifier: 'HKStateOfMind',
      icon: Icons.mood_rounded,
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILITY (8 — all Apple-only)
  // ══════════════════════════════════════════════════════════════════════════

  static const List<HealthMetric> _mobility = [
    HealthMetric(
      id: 'six_minute_walk_distance',
      displayName: 'Six-Minute Walk Distance',
      unit: 'm',
      category: HealthCategory.mobility,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierSixMinuteWalkTestDistance',
      icon: Icons.directions_walk_rounded,
    ),
    HealthMetric(
      id: 'stair_ascent_speed',
      displayName: 'Stair Ascent Speed',
      unit: 'm/s',
      category: HealthCategory.mobility,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierStairAscentSpeed',
      icon: Icons.stairs_rounded,
    ),
    HealthMetric(
      id: 'stair_descent_speed',
      displayName: 'Stair Descent Speed',
      unit: 'm/s',
      category: HealthCategory.mobility,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierStairDescentSpeed',
      icon: Icons.stairs_rounded,
    ),
    HealthMetric(
      id: 'walking_speed',
      displayName: 'Walking Speed',
      unit: 'km/h',
      category: HealthCategory.mobility,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierWalkingSpeed',
      icon: Icons.speed_rounded,
    ),
    HealthMetric(
      id: 'walking_step_length',
      displayName: 'Walking Step Length',
      unit: 'cm',
      category: HealthCategory.mobility,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierWalkingStepLength',
      icon: Icons.straighten_rounded,
    ),
    HealthMetric(
      id: 'walking_asymmetry',
      displayName: 'Walking Asymmetry',
      unit: '%',
      category: HealthCategory.mobility,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierWalkingAsymmetryPercentage',
      icon: Icons.balance_rounded,
    ),
    HealthMetric(
      id: 'walking_double_support',
      displayName: 'Walking Double Support',
      unit: '%',
      category: HealthCategory.mobility,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierWalkingDoubleSupportPercentage',
      icon: Icons.balance_rounded,
    ),
    HealthMetric(
      id: 'walking_steadiness',
      displayName: 'Walking Steadiness',
      unit: '%',
      category: HealthCategory.mobility,
      graphType: GraphType.thresholdLine,
      hkIdentifier: 'HKQuantityTypeIdentifierAppleWalkingSteadiness',
      icon: Icons.balance_rounded,
    ),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // ENVIRONMENT (1 — Apple-only)
  // ══════════════════════════════════════════════════════════════════════════

  static const List<HealthMetric> _environment = [
    HealthMetric(
      id: 'water_temperature',
      displayName: 'Water Temperature',
      unit: '°C',
      category: HealthCategory.environment,
      graphType: GraphType.line,
      hkIdentifier: 'HKQuantityTypeIdentifierWaterTemperature',
      icon: Icons.thermostat_rounded,
    ),
  ];
}
