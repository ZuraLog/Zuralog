/// Zuralog Dashboard — Metric Data Repository.
///
/// Provides deterministic mock time-series data for every supported health
/// metric. No network calls are made; all data is generated in-memory using
/// [dart:math.Random] seeded with each metric's ID hash so that the same
/// metric always produces the same sequence across rebuilds.
///
/// This repository is the sole data source consumed by the Riverpod providers
/// in `presentation/providers/metric_series_provider.dart` during development
/// and testing.
library;

import 'dart:math' as math;

import 'package:zuralog/features/dashboard/domain/metric_data_point.dart';
import 'package:zuralog/features/dashboard/domain/metric_series.dart';
import 'package:zuralog/features/dashboard/domain/metric_stats.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';

// ── Internal helpers ──────────────────────────────────────────────────────────

/// Returns the number of data points to generate for a given [TimeRange].
///
/// - [TimeRange.day]       → 24 (hourly)
/// - [TimeRange.week]      → 7  (daily)
/// - [TimeRange.month]     → 30 (daily)
/// - [TimeRange.sixMonths] → 26 (weekly)
/// - [TimeRange.year]      → 52 (weekly)
int _pointCount(TimeRange range) => switch (range) {
      TimeRange.day => 24,
      TimeRange.week => 7,
      TimeRange.month => 30,
      TimeRange.sixMonths => 26,
      TimeRange.year => 52,
    };

/// Returns the [Duration] step between consecutive data points.
Duration _stepDuration(TimeRange range) => switch (range) {
      TimeRange.day => const Duration(hours: 1),
      TimeRange.week => const Duration(days: 1),
      TimeRange.month => const Duration(days: 1),
      TimeRange.sixMonths => const Duration(days: 7),
      TimeRange.year => const Duration(days: 7),
    };

/// Computes [MetricStats] from a list of [MetricDataPoint]s.
///
/// - [average] — arithmetic mean of [MetricDataPoint.value].
/// - [min] / [max] — extremes of [MetricDataPoint.value].
/// - [total] — sum of all [MetricDataPoint.value].
/// - [trendPercent] — percentage change: last 25 % vs first 25 % of points.
///
/// Returns zeroed stats when [points] is empty.
MetricStats _computeStats(List<MetricDataPoint> points) {
  if (points.isEmpty) {
    return const MetricStats(
      average: 0,
      min: 0,
      max: 0,
      total: 0,
      trendPercent: 0,
    );
  }

  final values = points.map((p) => p.value).toList();

  final double total = values.fold(0.0, (acc, v) => acc + v);
  final double average = total / values.length;
  final double min = values.reduce(math.min);
  final double max = values.reduce(math.max);

  // Trend: compare mean of last 25 % vs mean of first 25 %.
  final int quarter = (values.length / 4).ceil().clamp(1, values.length);
  final List<double> early = values.take(quarter).toList();
  final List<double> late = values.skip(values.length - quarter).toList();
  final double earlyMean = early.fold(0.0, (a, v) => a + v) / early.length;
  final double lateMean = late.fold(0.0, (a, v) => a + v) / late.length;
  final double trendPercent =
      earlyMean == 0 ? 0 : ((lateMean - earlyMean) / earlyMean) * 100;

  return MetricStats(
    average: average,
    min: min,
    max: max,
    total: total,
    trendPercent: trendPercent,
  );
}

// ── Repository ────────────────────────────────────────────────────────────────

/// Mock data repository for health metric time-series.
///
/// All data is generated deterministically from [metricId.hashCode] so that
/// repeated calls for the same metric always yield the same sequence, making
/// UI development stable and reproducible.
///
/// Usage:
/// ```dart
/// final repo = MetricDataRepository();
/// final series = await repo.getMetricSeries(metricId: 'steps', timeRange: TimeRange.week);
/// ```
class MetricDataRepository {
  /// Creates a [MetricDataRepository].
  const MetricDataRepository();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns mock [MetricSeries] data for [metricId] over [timeRange].
  ///
  /// Data is generated deterministically: the same [metricId] always produces
  /// the same sequence. Timestamps are anchored to [referenceDate] (or
  /// `DateTime.now()` when not supplied), so that tests can pass a fixed date
  /// and get stable, reproducible results across rebuilds.
  ///
  /// Parameters:
  /// - [metricId] — unique metric identifier (e.g. `'steps'`).
  /// - [timeRange] — the time window to generate data for.
  /// - [referenceDate] — optional anchor for the newest data point's timestamp.
  ///   Defaults to `DateTime.now()` when `null`.
  ///
  /// Returns a [MetricSeries] containing the generated [MetricDataPoint]s and
  /// pre-computed [MetricStats].
  Future<MetricSeries> getMetricSeries({
    required String metricId,
    required TimeRange timeRange,
    DateTime? referenceDate,
  }) async {
    // Simulated async latency — remove when wired to real data source.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final DateTime anchor = referenceDate ?? DateTime.now();
    final List<MetricDataPoint> points =
        _generatePoints(metricId, timeRange, anchor);
    final MetricStats stats = _computeStats(points);

    return MetricSeries(
      metricId: metricId,
      timeRange: timeRange,
      dataPoints: points,
      stats: stats,
    );
  }

