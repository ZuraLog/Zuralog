/// Zuralog — Mock Trends Repository.
///
/// Used in debug builds (`kDebugMode`) to serve realistic stub data
/// without requiring the backend to be running locally.
library;

import 'package:zuralog/features/trends/data/trends_repository.dart';
import 'package:zuralog/features/trends/domain/trends_models.dart';

// ── MockTrendsRepository ──────────────────────────────────────────────────────

/// Debug-only stub implementation of [TrendsRepositoryInterface].
///
/// All methods simulate a 300–600 ms network delay and return
/// realistic hardcoded data so every Trends screen renders correctly
/// without a live backend connection.
class MockTrendsRepository implements TrendsRepositoryInterface {
  const MockTrendsRepository();

  static const _minDelay = Duration(milliseconds: 300);
  static const _maxDelay = Duration(milliseconds: 600);

  /// Simulates realistic async latency.
  Future<void> _delay() => Future<void>.delayed(_minDelay +
      Duration(
        milliseconds:
            (_maxDelay.inMilliseconds - _minDelay.inMilliseconds) ~/ 2,
      ));

  // ── Trends Home ─────────────────────────────────────────────────────────────

  @override
  Future<TrendsHomeData> getTrendsHome() async {
    await _delay();
    final now = DateTime.now();
    return TrendsHomeData(
      patternCount: 5,
      hasEnoughData: true,
      timePeriods: const [],
      suggestionCards: const [],
      correlationHighlights: [
        CorrelationHighlight(
          id: 'pattern-sleep-hrv',
          metricA: 'Deep Sleep',
          metricB: 'Morning HRV',
          coefficient: 0.72,
          direction: CorrelationDirection.positive,
          headline: 'More deep sleep → higher morning HRV',
          body:
              'On nights with 90+ min of deep sleep, your morning HRV is consistently 15–20% higher.',
          category: 'sleep',
          discoveredAt:
              now.subtract(const Duration(days: 14)).toIso8601String(),
          categoryColorHex: '#CFE1B9',
        ),
        CorrelationHighlight(
          id: 'pattern-steps-energy',
          metricA: 'Daily Steps',
          metricB: 'Perceived Energy',
          coefficient: 0.61,
          direction: CorrelationDirection.positive,
          headline: '10k steps correlates with higher energy next day',
          body:
              'Days you hit 10,000+ steps, you report 30% higher energy the following morning.',
          category: 'activity',
          discoveredAt: now.subtract(const Duration(days: 3)).toIso8601String(),
          categoryColorHex: '#30D158',
        ),
        CorrelationHighlight(
          id: 'pattern-screen-sleep',
          metricA: 'Screen Time',
          metricB: 'Sleep Quality',
          coefficient: -0.58,
          direction: CorrelationDirection.negative,
          headline: 'Late screen time hurts sleep quality',
          body:
              'Each extra hour of screen time after 9pm is associated with 12% worse sleep quality scores.',
          category: 'wellness',
          discoveredAt: now.subtract(const Duration(days: 5)).toIso8601String(),
          categoryColorHex: '#FFD60A',
        ),
        CorrelationHighlight(
          id: 'pattern-running-hr',
          metricA: 'Running',
          metricB: 'Resting Heart Rate',
          coefficient: -0.49,
          direction: CorrelationDirection.negative,
          headline: 'Regular running lowers resting heart rate',
          body:
              'Weeks with 3+ runs correlate with a 4 bpm lower resting heart rate.',
          category: 'heart',
          discoveredAt:
              now.subtract(const Duration(days: 21)).toIso8601String(),
          categoryColorHex: '#FF375F',
        ),
        CorrelationHighlight(
          id: 'pattern-protein-recovery',
          metricA: 'Protein Intake',
          metricB: 'Recovery Score',
          coefficient: 0.44,
          direction: CorrelationDirection.positive,
          headline: 'Higher protein → better workout recovery',
          body:
              'On days with 120g+ protein, your next-day recovery score averages 18% higher.',
          category: 'nutrition',
          discoveredAt: now.subtract(const Duration(days: 1)).toIso8601String(),
          categoryColorHex: '#FF9F0A',
        ),
      ],
    );
  }

  // ── Pattern Expand ───────────────────────────────────────────────────────────

  @override
  Future<PatternExpandData> fetchPatternExpand(
    String patternId, {
    String timeRange = '30d',
  }) async {
    await _delay();
    return PatternExpandData(
      id: patternId,
      seriesALabel: 'Deep Sleep',
      seriesBLabel: 'Morning HRV',
      aiExplanation:
          'On nights when you get more than 90 minutes of deep sleep, your '
          'morning heart rate variability is consistently 15–20% higher. '
          'This pattern has held across the last 30 days of data.',
      dataSources: ['Apple Health', 'Fitbit'],
      dataDays: 30,
      timeRange: timeRange,
      seriesA: List.generate(
        7,
        (i) => ChartSeriesPoint(
          date: DateTime.now()
              .subtract(Duration(days: 6 - i))
              .toIso8601String()
              .substring(0, 10),
          value: 85.0 + (i * 2.5),
        ),
      ),
      seriesB: List.generate(
        7,
        (i) => ChartSeriesPoint(
          date: DateTime.now()
              .subtract(Duration(days: 6 - i))
              .toIso8601String()
              .substring(0, 10),
          value: 42.0 + (i * 1.8),
        ),
      ),
    );
  }

  // ── Cache Invalidation ────────────────────────────────────────────────────────

  @override
  void invalidateAll() {
    // No-op: mock has no cache state.
  }
}
