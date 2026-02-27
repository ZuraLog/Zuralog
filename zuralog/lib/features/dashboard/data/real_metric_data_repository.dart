/// Zuralog Dashboard — Real Metric Data Repository.
///
/// Replaces [MetricDataRepository] with a live data layer that reads from
/// native health platforms (HealthKit / Health Connect) via [HealthRepository],
/// falls back to the Cloud Brain [AnalyticsRepository] when native data is
/// unavailable, and returns empty [MetricSeries] for metrics with no source.
///
/// The UI interprets empty series (zero data points) as "no data available"
/// and renders the greyed-out empty state with a "Connect a source" CTA.
library;

import 'dart:io' show Platform;

import 'package:zuralog/features/analytics/data/analytics_repository.dart';
import 'package:zuralog/features/dashboard/domain/health_metric.dart';
import 'package:zuralog/features/dashboard/domain/health_metric_registry.dart';
import 'package:zuralog/features/dashboard/domain/metric_data_point.dart';
import 'package:zuralog/features/dashboard/domain/metric_series.dart';
import 'package:zuralog/features/dashboard/domain/metric_stats.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';
import 'package:zuralog/features/health/data/health_repository.dart';

/// Real data repository for health metric time-series.
///
/// Data resolution strategy (per metric):
///   1. Read from native HealthKit / Health Connect via [HealthRepository].
///   2. If native returns null/empty, attempt Cloud Brain API fallback via
///      [AnalyticsRepository] for metrics that have server-side data.
///   3. If both fail, return an empty [MetricSeries] (zero data points).
///
/// The UI layer uses `series.dataPoints.isEmpty` to detect "no data" and
/// render the dimmed empty state.
class RealMetricDataRepository {
  /// Creates a [RealMetricDataRepository].
  ///
  /// [healthRepository] — native health platform access.
  /// [analyticsRepository] — Cloud Brain API access for fallback.
  const RealMetricDataRepository({
    required HealthRepository healthRepository,
    required AnalyticsRepository analyticsRepository,
  })  : _healthRepo = healthRepository,
        _analyticsRepo = analyticsRepository;

  final HealthRepository _healthRepo;
  final AnalyticsRepository _analyticsRepo;

  // ── Public API (same signature as MetricDataRepository) ──────────────────

  /// Returns real [MetricSeries] data for [metricId] over [timeRange].
  ///
  /// Attempts native health platform read first, then Cloud Brain API
  /// fallback. Returns empty series if no data is available from any source.
  ///
  /// Parameters:
  ///   [metricId]      — unique metric identifier from [HealthMetricRegistry].
  ///   [timeRange]     — time window for the data points.
  ///   [referenceDate] — anchor date (defaults to [DateTime.now]).
  ///
  /// Returns:
  ///   A [MetricSeries] with data points and stats. [dataPoints] is empty
  ///   when no data source is connected or the metric is unsupported.
  Future<MetricSeries> getMetricSeries({
    required String metricId,
    required TimeRange timeRange,
    DateTime? referenceDate,
  }) async {
    final DateTime anchor = referenceDate ?? DateTime.now();

    // Check if this metric is available on the current platform.
    final HealthMetric? metric = HealthMetricRegistry.byId(metricId);
    if (metric == null) return _emptySeries(metricId, timeRange);

    final bool platformAvailable = Platform.isIOS
        ? metric.isAvailableOnIOS
        : metric.isAvailableOnAndroid;

    if (!platformAvailable) return _emptySeries(metricId, timeRange);

    // Attempt native read (with 5-second timeout).
    final List<MetricDataPoint> nativePoints = await _readNativeWithTimeout(
      metricId: metricId,
      timeRange: timeRange,
      anchor: anchor,
    );

    if (nativePoints.isNotEmpty) {
      return MetricSeries(
        metricId: metricId,
        timeRange: timeRange,
        dataPoints: nativePoints,
        stats: _computeStats(nativePoints),
      );
    }

    // Fallback: attempt Cloud Brain API read for supported metrics.
    final List<MetricDataPoint> cloudPoints = await _readCloud(
      metricId: metricId,
      timeRange: timeRange,
      anchor: anchor,
    );

    if (cloudPoints.isNotEmpty) {
      return MetricSeries(
        metricId: metricId,
        timeRange: timeRange,
        dataPoints: cloudPoints,
        stats: _computeStats(cloudPoints),
      );
    }

    // No data from any source.
    return _emptySeries(metricId, timeRange);
  }

