/// Zuralog — Mock Data Repository.
///
/// In-memory stub implementation of [DataRepositoryInterface] used in
/// debug builds (`kDebugMode`) to allow the Data tab to render without a
/// running backend.
///
/// Simulates realistic network latency (400 ms) and returns fixed health data
/// that exercises every Data-tab widget path.
library;

import 'package:zuralog/features/data/data/data_repository.dart';
import 'package:zuralog/features/data/domain/data_models.dart';

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
  Future<DashboardData> getDashboard() async {
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
    final category = HealthCategory.fromString(categoryId);
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
    return MetricDetailData(
      series: MetricSeries(
        metricId: metricId,
        displayName: _displayNameForMetric(metricId),
        unit: _unitForMetric(metricId),
        dataPoints: _mockDataPoints(metricId),
        sourceIntegration: 'apple_health',
        currentValue: _currentValueForMetric(metricId),
        deltaPercent: 3.2,
        average: null,
      ),
      category: HealthCategory.activity,
      aiInsight:
          'Your ${_displayNameForMetric(metricId)} has been consistently trending '
          'upward over the past 7 days. Keep up the great work!',
    );
  }

  // ── Dashboard Layout ──────────────────────────────────────────────────────

  @override
  Future<void> saveDashboardLayout(DashboardLayout layout) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // No-op in mock — layout changes are reflected immediately via provider.
  }

  @override
  Future<DashboardLayout?> getPersistedLayout() async {
    // No-op in mock — always returns null to use the default layout.
    return null;
  }

  @override
  void invalidateAll() {
    // No-op: mock has no cache to invalidate.
  }

  // ── Fixture Builders ──────────────────────────────────────────────────────

  List<CategorySummary> _mockCategories() {
    return const [
      CategorySummary(
        category: HealthCategory.activity,
        primaryValue: '8,432',
        unit: 'steps',
        deltaPercent: 4.2,
        trend: [7200.0, 7800.0, 8100.0, 6900.0, 8500.0, 7600.0, 8432.0],
      ),
      CategorySummary(
        category: HealthCategory.sleep,
        primaryValue: '7h 22m',
        unit: null,
        deltaPercent: 2.1,
        trend: [6.5, 7.0, 7.2, 6.8, 7.5, 7.1, 7.4],
      ),
      CategorySummary(
        category: HealthCategory.heart,
        primaryValue: '62',
        unit: 'bpm RHR',
        deltaPercent: -3.1,
        trend: [66.0, 65.0, 64.0, 64.0, 63.0, 63.0, 62.0],
      ),
      CategorySummary(
        category: HealthCategory.nutrition,
        primaryValue: '1,840',
        unit: 'kcal',
        deltaPercent: -1.5,
        trend: [1950.0, 1820.0, 1760.0, 1900.0, 1830.0, 1790.0, 1840.0],
      ),
      CategorySummary(
        category: HealthCategory.body,
        primaryValue: '78.2',
        unit: 'kg',
        deltaPercent: -0.5,
        trend: [78.8, 78.7, 78.6, 78.5, 78.4, 78.3, 78.2],
      ),
      CategorySummary(
        category: HealthCategory.vitals,
        primaryValue: '98%',
        unit: 'SpO₂',
        deltaPercent: 0.0,
        trend: [97.0, 98.0, 98.0, 97.0, 98.0, 98.0, 98.0],
      ),
      CategorySummary(
        category: HealthCategory.wellness,
        primaryValue: '54',
        unit: 'ms HRV',
        deltaPercent: 5.9,
        trend: [48.0, 50.0, 51.0, 53.0, 52.0, 53.0, 54.0],
      ),
      CategorySummary(
        category: HealthCategory.mobility,
        primaryValue: '—',
        unit: null,
        deltaPercent: null,
        trend: null,
      ),
      CategorySummary(
        category: HealthCategory.cycle,
        primaryValue: '—',
        unit: null,
        deltaPercent: null,
        trend: null,
      ),
      CategorySummary(
        category: HealthCategory.environment,
        primaryValue: '—',
        unit: null,
        deltaPercent: null,
        trend: null,
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
            currentValue: '8,432',
            deltaPercent: 4.2,
          ),
          MetricSeries(
            metricId: 'active_calories',
            displayName: 'Active Calories',
            unit: 'kcal',
            dataPoints: _mockDataPoints('active_calories'),
            currentValue: '420',
            deltaPercent: 2.8,
          ),
        ];
      case HealthCategory.sleep:
        return [
          MetricSeries(
            metricId: 'sleep_duration',
            displayName: 'Sleep Duration',
            unit: 'hours',
            dataPoints: _mockDataPoints('sleep_duration'),
            currentValue: '7.4',
            deltaPercent: 2.1,
          ),
          MetricSeries(
            metricId: 'deep_sleep',
            displayName: 'Deep Sleep',
            unit: 'min',
            dataPoints: _mockDataPoints('deep_sleep'),
            currentValue: '76',
            deltaPercent: 12.0,
          ),
        ];
      case HealthCategory.heart:
        return [
          MetricSeries(
            metricId: 'heart_rate_resting',
            displayName: 'Resting Heart Rate',
            unit: 'bpm',
            dataPoints: _mockDataPoints('heart_rate_resting'),
            sourceIntegration: 'apple_health',
            currentValue: '62',
            deltaPercent: -3.1,
          ),
          MetricSeries(
            metricId: 'hrv',
            displayName: 'Heart Rate Variability',
            unit: 'ms',
            dataPoints: _mockDataPoints('hrv'),
            sourceIntegration: 'apple_health',
            currentValue: '54',
            deltaPercent: 5.9,
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
            metricId: 'protein',
            displayName: 'Protein',
            unit: 'g',
            dataPoints: _mockDataPoints('protein'),
            sourceIntegration: 'apple_health',
            currentValue: '132',
            deltaPercent: 3.2,
            average: 128,
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
      case HealthCategory.wellness:
        return [
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
            metricId: 'stress',
            displayName: 'Stress Level',
            unit: '',
            dataPoints: _mockDataPoints('stress'),
            sourceIntegration: 'apple_health',
            currentValue: '32',
            deltaPercent: -8.0,
            average: 38,
          ),
        ];
      case HealthCategory.mobility:
        return [
          MetricSeries(
            metricId: 'flights_climbed',
            displayName: 'Flights Climbed',
            unit: 'flights',
            dataPoints: _mockDataPoints('flights_climbed'),
            sourceIntegration: 'apple_health',
            currentValue: '8',
            deltaPercent: 14.3,
            average: 7,
          ),
        ];
      case HealthCategory.cycle:
        return [
          MetricSeries(
            metricId: 'cycle_phase',
            displayName: 'Cycle Phase',
            unit: '',
            dataPoints: _mockDataPoints('cycle_phase'),
            sourceIntegration: 'apple_health',
            currentValue: 'Follicular',
            deltaPercent: null,
            average: null,
          ),
        ];
      case HealthCategory.environment:
        return [
          MetricSeries(
            metricId: 'noise_exposure',
            displayName: 'Noise Exposure',
            unit: 'dB',
            dataPoints: _mockDataPoints('noise_exposure'),
            sourceIntegration: 'apple_health',
            currentValue: '72',
            deltaPercent: 2.8,
            average: 70,
          ),
        ];
    }
  }

  List<MetricDataPoint> _mockDataPoints(String metricId) {
    final now = DateTime.now();
    final base = _baseValueForMetric(metricId);
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final variation = (i % 3 - 1) * (base * 0.05);
      return MetricDataPoint(
        timestamp: day.toIso8601String().split('T').first,
        value: (base + variation).clamp(0.0, double.infinity),
      );
    });
  }

  double _baseValueForMetric(String metricId) {
    switch (metricId) {
      case 'steps':
        return 8432.0;
      case 'active_calories':
        return 420.0;
      case 'sleep_duration':
        return 7.4;
      case 'deep_sleep':
        return 76.0;
      case 'heart_rate_resting':
        return 62.0;
      case 'hrv':
        return 54.0;
      case 'calories':
        return 1840.0;
      case 'protein':
        return 132.0;
      case 'weight':
        return 78.2;
      case 'body_fat':
        return 19.2;
      case 'spo2':
        return 98.0;
      case 'respiratory_rate':
        return 14.2;
      case 'stress':
        return 32.0;
      case 'flights_climbed':
        return 8.0;
      case 'cycle_phase':
        return 14.0;
      case 'noise_exposure':
        return 72.0;
      default:
        return 100.0;
    }
  }

  String _displayNameForMetric(String metricId) {
    switch (metricId) {
      case 'steps':
        return 'Steps';
      case 'active_calories':
        return 'Active Calories';
      case 'sleep_duration':
        return 'Sleep Duration';
      case 'deep_sleep':
        return 'Deep Sleep';
      case 'heart_rate_resting':
        return 'Resting Heart Rate';
      case 'hrv':
        return 'HRV';
      case 'calories':
        return 'Calories';
      case 'protein':
        return 'Protein';
      case 'weight':
        return 'Weight';
      case 'body_fat':
        return 'Body Fat';
      case 'spo2':
        return 'Blood Oxygen';
      case 'respiratory_rate':
        return 'Respiratory Rate';
      case 'stress':
        return 'Stress Level';
      case 'flights_climbed':
        return 'Flights Climbed';
      case 'cycle_phase':
        return 'Cycle Phase';
      case 'noise_exposure':
        return 'Noise Exposure';
      default:
        return metricId
            .split('_')
            .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
    }
  }

  String _unitForMetric(String metricId) {
    switch (metricId) {
      case 'steps':
        return 'steps';
      case 'active_calories':
        return 'kcal';
      case 'sleep_duration':
        return 'hours';
      case 'deep_sleep':
        return 'min';
      case 'heart_rate_resting':
        return 'bpm';
      case 'hrv':
        return 'ms';
      case 'calories':
        return 'kcal';
      case 'protein':
        return 'g';
      case 'weight':
        return 'kg';
      case 'body_fat':
        return '%';
      case 'spo2':
        return '%';
      case 'respiratory_rate':
        return 'brpm';
      case 'stress':
        return '';
      case 'flights_climbed':
        return 'flights';
      case 'cycle_phase':
        return '';
      case 'noise_exposure':
        return 'dB';
      default:
        return '';
    }
  }

  String _currentValueForMetric(String metricId) {
    switch (metricId) {
      case 'steps':
        return '8,432';
      case 'active_calories':
        return '420';
      case 'sleep_duration':
        return '7.4';
      case 'deep_sleep':
        return '76';
      case 'heart_rate_resting':
        return '62';
      case 'hrv':
        return '54';
      case 'calories':
        return '1,840';
      case 'protein':
        return '132';
      case 'weight':
        return '78.2';
      case 'body_fat':
        return '19.2';
      case 'spo2':
        return '98';
      case 'respiratory_rate':
        return '14.2';
      case 'stress':
        return '32';
      case 'flights_climbed':
        return '8';
      case 'cycle_phase':
        return 'Follicular';
      case 'noise_exposure':
        return '72';
      default:
        return '—';
    }
  }
}