  /// Returns today's snapshot values for each of the given [metricIds].
  ///
  /// Used by dashboard hub cards to display a compact preview value. The
  /// returned map has one entry per requested metric ID. The value is the
  /// most-recent single data point for that metric (i.e. today's reading).
  ///
  /// **Missing keys:** If a metric produces no data points (e.g. sparse
  /// calendar metrics on a day with no events), its key is absent from the
  /// result. Callers should guard with `result[id] ?? 0.0`.
  ///
  /// Parameters:
  /// - [metricIds] — list of metric identifiers to fetch snapshots for.
  ///
  /// Returns a [Map<String, double>] from metric ID to its latest value.
  /// Keys are omitted (not set to zero) when no data is available.
  Future<Map<String, double>> getTodaySnapshots(
    List<String> metricIds,
  ) async {
    // Simulated async latency — remove when wired to real data source.
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final DateTime anchor = DateTime.now();
    final Map<String, double> result = {};
    for (final id in metricIds) {
      final List<MetricDataPoint> points =
          _generatePoints(id, TimeRange.week, anchor);
      if (points.isNotEmpty) {
        result[id] = points.last.value;
      }
    }
    return result;
  }

  // ── Private generation logic ───────────────────────────────────────────────

  /// Generates mock [MetricDataPoint]s for [metricId] over [timeRange].
  ///
  /// Dispatches to a per-metric generator based on the metric ID string.
  /// Falls back to [_genericLine] for unrecognised IDs.
  ///
  /// [anchor] is the timestamp for the newest (last) data point. Passing a
  /// fixed value produces identical timestamps on every call, enabling stable
  /// widget tests and golden screenshots.
  List<MetricDataPoint> _generatePoints(
    String metricId,
    TimeRange timeRange,
    DateTime anchor,
  ) {
    final math.Random rng = math.Random(metricId.hashCode);
    final int count = _pointCount(timeRange);
    final Duration step = _stepDuration(timeRange);

    // Compute the start time so the last point lands exactly on [anchor].
    final DateTime start = anchor.subtract(step * (count - 1));

    /// Helper: timestamp for the i-th point.
    DateTime ts(int i) => start.add(step * i);

    return switch (metricId) {
      'steps' => _barSeries(
          rng: rng, count: count, ts: ts, lo: 4000, hi: 14000, integer: true),
      'active_calories_burned' => _barSeries(
          rng: rng, count: count, ts: ts, lo: 200, hi: 700),
      'total_calories_burned' => _barSeries(
          rng: rng, count: count, ts: ts, lo: 1800, hi: 2800),
      'distance' => _barSeries(
          rng: rng, count: count, ts: ts, lo: 2000, hi: 12000),
      'distance_cycling' =>
        _barSeries(rng: rng, count: count, ts: ts, lo: 0, hi: 80),
      'distance_swimming' =>
        _barSeries(rng: rng, count: count, ts: ts, lo: 0, hi: 3000),
      'weight' =>
        _driftLine(rng: rng, count: count, ts: ts, base: 75, drift: 1.5),
      'body_fat_percentage' =>
        _driftLine(rng: rng, count: count, ts: ts, base: 21, drift: 1.0),
      'heart_rate' => _rangeLine(
          rng: rng,
          count: count,
          ts: ts,
          centerLo: 60,
          centerHi: 90,
          minLo: 55,
          minHi: 70,
          maxLo: 90,
          maxHi: 130,
        ),
      'resting_heart_rate' =>
        _simpleLine(rng: rng, count: count, ts: ts, lo: 55, hi: 75),
      'heart_rate_variability' =>
        _simpleLine(rng: rng, count: count, ts: ts, lo: 25, hi: 80),
      'vo2_max' =>
        _driftLine(rng: rng, count: count, ts: ts, base: 45, drift: 0.5),
      'blood_pressure' => _bloodPressureSeries(
          rng: rng, count: count, ts: ts),
      'oxygen_saturation' =>
        _thresholdLine(rng: rng, count: count, ts: ts, lo: 95, hi: 100),
      'sleep_duration' => _sleepSeries(rng: rng, count: count, ts: ts),
      'sleep_stages' => _sleepSeries(rng: rng, count: count, ts: ts),
      'dietary_energy' =>
        _barSeries(rng: rng, count: count, ts: ts, lo: 1500, hi: 3000),
      'protein' =>
        _barSeries(rng: rng, count: count, ts: ts, lo: 80, hi: 180),
      'carbohydrates' =>
        _barSeries(rng: rng, count: count, ts: ts, lo: 150, hi: 350),
      'fat_total' =>
        _barSeries(rng: rng, count: count, ts: ts, lo: 50, hi: 100),
      'hydration' =>
        _barSeries(rng: rng, count: count, ts: ts, lo: 1500, hi: 3500),
      'height' => _singleValueSeries(ts: ts, value: 175.0),
      'state_of_mind' =>
        _moodSeries(rng: rng, count: count, ts: ts),
      'blood_glucose' =>
        _thresholdLine(rng: rng, count: count, ts: ts, lo: 70, hi: 140),
      'menstruation_flow' =>
        _calendarMarker(rng: rng, count: count, ts: ts, lo: 1, hi: 4),
      'exercise_sessions' =>
        _calendarHeatmap(rng: rng, count: count, ts: ts),
      _ => _genericLine(rng: rng, count: count, ts: ts),
    };
  }

