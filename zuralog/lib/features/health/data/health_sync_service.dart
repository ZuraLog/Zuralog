/// Service that reads local HealthKit/Health Connect data and pushes it
/// to the Cloud Brain's unified `/api/v1/ingest/bulk` endpoint.
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
import 'package:zuralog/core/utils/idempotency_key.dart';
import 'package:zuralog/features/health/data/health_repository.dart';

/// Reads all available HealthKit/Health Connect data and pushes it to the
/// Cloud Brain via the unified `POST /api/v1/ingest/bulk` endpoint.
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
  /// to the Cloud Brain bulk ingest endpoint.
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
      final nowStr = _isoDateTimeWithTz(now);

      // Use the correct source name for each platform so the Cloud Brain
      // DB and deduplication engine know the origin of the data.
      final source = Platform.isAndroid ? 'health_connect' : 'apple_health';

      // Build a flat list of bulk event payloads from all health data.
      final events = <Map<String, dynamic>>[];

      // ── Daily aggregate metrics ──────────────────────────────────────────
      void addDaily(String metricType, num? value, String unit) {
        if (value != null && value > 0) {
          events.add({
            'metric_type': metricType,
            'value': value.toDouble(),
            'unit': unit,
            'recorded_at': '${todayStr}T00:00:00${_localTzSuffix(now)}',
            'granularity': 'daily_aggregate',
            'idempotency_key': generateIdempotencyKey(),
          });
        }
      }

      addDaily('steps', steps.round(), 'steps');
      addDaily('active_calories', (activeCalories ?? 0.0).round(), 'kcal');
      addDaily('distance_meters', distance > 0 ? distance : null, 'm');
      addDaily('flights_climbed', flights > 0 ? flights.round() : null, 'flights');
      addDaily('water_liters', water, 'L');
      addDaily('mindful_minutes', mindfulMin, 'min');

      // ── Nutrition macros (daily aggregate) ────────────────────────────────
      if (nutritionCalories != null && nutritionCalories > 0) {
        addDaily('nutrition_calories', nutritionCalories.round(), 'kcal');
      }
      if (nutritionMacros != null) {
        addDaily('nutrition_protein_g', nutritionMacros['nutrition_protein_g'] as num?, 'g');
        addDaily('nutrition_carbs_g', nutritionMacros['nutrition_carbs_g'] as num?, 'g');
        addDaily('nutrition_fat_g', nutritionMacros['nutrition_fat_g'] as num?, 'g');
        addDaily('nutrition_fiber_g', nutritionMacros['nutrition_fiber_g'] as num?, 'g');
      }

      // ── Point-in-time metrics ─────────────────────────────────────────────
      void addPoint(String metricType, num? value, String unit) {
        if (value != null && value > 0) {
          events.add({
            'metric_type': metricType,
            'value': value.toDouble(),
            'unit': unit,
            'recorded_at': nowStr,
            'granularity': 'point_in_time',
            'idempotency_key': generateIdempotencyKey(),
          });
        }
      }

      addPoint('resting_heart_rate', rhr, 'bpm');
      addPoint('hrv_ms', hrv, 'ms');
      addPoint('vo2_max', vo2, 'mL/kg/min');
      addPoint('weight', weight, 'kg');
      addPoint('body_fat_percentage', bodyFat, '%');
      addPoint('respiratory_rate', respiratoryRate, 'breaths/min');
      addPoint('oxygen_saturation', oxygenSaturation, '%');
      addPoint('heart_rate_avg', heartRate, 'bpm');
      addPoint('body_temperature_celsius', bodyTemp, 'C');
      addPoint('walking_speed_mps', walkingSpeed, 'm/s');
      addPoint('running_pace_mps', runningPaceMps, 'm/s');

      // Wrist temperature deviation (can be negative, so check for null only)
      if (wristTemp != null) {
        events.add({
          'metric_type': 'wrist_temperature_deviation',
          'value': wristTemp.toDouble(),
          'unit': 'C',
          'recorded_at': nowStr,
          'granularity': 'point_in_time',
          'idempotency_key': generateIdempotencyKey(),
        });
      }

      // Blood pressure (two separate events)
      if (bp != null && bp['systolic'] != null) {
        addPoint('blood_pressure_systolic', bp['systolic'] as num?, 'mmHg');
      }
      if (bp != null && bp['diastolic'] != null) {
        addPoint('blood_pressure_diastolic', bp['diastolic'] as num?, 'mmHg');
      }

      // ── Sleep (daily aggregate from segment summation) ───────────────────
      final sleepHours = _aggregateSleepHours(sleepSegments);
      if (sleepHours > 0) {
        events.add({
          'metric_type': 'sleep_hours',
          'value': double.parse(sleepHours.toStringAsFixed(2)),
          'unit': 'hrs',
          'recorded_at': '${todayStr}T00:00:00${_localTzSuffix(now)}',
          'granularity': 'daily_aggregate',
          'idempotency_key': generateIdempotencyKey(),
        });
      }

      // ── Workouts (each as a point-in-time event) ─────────────────────────
      for (final w in workouts) {
        final startTime = (w['startDate'] as String?) ?? now.toIso8601String();
        final durationSec = (w['duration'] as num?)?.round() ?? 0;
        final distanceM = (w['totalDistance'] as num?)?.toDouble() ?? 0.0;
        final calories = (w['totalEnergyBurned'] as num?)?.round() ?? 0;
        final activityType = (w['activityType'] as String?) ?? 'unknown';

        // Duration as minutes is the primary value for workout events
        if (durationSec > 0) {
          events.add({
            'metric_type': 'workout_${activityType.toLowerCase()}',
            'value': durationSec / 60.0,
            'unit': 'min',
            'recorded_at': startTime,
            'granularity': 'point_in_time',
            'idempotency_key': generateIdempotencyKey(),
            'metadata': {
              'activity_type': activityType,
              'duration_seconds': durationSec,
              'distance_meters': distanceM,
              'calories': calories,
              'original_id': (w['uuid'] as String?) ??
                  '${activityType}_$startTime',
            },
          });
        }
      }

      // ── Cycle data ──────────────────────────────────────────────────────
      if (cycleData.isNotEmpty) {
        final lastCycle = cycleData.last;
        events.add({
          'metric_type': 'cycle_day',
          'value': cycleData.length.toDouble(),
          'unit': 'day',
          'recorded_at': '${todayStr}T00:00:00${_localTzSuffix(now)}',
          'granularity': 'daily_aggregate',
          'idempotency_key': generateIdempotencyKey(),
          'metadata': {
            'cycle_phase': lastCycle['cycle_phase'] ?? 'unknown',
            'cycle_flow_intensity': lastCycle['cycle_flow_intensity'] ?? 0,
          },
        });
      }

      // Only send if we have events to submit
      if (events.isEmpty) {
        debugPrint('[HealthSync] No health data to sync');
        return true;
      }

      await _apiClient.post('/api/v1/ingest/bulk', data: {
        'source': source,
        'events': events,
      });

      debugPrint(
        '[HealthSync] Sync complete: ${events.length} events '
        '(${workouts.length} workouts, ${steps.round()} steps)',
      );
      // Analytics: track sync success (fire-and-forget).
      _analytics?.capture(
        event: AnalyticsEvents.healthSyncCompleted,
        properties: {
          'platform': platform,
          'record_count': events.length,
        },
      );
      SentryBreadcrumbs.healthSync(
        platform: platform,
        status: 'completed',
        recordCount: events.length,
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

  /// Aggregates sleep segments into total hours.
  ///
  /// Each [segment] may use either `startDate`/`endDate` or
  /// `startTime`/`endTime` key names. Total hours are summed across
  /// all segments.
  ///
  /// Returns 0.0 if [segments] is empty or total duration is zero.
  double _aggregateSleepHours(List<Map<String, dynamic>> segments) {
    if (segments.isEmpty) return 0.0;
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
    return totalHours;
  }

  /// Formats a [DateTime] as an ISO date string (YYYY-MM-DD).
  String _isoDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  /// Formats a [DateTime] as an ISO 8601 datetime string with timezone offset.
  String _isoDateTimeWithTz(DateTime dt) {
    final local = dt.toLocal();
    final base = local.toIso8601String().split('.').first;
    return '$base${_localTzSuffix(dt)}';
  }

  /// Returns the local timezone offset suffix (e.g. "+05:00" or "-08:00").
  String _localTzSuffix(DateTime dt) {
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hh = offset.inHours.abs().toString().padLeft(2, '0');
    final mm = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '$sign$hh:$mm';
  }
}