  /// Returns today's snapshot values for each of the given [metricIds].
  ///
  /// For each metric, attempts a native read of today's value. Returns a
  /// map with entries only for metrics that have real data. Missing keys
  /// indicate "no data" — the UI should render those as dimmed/greyed.
  ///
  /// Parameters:
  ///   [metricIds] — list of metric IDs to snapshot.
  ///
  /// Returns:
  ///   Map from metric ID to its current value. Missing keys = no data.
  Future<Map<String, double>> getTodaySnapshots(
    List<String> metricIds,
  ) async {
    final Map<String, double> result = {};
    final DateTime today = DateTime.now();

    // Fan out all reads in parallel for performance.
    final futures = metricIds.map((id) async {
      final double? value = await _readSingleNativeValue(id, today);
      if (value != null && value > 0) {
        result[id] = value;
      }
    });

    await Future.wait(futures);
    return result;
  }

  // ── Private: Native reads (with timeout) ─────────────────────────────────

  /// Reads time-series data points from the native health platform with a
  /// 5-second timeout guard to prevent UI hangs if the bridge becomes
  /// unresponsive.
  ///
  /// Parameters:
  ///   [metricId]  — the metric to read.
  ///   [timeRange] — the time window.
  ///   [anchor]    — end date for the time window.
  ///
  /// Returns:
  ///   List of data points, or empty list on timeout or any error.
  Future<List<MetricDataPoint>> _readNativeWithTimeout({
    required String metricId,
    required TimeRange timeRange,
    required DateTime anchor,
  }) async {
    try {
      return await Future.any([
        _readNative(metricId: metricId, timeRange: timeRange, anchor: anchor),
        Future.delayed(
          const Duration(seconds: 5),
          () => <MetricDataPoint>[],
        ),
      ]);
    } catch (_) {
      return <MetricDataPoint>[];
    }
  }

  /// Reads time-series data points from the native health platform.
  ///
  /// Dispatches to the appropriate [HealthRepository] method based on
  /// [metricId]. Returns an empty list for metrics not yet supported
  /// by the native bridge.
  ///
  /// Parameters:
  ///   [metricId]  — the metric to read.
  ///   [timeRange] — the time window.
  ///   [anchor]    — end date anchor (inclusive).
  ///
  /// Returns:
  ///   List of [MetricDataPoint]s, or empty list if unsupported or on error.
  Future<List<MetricDataPoint>> _readNative({
    required String metricId,
    required TimeRange timeRange,
    required DateTime anchor,
  }) async {
    try {
      final Duration window = Duration(days: timeRange.days);
      final DateTime start = anchor.subtract(window);

      return switch (metricId) {
        'steps' => await _readDailySteps(start, anchor),
        'active_calories_burned' =>
          await _readDailyCaloriesBurned(start, anchor),
        'total_calories_burned' =>
          await _readDailyCaloriesBurned(start, anchor),
        'weight' => await _readWeight(),
        'body_fat_percentage' => await _readBodyFat(),
        'resting_heart_rate' => await _readRestingHeartRate(),
        'heart_rate_variability' => await _readHRV(),
        'heart_rate' => await _readHeartRate(),
        'vo2_max' => await _readCardioFitness(),
        'sleep_duration' => await _readSleepDuration(start, anchor),
        'oxygen_saturation' => await _readOxygenSaturation(),
        'blood_pressure' => await _readBloodPressure(),
        'respiratory_rate' => await _readRespiratoryRate(),
        'distance' => await _readDistance(start, anchor),
        'flights_climbed' => await _readFlightsClimbed(start, anchor),
        'dietary_energy' => await _readDietaryEnergy(start, anchor),
        _ => <MetricDataPoint>[], // Not yet supported by native bridge.
      };
    } catch (_) {
      return <MetricDataPoint>[];
    }
  }