  // ── Per-type generators ───────────────────────────────────────────────────

  /// Generates a bar-chart series (simple positive values, optionally integer).
  ///
  /// Parameters:
  /// - [lo] / [hi] — inclusive range for generated values.
  /// - [integer] — when true, rounds each value to the nearest integer.
  List<MetricDataPoint> _barSeries({
    required math.Random rng,
    required int count,
    required DateTime Function(int) ts,
    required double lo,
    required double hi,
    bool integer = false,
  }) {
    return List<MetricDataPoint>.generate(count, (i) {
      final double raw = lo + rng.nextDouble() * (hi - lo);
      final double value = integer ? raw.roundToDouble() : _round2(raw);
      return MetricDataPoint(timestamp: ts(i), value: value);
    });
  }

  /// Generates a smooth line series with a slow random drift.
  ///
  /// [base] is the central value; [drift] is the maximum total drift over the
  /// entire series length. Noise is added per point to simulate day-to-day
  /// variation.
  List<MetricDataPoint> _driftLine({
    required math.Random rng,
    required int count,
    required DateTime Function(int) ts,
    required double base,
    required double drift,
  }) {
    double current = base + (rng.nextDouble() - 0.5) * drift * 2;
    return List<MetricDataPoint>.generate(count, (i) {
      current += (rng.nextDouble() - 0.5) * (drift / count) * 4;
      return MetricDataPoint(timestamp: ts(i), value: _round2(current));
    });
  }

  /// Generates a simple random line within [lo]–[hi].
  List<MetricDataPoint> _simpleLine({
    required math.Random rng,
    required int count,
    required DateTime Function(int) ts,
    required double lo,
    required double hi,
  }) {
    return List<MetricDataPoint>.generate(count, (i) {
      final double value = lo + rng.nextDouble() * (hi - lo);
      return MetricDataPoint(timestamp: ts(i), value: _round2(value));
    });
  }

  /// Generates a range-line series with [min], center [value], and [max].
  ///
  /// Used for heart rate and similar metrics that record a min/max window.
  List<MetricDataPoint> _rangeLine({
    required math.Random rng,
    required int count,
    required DateTime Function(int) ts,
    required double centerLo,
    required double centerHi,
    required double minLo,
    required double minHi,
    required double maxLo,
    required double maxHi,
  }) {
    return List<MetricDataPoint>.generate(count, (i) {
      final double center =
          centerLo + rng.nextDouble() * (centerHi - centerLo);
      final double minVal = minLo + rng.nextDouble() * (minHi - minLo);
      final double maxVal = maxLo + rng.nextDouble() * (maxHi - maxLo);
      return MetricDataPoint(
        timestamp: ts(i),
        value: _round2(center),
        min: _round2(minVal),
        max: _round2(maxVal),
      );
    });
  }

  /// Generates a threshold-line series (values near an upper boundary).
  List<MetricDataPoint> _thresholdLine({
    required math.Random rng,
    required int count,
    required DateTime Function(int) ts,
    required double lo,
    required double hi,
  }) {
    return List<MetricDataPoint>.generate(count, (i) {
      final double value = lo + rng.nextDouble() * (hi - lo);
      return MetricDataPoint(timestamp: ts(i), value: _round2(value));
    });
  }

