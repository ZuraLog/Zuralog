/// Zuralog — Mock Data Repository.
///
/// In-memory stub implementation of [DataRepositoryInterface] used in
/// debug builds (`kDebugMode`) to allow the Data tab to render without a
/// running backend.
///
/// Simulates realistic network latency (400 ms) and returns fixed health data
/// that exercises every Data-tab widget path.
library;

import 'dart:math' as math;

import 'package:zuralog/features/data/data/data_repository.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';

// ── MockDataRepository ────────────────────────────────────────────────────────

/// Debug-only stub implementation of [DataRepositoryInterface].
///
/// Returns hardcoded fixture data after a short artificial delay so that
/// loading skeletons and data states are both exercisable in development.
final class MockDataRepository implements DataRepositoryInterface {
  /// Creates a const [MockDataRepository].
  const MockDataRepository();

  static const Duration _delay = Duration(milliseconds: 400);

  // ── Dashboard ─────────────────────────────────────────────────────────────

  @override
  Future<DashboardData> getDashboard({bool forceRefresh = false}) async {
    await Future<void>.delayed(_delay);
    return DashboardData(
      categories: _mockCategories(),
      visibleOrder: HealthCategory.values.map((c) => c.name).toList(),
    );
  }

  // ── Category Detail ───────────────────────────────────────────────────────

  @override
  Future<CategoryDetailData> getCategoryDetail({
    required String categoryId,
    required String timeRange,
  }) async {
    await Future<void>.delayed(_delay);
    final category = HealthCategory.fromString(categoryId) ?? HealthCategory.activity;
    return CategoryDetailData(
      category: category,
      metrics: _mockMetricsFor(category, timeRange),
      timeRange: timeRange,
    );
  }

  // ── Metric Detail ─────────────────────────────────────────────────────────

  @override
  Future<MetricDetailData> getMetricDetail({
    required String metricId,
    required String timeRange,
  }) async {
    await Future<void>.delayed(_delay);
    final tileId = TileId.fromSlug(metricId);
    final displayName = tileId?.displayName ?? _displayNameForMetric(metricId);
    final category = tileId?.category ?? HealthCategory.activity;
    return MetricDetailData(
      series: MetricSeries(
        metricId: metricId,
        displayName: displayName,
        unit: _unitForMetric(metricId),
        dataPoints: _mockDataPoints(metricId),
        sourceIntegration: 'apple_health',
        currentValue: _currentValueForMetric(metricId),
        deltaPercent: 3.2,
        average: null,
      ),
      category: category,
      aiInsight:
          'Your $displayName has been consistently trending '
          'upward over the past 7 days. Keep up the great work!',
    );
  }

  @override
  void invalidateAll() {
    // No-op: mock has no cache to invalidate.
  }

  // ── Fixture Builders ──────────────────────────────────────────────────────

  List<CategorySummary> _mockCategories() {
    return [
      CategorySummary(
        category: HealthCategory.activity,
        primaryValue: '8,432',
        unit: 'steps',
        deltaPercent: 4.2,
        trend: _trendForMetric('steps'),
      ),
      CategorySummary(
        category: HealthCategory.sleep,
        primaryValue: '7h 22m',
        unit: null,
        deltaPercent: 2.1,
        trend: _trendForMetric('sleep_duration'),
      ),
      CategorySummary(
        category: HealthCategory.heart,
        primaryValue: '62',
        unit: 'bpm RHR',
        deltaPercent: -3.1,
        trend: _trendForMetric('resting_heart_rate'),
      ),
      CategorySummary(
        category: HealthCategory.nutrition,
        primaryValue: '1,840',
        unit: 'kcal',
        deltaPercent: -1.5,
        trend: _trendForMetric('calories'),
      ),
      CategorySummary(
        category: HealthCategory.body,
        primaryValue: '78.2',
        unit: 'kg',
        deltaPercent: -0.5,
        trend: _trendForMetric('weight'),
      ),
      CategorySummary(
        category: HealthCategory.vitals,
        primaryValue: '98%',
        unit: 'SpO₂',
        deltaPercent: 0.0,
        trend: _trendForMetric('spo2'),
      ),
      CategorySummary(
        category: HealthCategory.wellness,
        primaryValue: '7',
        unit: 'mood',
        deltaPercent: 4.5,
        trend: _trendForMetric('mood'),
      ),
      CategorySummary(
        category: HealthCategory.mobility,
        primaryValue: '8',
        unit: 'floors',
        deltaPercent: 14.3,
        trend: _trendForMetric('floors_climbed'),
      ),
      CategorySummary(
        category: HealthCategory.cycle,
        primaryValue: 'Day 14',
        unit: null,
        deltaPercent: null,
        trend: _trendForMetric('cycle'),
      ),
      CategorySummary(
        category: HealthCategory.environment,
        primaryValue: '68',
        unit: 'dB',
        deltaPercent: -2.8,
        trend: _trendForMetric('environment'),
      ),
    ];
  }