  /// Reads a single today-value for a metric from the native health platform.
  ///
  /// Used by [getTodaySnapshots] for the compact preview cards.
  ///
  /// Parameters:
  ///   [metricId] — the metric to read.
  ///   [date]     — the date to read for (typically today).
  ///
  /// Returns:
  ///   The current value, or `null` if the metric is unsupported or has
  ///   no data available.
  Future<double?> _readSingleNativeValue(String metricId, DateTime date) async {
    try {
      return switch (metricId) {
        'steps' => await _healthRepo.getSteps(date),
        'active_calories_burned' => await _healthRepo.getCaloriesBurned(date),
        'total_calories_burned' => await _healthRepo.getCaloriesBurned(date),
        'weight' => await _healthRepo.getWeight(),
        'body_fat_percentage' => await _healthRepo.getBodyFat(),
        'resting_heart_rate' => await _healthRepo.getRestingHeartRate(),
        'heart_rate_variability' => await _healthRepo.getHRV(),
        'heart_rate' => await _healthRepo.getHeartRate(),
        'vo2_max' => await _healthRepo.getCardioFitness(),
        'oxygen_saturation' => await _healthRepo.getOxygenSaturation(),
        'respiratory_rate' => await _healthRepo.getRespiratoryRate(),
        'distance' => await _healthRepo.getDistance(date),
        'flights_climbed' => await _healthRepo.getFlights(date),
        'dietary_energy' => await _healthRepo.getNutritionCalories(date),
        'sleep_duration' => await _readTodaySleepHours(date),
        _ => null, // Not yet supported.
      };
    } catch (_) {
      return null;
    }
  }

  // ── Private: Per-metric native bridge helpers ────────────────────────────
  // Each helper reads raw data from HealthRepository and converts it into
  // a List<MetricDataPoint> suitable for the graph widgets.
  //
  // IMPORTANT: These are scaffolded for the metrics currently supported
  // by HealthBridge. As new bridge methods are added, add a case to the
  // switch in _readNative and implement the corresponding helper here.

  /// Reads daily step counts from [start] to [end] (exclusive).
  ///
  /// Returns:
  ///   One data point per day that has non-zero step data.
  Future<List<MetricDataPoint>> _readDailySteps(
    DateTime start,
    DateTime end,
  ) async {
    final List<MetricDataPoint> points = [];
    for (
      var date = start;
      date.isBefore(end);
      date = date.add(const Duration(days: 1))
    ) {
      final double steps = await _healthRepo.getSteps(date);
      if (steps > 0) {
        points.add(MetricDataPoint(timestamp: date, value: steps));
      }
    }
    return points;
  }

  /// Reads daily active calories burned from [start] to [end] (exclusive).
  ///
  /// Returns:
  ///   One data point per day with non-zero calorie data.
  Future<List<MetricDataPoint>> _readDailyCaloriesBurned(
    DateTime start,
    DateTime end,
  ) async {
    final List<MetricDataPoint> points = [];
    for (
      var date = start;
      date.isBefore(end);
      date = date.add(const Duration(days: 1))
    ) {
      final double? cals = await _healthRepo.getCaloriesBurned(date);
      if (cals != null && cals > 0) {
        points.add(MetricDataPoint(timestamp: date, value: cals));
      }
    }
    return points;
  }

  /// Reads the most recent weight measurement as a single data point.
  ///
  /// Returns:
  ///   A list with one data point at [DateTime.now], or empty if unavailable.
  Future<List<MetricDataPoint>> _readWeight() async {
    final double? weight = await _healthRepo.getWeight();
    if (weight == null || weight <= 0) return [];
    return [MetricDataPoint(timestamp: DateTime.now(), value: weight)];
  }

