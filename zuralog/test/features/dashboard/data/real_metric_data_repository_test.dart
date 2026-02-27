/// Tests for [RealMetricDataRepository].
///
/// Verifies the core data-resolution strategy:
///   - Returns empty series for unknown metric IDs.
///   - Stats are zeroed when series is empty.
///   - Handles health repository returning zero/null values gracefully.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/core/health/health_bridge.dart';
import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/analytics/data/analytics_repository.dart';
import 'package:zuralog/features/dashboard/data/real_metric_data_repository.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';
import 'package:zuralog/features/health/data/health_repository.dart';

// ---------------------------------------------------------------------------
// Minimal stubs (no generated code required)
// ---------------------------------------------------------------------------

/// [HealthBridge] stub that returns zero / empty for all reads.
class _ZeroHealthBridge extends HealthBridge {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> requestAuthorization() async => false;

  @override
  Future<bool> checkPermissions() async => false;

  @override
  Future<double> getSteps(DateTime date) async => 0.0;

  @override
  Future<List<Map<String, dynamic>>> getWorkouts(
    DateTime startDate,
    DateTime endDate,
  ) async => [];

  @override
  Future<List<Map<String, dynamic>>> getSleep(
    DateTime startDate,
    DateTime endDate,
  ) async => [];

  @override
  Future<double?> getWeight() async => null;

  @override
  Future<double?> getCaloriesBurned(DateTime date) async => null;

  @override
  Future<double?> getNutritionCalories(DateTime date) async => null;

  @override
  Future<double?> getRestingHeartRate() async => null;

  @override
  Future<double?> getHRV() async => null;

  @override
  Future<double?> getCardioFitness() async => null;

  @override
  Future<double> getDistance(DateTime date) async => 0.0;

  @override
  Future<double> getFlights(DateTime date) async => 0.0;

  @override
  Future<double?> getBodyFat() async => null;

  @override
  Future<double?> getRespiratoryRate() async => null;

  @override
  Future<double?> getOxygenSaturation() async => null;

  @override
  Future<double?> getHeartRate() async => null;

  @override
  Future<Map<String, dynamic>?> getBloodPressure() async => null;

  @override
  Future<bool> startBackgroundObservers() async => false;

  @override
  Future<bool> configureBackgroundSync({
    required String authToken,
    required String apiBaseUrl,
  }) async => false;

  @override
  Future<bool> triggerSync(String type) async => false;

  @override
  Future<bool> writeWorkout({
    required String activityType,
    required DateTime startDate,
    required DateTime endDate,
    required double energyBurned,
  }) async => false;

  @override
  Future<bool> writeNutrition({
    required double calories,
    required DateTime date,
  }) async => false;

  @override
  Future<bool> writeWeight({
    required double weightKg,
    required DateTime date,
  }) async => false;
}

/// [ApiClient] stub that throws on every call (analytics unavailable).
class _UnavailableApiClient extends ApiClient {
  _UnavailableApiClient() : super(onUnauthenticated: () {});

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    throw Exception('API unavailable in test');
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late RealMetricDataRepository repository;

  setUp(() {
    final healthRepo = HealthRepository(bridge: _ZeroHealthBridge());
    final analyticsRepo =
        AnalyticsRepository(apiClient: _UnavailableApiClient());
    repository = RealMetricDataRepository(
      healthRepository: healthRepo,
      analyticsRepository: analyticsRepo,
    );
  });

  group('RealMetricDataRepository.getMetricSeries', () {
    test('returns empty series for an unknown metric ID', () async {
      final series = await repository.getMetricSeries(
        metricId: 'nonexistent_metric_xyz',
        timeRange: TimeRange.week,
      );

      expect(series.dataPoints, isEmpty);
      expect(series.metricId, equals('nonexistent_metric_xyz'));
      expect(series.stats.total, equals(0.0));
      expect(series.stats.average, equals(0.0));
    });

    test('stats are fully zeroed when series is empty', () async {
      final series = await repository.getMetricSeries(
        metricId: 'this_metric_does_not_exist',
        timeRange: TimeRange.month,
      );

      expect(series.dataPoints, isEmpty);
      expect(series.stats.min, equals(0.0));
      expect(series.stats.max, equals(0.0));
      expect(series.stats.trendPercent, equals(0.0));
    });

    test(
      'returns empty series when native bridge returns zero steps',
      () async {
        // steps is a supported metric, but the bridge stub returns 0.0
        // for every day → no points should be included.
        final series = await repository.getMetricSeries(
          metricId: 'steps',
          timeRange: TimeRange.week,
        );

        expect(series.dataPoints, isEmpty,
            reason: 'Zero step counts should not create data points');
      },
    );
  });

  group('RealMetricDataRepository.getTodaySnapshots', () {
    test('returns empty map when all reads return zero or null', () async {
      final snapshots = await repository.getTodaySnapshots([
        'steps',
        'weight',
        'resting_heart_rate',
      ]);

      // All bridge calls return 0 / null — nothing should appear in result.
      expect(snapshots, isEmpty);
    });

    test('returns empty map for completely unknown metric IDs', () async {
      final snapshots = await repository.getTodaySnapshots([
        'nonexistent_a',
        'nonexistent_b',
      ]);

      expect(snapshots, isEmpty);
    });
  });
}