  List<MetricSeries> _mockMetricsFor(
    HealthCategory category,
    String timeRange,
  ) {
    switch (category) {
      case HealthCategory.activity:
        return [
          MetricSeries(
            metricId: 'steps',
            displayName: 'Steps',
            unit: 'steps',
            dataPoints: _mockDataPoints('steps'),
            sourceIntegration: 'apple_health',
            currentValue: '8,432',
            deltaPercent: 4.2,
            average: 7800,
          ),
          MetricSeries(
            metricId: 'active_calories',
            displayName: 'Active Calories',
            unit: 'kcal',
            dataPoints: _mockDataPoints('active_calories'),
            sourceIntegration: 'apple_health',
            currentValue: '420',
            deltaPercent: 2.8,
            average: 390,
          ),
          MetricSeries(
            metricId: 'workouts',
            displayName: 'Workouts',
            unit: 'sessions',
            dataPoints: _mockDataPoints('workouts'),
            sourceIntegration: 'apple_health',
            currentValue: '1',
            deltaPercent: null,
            average: null,
          ),
          MetricSeries(
            metricId: 'distance',
            displayName: 'Distance',
            unit: 'km',
            dataPoints: _mockDataPoints('distance'),
            sourceIntegration: 'apple_health',
            currentValue: '6.2',
            deltaPercent: 3.5,
            average: 5.9,
          ),
          MetricSeries(
            metricId: 'floors_climbed',
            displayName: 'Floors Climbed',
            unit: 'floors',
            dataPoints: _mockDataPoints('floors_climbed'),
            sourceIntegration: 'apple_health',
            currentValue: '8',
            deltaPercent: 14.3,
            average: 7,
          ),
          MetricSeries(
            metricId: 'exercise_minutes',
            displayName: 'Exercise Minutes',
            unit: 'min',
            dataPoints: _mockDataPoints('exercise_minutes'),
            sourceIntegration: 'apple_health',
            currentValue: '45',
            deltaPercent: 12.5,
            average: 40,
          ),
          MetricSeries(
            metricId: 'walking_speed',
            displayName: 'Walking Speed',
            unit: 'm/s',
            dataPoints: _mockDataPoints('walking_speed'),
            sourceIntegration: 'apple_health',
            currentValue: '1.4',
            deltaPercent: 1.2,
            average: 1.38,
          ),
          MetricSeries(
            metricId: 'running_pace',
            displayName: 'Running Pace',
            unit: 'min/km',
            dataPoints: _mockDataPoints('running_pace'),
            sourceIntegration: 'apple_health',
            currentValue: '5:30',
            deltaPercent: -2.1,
            average: null,
          ),
        ];
      case HealthCategory.sleep:
        return [
          MetricSeries(
            metricId: 'sleep_duration',
            displayName: 'Sleep Duration',
            unit: 'hours',
            dataPoints: _mockDataPoints('sleep_duration'),
            sourceIntegration: 'apple_health',
            currentValue: '7.4',
            deltaPercent: 2.1,
            average: 7.1,
          ),
          MetricSeries(
            metricId: 'sleep_stages',
            displayName: 'Sleep Stages',
            unit: 'min deep',
            dataPoints: _mockDataPoints('sleep_stages'),
            sourceIntegration: 'apple_health',
            currentValue: '76',
            deltaPercent: 12.0,
            average: 68,
          ),
        ];
      case HealthCategory.heart:
        return [
          MetricSeries(
            metricId: 'resting_heart_rate',
            displayName: 'Resting Heart Rate',
            unit: 'bpm',
            dataPoints: _mockDataPoints('resting_heart_rate'),
            sourceIntegration: 'apple_health',
            currentValue: '62',
            deltaPercent: -3.1,
            average: 64,
          ),
          MetricSeries(
            metricId: 'hrv',
            displayName: 'HRV',
            unit: 'ms',
            dataPoints: _mockDataPoints('hrv'),
            sourceIntegration: 'apple_health',
            currentValue: '54',
            deltaPercent: 5.9,
            average: 51,
          ),
          MetricSeries(
            metricId: 'vo2_max',
            displayName: 'VO₂ Max',
            unit: 'mL/kg/min',
            dataPoints: _mockDataPoints('vo2_max'),
            sourceIntegration: 'apple_health',
            currentValue: '48.2',
            deltaPercent: 0.8,
            average: 47.8,
          ),
          MetricSeries(
            metricId: 'respiratory_rate',
            displayName: 'Respiratory Rate',
            unit: 'brpm',
            dataPoints: _mockDataPoints('respiratory_rate'),
            sourceIntegration: 'apple_health',
            currentValue: '14.2',
            deltaPercent: -1.4,
            average: 14.5,
          ),
        ];
      case HealthCategory.nutrition:
        return [
          MetricSeries(
            metricId: 'calories',
            displayName: 'Calories',
            unit: 'kcal',
            dataPoints: _mockDataPoints('calories'),
            sourceIntegration: 'apple_health',
            currentValue: '1,840',
            deltaPercent: -1.5,
            average: 1870,
          ),
          MetricSeries(
            metricId: 'water',
            displayName: 'Water',
            unit: 'mL',
            dataPoints: _mockDataPoints('water'),
            sourceIntegration: 'apple_health',
            currentValue: '2,100',
            deltaPercent: 5.0,
            average: 1950,
          ),
          MetricSeries(
            metricId: 'macros',
            displayName: 'Macros',
            unit: '% carbs',
            dataPoints: _mockDataPoints('macros'),
            sourceIntegration: 'apple_health',
            currentValue: '45',
            deltaPercent: null,
            average: null,
          ),
        ];
      case HealthCategory.body:
        return [
          MetricSeries(
            metricId: 'weight',
            displayName: 'Weight',
            unit: 'kg',
            dataPoints: _mockDataPoints('weight'),
            sourceIntegration: 'apple_health',
            currentValue: '78.2',
            deltaPercent: -0.5,
            average: 78.5,
          ),
          MetricSeries(
            metricId: 'body_fat',
            displayName: 'Body Fat',
            unit: '%',
            dataPoints: _mockDataPoints('body_fat'),
            sourceIntegration: 'apple_health',
            currentValue: '19.2',
            deltaPercent: -2.1,
            average: 19.6,
          ),
          MetricSeries(
            metricId: 'body_temperature',
            displayName: 'Body Temperature',
            unit: '°C',
            dataPoints: _mockDataPoints('body_temperature'),
            sourceIntegration: 'apple_health',
            currentValue: '36.8',
            deltaPercent: null,
            average: 36.7,
          ),
          MetricSeries(
            metricId: 'wrist_temperature',
            displayName: 'Wrist Temperature',
            unit: '°C',
            dataPoints: _mockDataPoints('wrist_temperature'),
            sourceIntegration: 'apple_health',
            currentValue: '35.2',
            deltaPercent: null,
            average: 35.1,
          ),
        ];
      case HealthCategory.vitals:
        return [
          MetricSeries(
            metricId: 'spo2',
            displayName: 'Blood Oxygen',
            unit: '%',
            dataPoints: _mockDataPoints('spo2'),
            sourceIntegration: 'apple_health',
            currentValue: '98',
            deltaPercent: 0.0,
            average: 97.8,
          ),
          MetricSeries(
            metricId: 'blood_pressure',
            displayName: 'Blood Pressure',
            unit: 'mmHg',
            dataPoints: _mockDataPoints('blood_pressure'),
            sourceIntegration: 'apple_health',
            currentValue: '118',
            deltaPercent: -1.2,
            average: 120,
          ),
          MetricSeries(
            metricId: 'blood_glucose',
            displayName: 'Blood Glucose',
            unit: 'mmol/L',
            dataPoints: _mockDataPoints('blood_glucose'),
            sourceIntegration: 'apple_health',
            currentValue: '5.2',
            deltaPercent: -3.7,
            average: 5.4,
          ),
        ];
      case HealthCategory.wellness:
        return [
          MetricSeries(
            metricId: 'mood',
            displayName: 'Mood',
            unit: '/10',
            dataPoints: _mockDataPoints('mood'),
            sourceIntegration: 'apple_health',
            currentValue: '7',
            deltaPercent: 4.5,
            average: 6.7,
          ),
          MetricSeries(
            metricId: 'energy',
            displayName: 'Energy',
            unit: '/10',
            dataPoints: _mockDataPoints('energy'),
            sourceIntegration: 'apple_health',
            currentValue: '6',
            deltaPercent: -2.0,
            average: 6.2,
          ),
          MetricSeries(
            metricId: 'stress',
            displayName: 'Stress',
            unit: '/100',
            dataPoints: _mockDataPoints('stress'),
            sourceIntegration: 'apple_health',
            currentValue: '32',
            deltaPercent: -8.0,
            average: 38,
          ),
          MetricSeries(
            metricId: 'mindful_minutes',
            displayName: 'Mindful Minutes',
            unit: 'min',
            dataPoints: _mockDataPoints('mindful_minutes'),
            sourceIntegration: 'apple_health',
            currentValue: '15',
            deltaPercent: 25.0,
            average: 12,
          ),
        ];
      case HealthCategory.mobility:
        return [
          MetricSeries(
            metricId: 'mobility',
            displayName: 'Mobility',
            unit: 'score',
            dataPoints: _mockDataPoints('mobility'),
            sourceIntegration: 'apple_health',
            currentValue: '72',
            deltaPercent: 3.1,
            average: 70,
          ),
        ];
      case HealthCategory.cycle:
        return [
          MetricSeries(
            metricId: 'cycle',
            displayName: 'Cycle',
            unit: 'day',
            dataPoints: _mockDataPoints('cycle'),
            sourceIntegration: 'apple_health',
            currentValue: 'Day 14',
            deltaPercent: null,
            average: null,
          ),
        ];
      case HealthCategory.environment:
        return [
          MetricSeries(
            metricId: 'environment',
            displayName: 'Environment',
            unit: 'dB',
            dataPoints: _mockDataPoints('environment'),
            sourceIntegration: 'apple_health',
            currentValue: '68',
            deltaPercent: -2.8,
            average: 70,
          ),
        ];
    }
  }