  /// Reads the most recent body fat percentage.
  ///
  /// Returns:
  ///   A list with one data point at [DateTime.now], or empty if unavailable.
  Future<List<MetricDataPoint>> _readBodyFat() async {
    final double? bf = await _healthRepo.getBodyFat();
    if (bf == null || bf <= 0) return [];
    return [MetricDataPoint(timestamp: DateTime.now(), value: bf)];
  }

  /// Reads the most recent resting heart rate.
  ///
  /// Returns:
  ///   A list with one data point at [DateTime.now], or empty if unavailable.
  Future<List<MetricDataPoint>> _readRestingHeartRate() async {
    final double? rhr = await _healthRepo.getRestingHeartRate();
    if (rhr == null || rhr <= 0) return [];
    return [MetricDataPoint(timestamp: DateTime.now(), value: rhr)];
  }

  /// Reads the most recent heart rate variability.
  ///
  /// Returns:
  ///   A list with one data point at [DateTime.now], or empty if unavailable.
  Future<List<MetricDataPoint>> _readHRV() async {
    final double? hrv = await _healthRepo.getHRV();
    if (hrv == null || hrv <= 0) return [];
    return [MetricDataPoint(timestamp: DateTime.now(), value: hrv)];
  }

  /// Reads the most recent instantaneous heart rate.
  ///
  /// Note: [HealthRepository.getHeartRate] returns a single most-recent
  /// reading, not a range. For time-series use, a single point is returned.
  ///
  /// Returns:
  ///   A list with one data point at [DateTime.now], or empty if unavailable.
  Future<List<MetricDataPoint>> _readHeartRate() async {
    final double? hr = await _healthRepo.getHeartRate();
    if (hr == null || hr <= 0) return [];
    return [MetricDataPoint(timestamp: DateTime.now(), value: hr)];
  }

  /// Reads the most recent VO2 max / cardio fitness value.
  ///
  /// Returns:
  ///   A list with one data point at [DateTime.now], or empty if unavailable.
  Future<List<MetricDataPoint>> _readCardioFitness() async {
    final double? vo2 = await _healthRepo.getCardioFitness();
    if (vo2 == null || vo2 <= 0) return [];
    return [MetricDataPoint(timestamp: DateTime.now(), value: vo2)];
  }

  /// Reads sleep duration for each night in the date range.
  ///
  /// Groups sleep segments by the night they started and sums the total
  /// hours, producing one data point per night.
  ///
  /// Parameters:
  ///   [start] — start of the time window.
  ///   [end]   — end of the time window.
  ///
  /// Returns:
  ///   Chronologically sorted data points, one per night with data.
  Future<List<MetricDataPoint>> _readSleepDuration(
    DateTime start,
    DateTime end,
  ) async {
    final List<Map<String, dynamic>> segments =
        await _healthRepo.getSleep(start, end);
    if (segments.isEmpty) return [];

    // Group segments by night (date key) and sum hours.
    final Map<String, double> dailySleep = {};
    for (final Map<String, dynamic> seg in segments) {
      final num startMs =
          (seg['startDate'] ?? seg['startTime'] ?? 0) as num;
      final num endMs = (seg['endDate'] ?? seg['endTime'] ?? 0) as num;
      if (endMs <= startMs) continue;
      final double hours =
          (endMs.toDouble() - startMs.toDouble()) / (1000 * 60 * 60);
      final String dayKey = DateTime.fromMillisecondsSinceEpoch(startMs.toInt())
          .toIso8601String()
          .substring(0, 10);
      dailySleep[dayKey] = (dailySleep[dayKey] ?? 0) + hours;
    }

    return dailySleep.entries.map((MapEntry<String, double> e) {
      final DateTime date = DateTime.parse(e.key);
      return MetricDataPoint(
        timestamp: date,
        value: double.parse(e.value.clamp(0.0, 24.0).toStringAsFixed(1)),
      );
    }).toList()
      ..sort((MetricDataPoint a, MetricDataPoint b) =>
          a.timestamp.compareTo(b.timestamp));
  }

