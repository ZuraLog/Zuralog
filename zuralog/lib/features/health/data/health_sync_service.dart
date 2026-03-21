/// Service that reads local HealthKit/Health Connect data and pushes it
/// to the Cloud Brain's `/health/ingest` endpoint.
///
/// This is the core device-to-cloud pipeline. Called on:
/// - App launch (if Apple Health is connected)
/// - Pull-to-refresh on dashboard
/// - After connecting Apple Health in integrations hub
/// - Background sync triggers (via FCM or native observers)
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/monitoring/sentry_breadcrumbs.dart';
import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/features/health/data/health_repository.dart';

/// Reads all available HealthKit/Health Connect data and pushes it to the
/// Cloud Brain via the `/api/v1/health/ingest` REST endpoint.
///
/// Callers should `await` the result only when they need to know success/failure.
/// For background triggers, call without awaiting.
class HealthSyncService {
  /// Creates a [HealthSyncService].
  ///
  /// Parameters:
  /// - [healthRepository]: Provides local HealthKit/Health Connect reads.
  /// - [apiClient]: Handles authenticated REST calls to the Cloud Brain.
  /// - [analyticsService]: Optional analytics for sync event tracking.
  HealthSyncService({
    required HealthRepository healthRepository,
    required ApiClient apiClient,
    AnalyticsService? analyticsService,
  }) : _healthRepo = healthRepository,
       _apiClient = apiClient,
       _analytics = analyticsService;

  final HealthRepository _healthRepo;
  final ApiClient _apiClient;
  final AnalyticsService? _analytics;

