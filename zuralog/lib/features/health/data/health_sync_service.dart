/// Service that reads local HealthKit/Health Connect data and pushes it
/// to the Cloud Brain's `/health/ingest` endpoint.
///
/// This is the core device-to-cloud pipeline. Called on:
/// - App launch (if Apple Health is connected)
/// - Pull-to-refresh on dashboard
/// - After connecting Apple Health in integrations hub
/// - Background sync triggers (via FCM or native observers)
library;

import 'package:flutter/foundation.dart';
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
  HealthSyncService({
    required HealthRepository healthRepository,
    required ApiClient apiClient,
  }) : _healthRepo = healthRepository,
       _apiClient = apiClient;

  final HealthRepository _healthRepo;
  final ApiClient _apiClient;

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
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final rangeStart = today.subtract(Duration(days: days));

      // Read scalar daily metrics for today (single-date API)
      final steps = await _healthRepo.getSteps(today);
      final activeCalories = await _healthRepo.getCaloriesBurned(today);
      final nutritionCalories = await _healthRepo.getNutritionCalories(today);

      // Read point-in-time values (most recent reading, no date arg)
      final weight = await _healthRepo.getWeight();
      final rhr = await _healthRepo.getRestingHeartRate();
      final hrv = await _healthRepo.getHRV();
      final vo2 = await _healthRepo.getCardioFitness();

      // Read date-range collections
      final workouts = await _healthRepo.getWorkouts(rangeStart, now);
      final sleepSegments = await _healthRepo.getSleep(rangeStart, now);

      final todayStr = _isoDate(today);

      final payload = <String, dynamic>{
        'source': 'apple_health',
        'daily_metrics': [
          {
            'date': todayStr,
            'steps': steps.round(),
            'active_calories': (activeCalories ?? 0.0).round(),
            if (rhr != null && rhr > 0) 'resting_heart_rate': rhr,
            if (hrv != null && hrv > 0) 'hrv_ms': hrv,
            if (vo2 != null && vo2 > 0) 'vo2_max': vo2,
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
      return true;
    } catch (e, st) {
      debugPrint('[HealthSync] Sync failed: $e\n$st');
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