  /// Reads today's total sleep hours for the compact snapshot view.
  ///
  /// Looks at the 18-hour window ending at noon of [date] to capture last
  /// night's sleep.
  ///
  /// Parameters:
  ///   [date] — the date whose overnight sleep is being queried.
  ///
  /// Returns:
  ///   Total sleep hours as a [double], or `null` if no sleep data exists.
  Future<double?> _readTodaySleepHours(DateTime date) async {
    final DateTime start = date.subtract(const Duration(hours: 18));
    final DateTime end = date.copyWith(hour: 12, minute: 0, second: 0);
    final List<Map<String, dynamic>> segments =
        await _healthRepo.getSleep(start, end);
    if (segments.isEmpty) return null;

    double totalMs = 0.0;
    for (final Map<String, dynamic> seg in segments) {
      final num s = (seg['startDate'] ?? seg['startTime'] ?? 0) as num;
      final num e = (seg['endDate'] ?? seg['endTime'] ?? 0) as num;
      if (e > s) totalMs += e.toDouble() - s.toDouble();
    }
    final double hours = totalMs / (1000 * 60 * 60);
    return hours > 0
        ? double.parse(hours.clamp(0.0, 24.0).toStringAsFixed(1))
        : null;
  }

  /// Reads the most recent oxygen saturation value.
  ///
  /// Returns:
  ///   A list with one data point at [DateTime.now], or empty if unavailable.
  Future<List<MetricDataPoint>> _readOxygenSaturation() async {
    final double? spo2 = await _healthRepo.getOxygenSaturation();
    if (spo2 == null || spo2 <= 0) return [];
    return [MetricDataPoint(timestamp: DateTime.now(), value: spo2)];
  }

  /// Reads the most recent blood pressure reading.
  ///
  /// Note: [HealthRepository.getBloodPressure] returns a single most-recent
  /// reading as a [Map] with `systolic`, `diastolic`, and `date` keys.
  /// A single data point is returned using systolic as the primary value.
  ///
  /// Returns:
  ///   A list with one data point, or empty if no data is available.
  Future<List<MetricDataPoint>> _readBloodPressure() async {
    final Map<String, dynamic>? bp = await _healthRepo.getBloodPressure();
    if (bp == null) return [];

    final num systolic = (bp['systolic'] ?? 0) as num;
    final num diastolic = (bp['diastolic'] ?? 0) as num;
    final num dateMs = (bp['date'] ?? 0) as num;
    if (systolic <= 0) return [];

    final DateTime ts = dateMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(dateMs.toInt())
        : DateTime.now();

    return [
      MetricDataPoint(
        timestamp: ts,
        value: systolic.toDouble(),
        components: {
          'systolic': systolic.toDouble(),
          'diastolic': diastolic.toDouble(),
        },
      ),
    ];
  }

  /// Reads the most recent respiratory rate.
  ///
  /// Returns:
  ///   A list with one data point at [DateTime.now], or empty if unavailable.
  Future<List<MetricDataPoint>> _readRespiratoryRate() async {
    final double? rr = await _healthRepo.getRespiratoryRate();
    if (rr == null || rr <= 0) return [];
    return [MetricDataPoint(timestamp: DateTime.now(), value: rr)];
  }

  /// Reads daily walking + running distance from [start] to [end] (exclusive).
  ///
  /// Returns:
  ///   One data point per day with non-zero distance.
  Future<List<MetricDataPoint>> _readDistance(
    DateTime start,
    DateTime end,
  ) async {
    final List<MetricDataPoint> points = [];
    for (
      var date = start;
      date.isBefore(end);
      date = date.add(const Duration(days: 1))
    ) {
      // getDistance returns double (non-nullable), 0.0 when no data.
      final double dist = await _healthRepo.getDistance(date);
      if (dist > 0) {
        points.add(MetricDataPoint(timestamp: date, value: dist));
      }
    }
    return points;
  }