  /// Reads all available HealthKit data for the last [days] and pushes it
  /// to the Cloud Brain ingest endpoint.
  ///
  /// Reads for today:
  /// - Steps, active calories, nutrition calories (single-date API)
  ///
  /// Reads for the last [days] window:
  /// - Workouts and sleep (date-range API)
  ///
  /// Point-in-time reads (no date range):
  /// - Weight, resting heart rate, HRV, VO2 max
  ///
  /// Parameters:
  /// - [days]: How many days back to pull workouts and sleep. Defaults to 7.
  ///
  /// Returns:
  ///   `true` if the POST to the Cloud Brain succeeded, `false` otherwise.
  ///   Errors are caught and logged; this method never throws.
  Future<bool> syncToCloud({int days = 7}) async {
    final platform = Platform.isIOS ? 'apple_health' : 'health_connect';
    // Analytics: track sync start (fire-and-forget).
    _analytics?.capture(
      event: AnalyticsEvents.healthSyncStarted,
      properties: {'platform': platform},
    );
    SentryBreadcrumbs.healthSync(
      platform: platform,
      status: 'started',
    );
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final rangeStart = today.subtract(Duration(days: days));

      // Read scalar daily metrics for today (single-date API)
      final steps = await _healthRepo.getSteps(today);
      final activeCalories = await _healthRepo.getCaloriesBurned(today);
      final nutritionCalories = await _healthRepo.getNutritionCalories(today);

      // Phase 6 new scalar types (also single-date or point-in-time)
      final distance = await _healthRepo.getDistance(today);
      final flights = await _healthRepo.getFlights(today);

      // Read point-in-time values (most recent reading, no date arg)
      final weight = await _healthRepo.getWeight();
      final rhr = await _healthRepo.getRestingHeartRate();
      final hrv = await _healthRepo.getHRV();
      final vo2 = await _healthRepo.getCardioFitness();

      // Phase 6 point-in-time new types
      final bodyFat = await _healthRepo.getBodyFat();
      final respiratoryRate = await _healthRepo.getRespiratoryRate();
      final oxygenSaturation = await _healthRepo.getOxygenSaturation();
      final heartRate = await _healthRepo.getHeartRate();

      // Read date-range collections
      final workouts = await _healthRepo.getWorkouts(rangeStart, now);
      final sleepSegments = await _healthRepo.getSleep(rangeStart, now);

      // New scalar daily metrics
      final water = await _healthRepo.getWater(today);
      final bodyTemp = await _healthRepo.getBodyTemperature(today);
      final wristTemp = await _healthRepo.getWristTemperature();
      final walkingSpeed = await _healthRepo.getWalkingSpeed(today);
      final mindfulMin = await _healthRepo.getMindfulMinutes(today);

      // Blood pressure (most recent reading, no date arg)
      final bp = await _healthRepo.getBloodPressure();

      // Nutrition macros for today
      final nutritionMacros = await _healthRepo.getNutritionMacros(today);

      // Cycle data over a 30-day window
      final cycleRangeStart = today.subtract(const Duration(days: 30));
      final cycleData = await _healthRepo.getCycleData(cycleRangeStart, today);

      // Derive running pace from most recent qualifying run in the existing
      // workouts list (already fetched above).
      double? runningPaceMps;
      final latestRun = workouts
          .where(
            (w) =>
                (w['activityType'] as String?)
                    ?.toLowerCase()
                    .contains('run') ==
                true &&
                (w['totalDistance'] as num?) != null &&
                (w['duration'] as num?) != null,
          )
          .lastOrNull;
      if (latestRun != null) {
        final distM = (latestRun['totalDistance'] as num).toDouble();
        final durS = (latestRun['duration'] as num).toDouble();
        if (durS > 0) runningPaceMps = distM / durS;
      }

      final todayStr = _isoDate(today);

      // Use the correct source name for each platform so the Cloud Brain
      // DB and deduplication engine know the origin of the data.
      final source = Platform.isAndroid ? 'health_connect' : 'apple_health';

      final payload = <String, dynamic>{
        'source': source,
        'daily_metrics': [
          {
            'date': todayStr,
            'steps': steps.round(),
            'active_calories': (activeCalories ?? 0.0).round(),
            if (rhr != null && rhr > 0) 'resting_heart_rate': rhr,
            if (hrv != null && hrv > 0) 'hrv_ms': hrv,
            if (vo2 != null && vo2 > 0) 'vo2_max': vo2,
            // Phase 6 new types
            if (distance > 0) 'distance_meters': distance,
            if (flights > 0) 'flights_climbed': flights.round(),
            if (bodyFat != null && bodyFat > 0) 'body_fat_percentage': bodyFat,
            if (respiratoryRate != null && respiratoryRate > 0)
              'respiratory_rate': respiratoryRate,
            if (oxygenSaturation != null && oxygenSaturation > 0)
              'oxygen_saturation': oxygenSaturation,
            if (heartRate != null && heartRate > 0) 'heart_rate_avg': heartRate,
            // Blood pressure (flat keys, bug fix — was fetched but never sent)
            if (bp != null && bp['systolic'] != null)
              'blood_pressure_systolic': bp['systolic'],
            if (bp != null && bp['diastolic'] != null)
              'blood_pressure_diastolic': bp['diastolic'],
            // Water
            if (water != null && water > 0) 'water_liters': water,
            // Body temperature
            if (bodyTemp != null && bodyTemp > 0)
              'body_temperature_celsius': bodyTemp,
            // Wrist temperature (Apple Watch only)
            'wrist_temperature_deviation': ?wristTemp,
            // Walking speed
            if (walkingSpeed != null && walkingSpeed > 0)
              'walking_speed_mps': walkingSpeed,
            // Mindful minutes
            if (mindfulMin != null && mindfulMin > 0)
              'mindful_minutes': mindfulMin,
            // Nutrition macros
            if (nutritionMacros != null &&
                nutritionMacros['nutrition_calories'] != null)
              'nutrition_calories': nutritionMacros['nutrition_calories'],
            if (nutritionMacros != null &&
                nutritionMacros['nutrition_protein_g'] != null)
              'nutrition_protein_g': nutritionMacros['nutrition_protein_g'],
            if (nutritionMacros != null &&
                nutritionMacros['nutrition_carbs_g'] != null)
              'nutrition_carbs_g': nutritionMacros['nutrition_carbs_g'],
            if (nutritionMacros != null &&
                nutritionMacros['nutrition_fat_g'] != null)
              'nutrition_fat_g': nutritionMacros['nutrition_fat_g'],
            if (nutritionMacros != null &&
                nutritionMacros['nutrition_fiber_g'] != null)
              'nutrition_fiber_g': nutritionMacros['nutrition_fiber_g'],
            // Cycle data (most recent entry from the 30-day window)
            if (cycleData.isNotEmpty)
              'cycle_phase': cycleData.last['cycle_phase'] ?? 'unknown',
            if (cycleData.isNotEmpty)
              'cycle_flow_intensity':
                  cycleData.last['cycle_flow_intensity'] ?? 0,
            if (cycleData.isNotEmpty) 'cycle_day': cycleData.length,
            // Running pace derived from most recent qualifying run
            if (runningPaceMps != null && runningPaceMps > 0)
              'running_pace_mps': runningPaceMps,
          },
        ],
        'workouts': workouts.map((w) {
          return <String, dynamic>{
            'original_id':
                (w['uuid'] as String?) ??
                '${w['activityType']}_${w['startDate']}',
            'activity_type': (w['activityType'] as String?) ?? 'unknown',
            'duration_seconds': (w['duration'] as num?)?.round() ?? 0,
            'distance_meters': (w['totalDistance'] as num?)?.toDouble() ?? 0.0,
            'calories': (w['totalEnergyBurned'] as num?)?.round() ?? 0,
            'start_time': (w['startDate'] as String?) ?? now.toIso8601String(),
          };
        }).toList(),
        'sleep': _aggregateSleep(sleepSegments, todayStr),
        'nutrition': (nutritionCalories != null && nutritionCalories > 0)
            ? [
                {'date': todayStr, 'calories': nutritionCalories.round()},
              ]
            : <Map<String, dynamic>>[],
        'weight': (weight != null && weight > 0)
            ? [
                {'date': todayStr, 'weight_kg': weight},
              ]
            : <Map<String, dynamic>>[],
      };

      await _apiClient.post('/api/v1/health/ingest', data: payload);
      debugPrint(
        '[HealthSync] Sync complete: ${workouts.length} workouts, '
        '${steps.round()} steps',
      );
      // Analytics: track sync success (fire-and-forget).
      _analytics?.capture(
        event: AnalyticsEvents.healthSyncCompleted,
        properties: {
          'platform': platform,
          'record_count': workouts.length,
        },
      );
      SentryBreadcrumbs.healthSync(
        platform: platform,
        status: 'completed',
        recordCount: workouts.length,
      );
      return true;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      debugPrint('[HealthSync] Sync failed: $e\n$st');
      // Analytics: track sync failure (fire-and-forget).
      _analytics?.capture(
        event: AnalyticsEvents.healthSyncFailed,
        properties: {
          'platform': platform,
          'error_type': e.runtimeType.toString(),
        },
      );
      SentryBreadcrumbs.healthSync(
        platform: platform,
        status: 'failed',
      );
      return false;
    }
  }

  /// Aggregates sleep segments into a single nightly record.
  ///
  /// Each [segment] may use either `startDate`/`endDate` or
  /// `startTime`/`endTime` key names. Total hours are summed across
  /// all segments and capped to a single payload entry for [date].
  ///
  /// Returns:
  ///   An empty list if [segments] is empty or total duration is zero.
  List<Map<String, dynamic>> _aggregateSleep(
    List<Map<String, dynamic>> segments,
    String date,
  ) {
    if (segments.isEmpty) return [];
    double totalHours = 0;
    for (final seg in segments) {
      final startStr = (seg['startDate'] ?? seg['startTime']) as String?;
      final endStr = (seg['endDate'] ?? seg['endTime']) as String?;
      if (startStr != null && endStr != null) {
        final start = DateTime.tryParse(startStr);
        final end = DateTime.tryParse(endStr);
        if (start != null && end != null) {
          totalHours += end.difference(start).inMinutes / 60.0;
        }
      }
    }
    if (totalHours <= 0) return [];
    return [
      {'date': date, 'hours': double.parse(totalHours.toStringAsFixed(2))},
    ];
  }

  /// Formats a [DateTime] as an ISO date string (YYYY-MM-DD).
  String _isoDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