  List<MetricDataPoint> _mockDataPoints(String metricId) {
    final now = DateTime.now();
    final base = _baseValueForMetric(metricId);
    final rng = math.Random(metricId.hashCode);
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final variation = (rng.nextDouble() * 2 - 1) * (base * 0.20);
      return MetricDataPoint(
        timestamp: day.toIso8601String().split('T').first,
        value: (base + variation).clamp(0.0, double.infinity),
      );
    });
  }

  List<double> _trendForMetric(String metricId) =>
      _mockDataPoints(metricId).map((p) => p.value).toList();

  double _baseValueForMetric(String metricId) {
    switch (metricId) {
      // Activity
      case 'steps':             return 8432.0;
      case 'active_calories':   return 420.0;
      case 'workouts':          return 1.0;
      case 'distance':          return 6.2;
      case 'floors_climbed':    return 8.0;
      case 'exercise_minutes':  return 45.0;
      case 'walking_speed':     return 1.4;
      case 'running_pace':      return 330.0; // seconds per km
      // Sleep
      case 'sleep_duration':    return 7.4;
      case 'sleep_stages':      return 76.0; // deep sleep minutes
      // Heart
      case 'resting_heart_rate': return 62.0;
      case 'hrv':               return 54.0;
      case 'vo2_max':           return 48.2;
      case 'respiratory_rate':  return 14.2;
      // Nutrition
      case 'calories':          return 1840.0;
      case 'water':             return 2100.0;
      case 'macros':            return 45.0; // % carbs
      // Body
      case 'weight':            return 78.2;
      case 'body_fat':          return 19.2;
      case 'body_temperature':  return 36.8;
      case 'wrist_temperature': return 35.2;
      // Vitals
      case 'spo2':              return 98.0;
      case 'blood_pressure':    return 118.0;
      case 'blood_glucose':     return 5.2;
      // Wellness
      case 'mood':              return 7.0;
      case 'energy':            return 6.0;
      case 'stress':            return 32.0;
      case 'mindful_minutes':   return 15.0;
      // Mobility / Cycle / Environment
      case 'mobility':          return 72.0;
      case 'cycle':             return 14.0;
      case 'environment':       return 68.0;
      default:                  return 100.0;
    }
  }

  String _displayNameForMetric(String metricId) {
    switch (metricId) {
      case 'steps':             return 'Steps';
      case 'active_calories':   return 'Active Calories';
      case 'workouts':          return 'Workouts';
      case 'distance':          return 'Distance';
      case 'floors_climbed':    return 'Floors Climbed';
      case 'exercise_minutes':  return 'Exercise Minutes';
      case 'walking_speed':     return 'Walking Speed';
      case 'running_pace':      return 'Running Pace';
      case 'sleep_duration':    return 'Sleep Duration';
      case 'sleep_stages':      return 'Sleep Stages';
      case 'resting_heart_rate': return 'Resting Heart Rate';
      case 'hrv':               return 'HRV';
      case 'vo2_max':           return 'VO₂ Max';
      case 'respiratory_rate':  return 'Respiratory Rate';
      case 'calories':          return 'Calories';
      case 'water':             return 'Water';
      case 'macros':            return 'Macros';
      case 'weight':            return 'Weight';
      case 'body_fat':          return 'Body Fat';
      case 'body_temperature':  return 'Body Temperature';
      case 'wrist_temperature': return 'Wrist Temperature';
      case 'spo2':              return 'Blood Oxygen';
      case 'blood_pressure':    return 'Blood Pressure';
      case 'blood_glucose':     return 'Blood Glucose';
      case 'mood':              return 'Mood';
      case 'energy':            return 'Energy';
      case 'stress':            return 'Stress';
      case 'mindful_minutes':   return 'Mindful Minutes';
      case 'mobility':          return 'Mobility';
      case 'cycle':             return 'Cycle';
      case 'environment':       return 'Environment';
      default:
        return metricId
            .split('_')
            .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
    }
  }

  String _unitForMetric(String metricId) {
    switch (metricId) {
      case 'steps':             return 'steps';
      case 'active_calories':   return 'kcal';
      case 'workouts':          return 'sessions';
      case 'distance':          return 'km';
      case 'floors_climbed':    return 'floors';
      case 'exercise_minutes':  return 'min';
      case 'walking_speed':     return 'm/s';
      case 'running_pace':      return 'min/km';
      case 'sleep_duration':    return 'hours';
      case 'sleep_stages':      return 'min deep';
      case 'resting_heart_rate': return 'bpm';
      case 'hrv':               return 'ms';
      case 'vo2_max':           return 'mL/kg/min';
      case 'respiratory_rate':  return 'brpm';
      case 'calories':          return 'kcal';
      case 'water':             return 'mL';
      case 'macros':            return '% carbs';
      case 'weight':            return 'kg';
      case 'body_fat':          return '%';
      case 'body_temperature':  return '°C';
      case 'wrist_temperature': return '°C';
      case 'spo2':              return '%';
      case 'blood_pressure':    return 'mmHg';
      case 'blood_glucose':     return 'mmol/L';
      case 'mood':              return '/10';
      case 'energy':            return '/10';
      case 'stress':            return '/100';
      case 'mindful_minutes':   return 'min';
      case 'mobility':          return 'score';
      case 'cycle':             return 'day';
      case 'environment':       return 'dB';
      default:                  return '';
    }
  }

  String _currentValueForMetric(String metricId) {
    switch (metricId) {
      case 'steps':             return '8,432';
      case 'active_calories':   return '420';
      case 'workouts':          return '1';
      case 'distance':          return '6.2';
      case 'floors_climbed':    return '8';
      case 'exercise_minutes':  return '45';
      case 'walking_speed':     return '1.4';
      case 'running_pace':      return '5:30';
      case 'sleep_duration':    return '7.4';
      case 'sleep_stages':      return '76';
      case 'resting_heart_rate': return '62';
      case 'hrv':               return '54';
      case 'vo2_max':           return '48.2';
      case 'respiratory_rate':  return '14.2';
      case 'calories':          return '1,840';
      case 'water':             return '2,100';
      case 'macros':            return '45';
      case 'weight':            return '78.2';
      case 'body_fat':          return '19.2';
      case 'body_temperature':  return '36.8';
      case 'wrist_temperature': return '35.2';
      case 'spo2':              return '98';
      case 'blood_pressure':    return '118/76';
      case 'blood_glucose':     return '5.2';
      case 'mood':              return '7';
      case 'energy':            return '6';
      case 'stress':            return '32';
      case 'mindful_minutes':   return '15';
      case 'mobility':          return '72';
      case 'cycle':             return 'Day 14';
      case 'environment':       return '68';
      default:                  return '—';
    }
  }
}