  /// Reads daily flights of stairs climbed from [start] to [end] (exclusive).
  ///
  /// Note: The correct [HealthRepository] method is [getFlights], not
  /// `getFlightsClimbed`.
  ///
  /// Returns:
  ///   One data point per day with non-zero flight data.
  Future<List<MetricDataPoint>> _readFlightsClimbed(
    DateTime start,
    DateTime end,
  ) async {
    final List<MetricDataPoint> points = [];
    for (
      var date = start;
      date.isBefore(end);
      date = date.add(const Duration(days: 1))
    ) {
      // getFlights returns double (non-nullable), 0.0 when no data.
      final double flights = await _healthRepo.getFlights(date);
      if (flights > 0) {
        points.add(MetricDataPoint(timestamp: date, value: flights));
      }
    }
    return points;
  }

  /// Reads daily dietary energy (calories consumed) from [start] to [end].
  ///
  /// Returns:
  ///   One data point per day with non-zero calorie data.
  Future<List<MetricDataPoint>> _readDietaryEnergy(
    DateTime start,
    DateTime end,
  ) async {
    final List<MetricDataPoint> points = [];
    for (
      var date = start;
      date.isBefore(end);
      date = date.add(const Duration(days: 1))
    ) {
      final double? cals = await _healthRepo.getNutritionCalories(date);
      if (cals != null && cals > 0) {
        points.add(MetricDataPoint(timestamp: date, value: cals));
      }
    }
    return points;
  }

  // ── Private: Cloud Brain API fallback ────────────────────────────────────

  /// Attempts to read time-series data from the Cloud Brain API.
  ///
  /// Only a subset of metrics are available via the API (those included in
  /// [DailySummary] and [WeeklyTrends]). Returns empty list for unsupported
  /// metrics or when the API is unreachable.
  ///
  /// Parameters:
  ///   [metricId]  — the metric to read.
  ///   [timeRange] — the time window.
  ///   [anchor]    — the reference date.
  ///
  /// Returns:
  ///   Data points from the Cloud Brain API, or empty list on failure.
  Future<List<MetricDataPoint>> _readCloud({
    required String metricId,
    required TimeRange timeRange,
    required DateTime anchor,
  }) async {
    try {
      // For weekly trends, the Cloud Brain API provides 7-day data for
      // a fixed set of metrics: steps, caloriesIn, caloriesOut, sleepHours.
      if (timeRange == TimeRange.week) {
        final trends = await _analyticsRepo.getWeeklyTrends();
        return switch (metricId) {
          'steps' => _weeklyTrendsToPoints(
              trends.dates,
              trends.steps.map((int e) => e.toDouble()).toList(),
            ),
          'active_calories_burned' => _weeklyTrendsToPoints(
              trends.dates,
              trends.caloriesOut.map((int e) => e.toDouble()).toList(),
            ),
          'total_calories_burned' => _weeklyTrendsToPoints(
              trends.dates,
              trends.caloriesOut.map((int e) => e.toDouble()).toList(),
            ),
          'dietary_energy' => _weeklyTrendsToPoints(
              trends.dates,
              trends.caloriesIn.map((int e) => e.toDouble()).toList(),
            ),
          'sleep_duration' => _weeklyTrendsToPoints(
              trends.dates,
              trends.sleepHours,
            ),
          _ => <MetricDataPoint>[],
        };
      }

      // For today, use the daily summary.
      if (timeRange == TimeRange.day) {
        final summary = await _analyticsRepo.getDailySummary(anchor);
        final double? value = switch (metricId) {
          'steps' => summary.steps.toDouble(),
          'active_calories_burned' => summary.caloriesBurned.toDouble(),
          'total_calories_burned' => summary.caloriesBurned.toDouble(),
          'dietary_energy' => summary.caloriesConsumed.toDouble(),
          'sleep_duration' => summary.sleepHours,
          'resting_heart_rate' => summary.restingHeartRate?.toDouble(),
          'heart_rate_variability' => summary.hrv,
          'vo2_max' => summary.cardioFitnessLevel,
          'weight' => summary.weightKg,
          _ => null,
        };
        if (value != null && value > 0) {
          return [MetricDataPoint(timestamp: anchor, value: value)];
        }
      }
    } catch (_) {
      // Cloud Brain unavailable — fall through to empty.
    }
    return <MetricDataPoint>[];
  }