  /// Generates dual-line blood pressure data using [components].
  ///
  /// [value] is the systolic reading. [components] carries `'systolic'` and
  /// `'diastolic'` keys.
  List<MetricDataPoint> _bloodPressureSeries({
    required math.Random rng,
    required int count,
    required DateTime Function(int) ts,
  }) {
    return List<MetricDataPoint>.generate(count, (i) {
      final double systolic = 110 + rng.nextDouble() * 30;
      final double diastolic = 70 + rng.nextDouble() * 20;
      return MetricDataPoint(
        timestamp: ts(i),
        value: _round2(systolic),
        components: {
          'systolic': _round2(systolic),
          'diastolic': _round2(diastolic),
        },
      );
    });
  }

  /// Generates stacked-bar sleep data with stage breakdowns in [components].
  ///
  /// [value] is the total sleep hours. [components] holds `'awake'`, `'rem'`,
  /// `'core'`, and `'deep'` stage durations in hours.
  List<MetricDataPoint> _sleepSeries({
    required math.Random rng,
    required int count,
    required DateTime Function(int) ts,
  }) {
    return List<MetricDataPoint>.generate(count, (i) {
      final double awake = 0.3 + rng.nextDouble() * 0.5;
      final double rem = 1.2 + rng.nextDouble() * 0.8;
      final double core = 2.0 + rng.nextDouble() * 1.5;
      final double deep = 0.8 + rng.nextDouble() * 0.7;
      final double total = awake + rem + core + deep;
      return MetricDataPoint(
        timestamp: ts(i),
        value: _round2(total),
        components: {
          'awake': _round2(awake),
          'rem': _round2(rem),
          'core': _round2(core),
          'deep': _round2(deep),
        },
      );
    });
  }

  /// Generates a single-value series (e.g. height — one data point only).
  ///
  /// Always produces exactly one [MetricDataPoint] regardless of [count].
  List<MetricDataPoint> _singleValueSeries({
    required DateTime Function(int) ts,
    required double value,
  }) {
    return [MetricDataPoint(timestamp: ts(0), value: value)];
  }

  /// Generates a mood scatter series with integer values in 1–5.
  List<MetricDataPoint> _moodSeries({
    required math.Random rng,
    required int count,
    required DateTime Function(int) ts,
  }) {
    return List<MetricDataPoint>.generate(count, (i) {
      // Produces integer 1–5 inclusive (nextInt(5) → [0,4], +1 → [1,5]).
      final double value = (1 + rng.nextInt(5)).toDouble();
      return MetricDataPoint(timestamp: ts(i), value: value);
    });
  }

  /// Generates a calendar-marker series (e.g. menstruation flow), integer 1–[hi].
  List<MetricDataPoint> _calendarMarker({
    required math.Random rng,
    required int count,
    required DateTime Function(int) ts,
    required double lo,
    required double hi,
  }) {
    final List<MetricDataPoint> result = [];
    for (int i = 0; i < count; i++) {
      // Sparse — only generate a point ~40 % of the time.
      if (rng.nextDouble() > 0.4) continue;
      // nextInt(n) returns [0, n), so this gives [lo, hi] inclusive.
      final double value =
          (lo + rng.nextInt((hi - lo + 1).toInt())).toDouble();
      result.add(MetricDataPoint(timestamp: ts(i), value: value));
    }
    return result;
  }

  /// Generates a calendar-heatmap series (e.g. exercise sessions).
  ///
  /// Each point has a [value] of 0 (rest) or 1 (session) and [components]
  /// carrying an `'intensity'` value 0–100.
  List<MetricDataPoint> _calendarHeatmap({
    required math.Random rng,
    required int count,
    required DateTime Function(int) ts,
  }) {
    return List<MetricDataPoint>.generate(count, (i) {
      final bool hasSession = rng.nextDouble() > 0.5;
      final double value = hasSession ? 1.0 : 0.0;
      final double intensity = hasSession ? rng.nextDouble() * 100 : 0.0;
      return MetricDataPoint(
        timestamp: ts(i),
        value: value,
        components: {'intensity': _round2(intensity)},
      );
    });
  }

  /// Fallback generator for any metric not matched by the switch.
  ///
  /// Produces a generic line in the 10–100 range.
  List<MetricDataPoint> _genericLine({
    required math.Random rng,
    required int count,
    required DateTime Function(int) ts,
  }) {
    return _simpleLine(rng: rng, count: count, ts: ts, lo: 10, hi: 100);
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  /// Rounds a [double] to two decimal places.
  double _round2(double value) =>
      (value * 100).roundToDouble() / 100;
}