  /// Converts parallel date/value lists from [WeeklyTrends] into data points.
  ///
  /// Parameters:
  ///   [dates]  — list of ISO-8601 date strings (`YYYY-MM-DD`).
  ///   [values] — corresponding metric values.
  ///
  /// Returns:
  ///   Data points for days where the value is positive (non-zero).
  List<MetricDataPoint> _weeklyTrendsToPoints(
    List<String> dates,
    List<double> values,
  ) {
    final List<MetricDataPoint> points = [];
    for (int i = 0; i < dates.length && i < values.length; i++) {
      if (values[i] > 0) {
        points.add(
          MetricDataPoint(
            timestamp: DateTime.parse(dates[i]),
            value: values[i],
          ),
        );
      }
    }
    return points;
  }

  // ── Private: Utilities ───────────────────────────────────────────────────

  /// Returns an empty [MetricSeries] indicating no data is available.
  ///
  /// All stats are zeroed. The UI interprets [dataPoints.isEmpty] as the
  /// "no data" state and renders the dimmed empty state.
  MetricSeries _emptySeries(String metricId, TimeRange timeRange) =>
      MetricSeries(
        metricId: metricId,
        timeRange: timeRange,
        dataPoints: const [],
        stats: const MetricStats(
          average: 0,
          min: 0,
          max: 0,
          total: 0,
          trendPercent: 0,
        ),
      );

  /// Computes [MetricStats] from a list of [MetricDataPoint]s.
  ///
  /// Calculates average, min, max, total, and a simple quarter-based
  /// trend percentage (comparing the first vs. last quarter of data).
  ///
  /// Parameters:
  ///   [points] — the data points to aggregate (must be non-empty).
  ///
  /// Returns:
  ///   Pre-computed [MetricStats] for the given data points.
  static MetricStats _computeStats(List<MetricDataPoint> points) {
    if (points.isEmpty) {
      return const MetricStats(
        average: 0,
        min: 0,
        max: 0,
        total: 0,
        trendPercent: 0,
      );
    }
    final List<double> values = points.map((MetricDataPoint p) => p.value).toList();
    final double total = values.fold(0.0, (double acc, double v) => acc + v);
    final double average = total / values.length;
    final double minVal = values.reduce((double a, double b) => a < b ? a : b);
    final double maxVal = values.reduce((double a, double b) => a > b ? a : b);

    final int quarter = (values.length / 4).ceil().clamp(1, values.length);
    final List<double> early = values.take(quarter).toList();
    final List<double> late_ = values.skip(values.length - quarter).toList();
    final double earlyMean =
        early.fold(0.0, (double a, double v) => a + v) / early.length;
    final double lateMean =
        late_.fold(0.0, (double a, double v) => a + v) / late_.length;
    final double trendPercent = earlyMean == 0
        ? 0.0
        : ((lateMean - earlyMean) / earlyMean) * 100;

    return MetricStats(
      average: _round2(average),
      min: _round2(minVal),
      max: _round2(maxVal),
      total: _round2(total),
      trendPercent: _round2(trendPercent),
    );
  }

  /// Rounds [value] to 2 decimal places.
  static double _round2(double value) => (value * 100).roundToDouble() / 100;
}
