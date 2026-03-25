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
    return const TrendsHomeData(
      hasEnoughData: true,
      correlationHighlights: [
        CorrelationHighlight(
          id: 'mock-corr-1',
          metricA: 'Sleep Duration',
          metricB: 'HRV',
          coefficient: 0.72,
          direction: CorrelationDirection.positive,
          headline: 'More sleep → higher HRV',
          body:
              'On nights you slept 8+ hours, your morning HRV was 18% higher on average over the past 30 days.',
          categoryColorHex: '#30D158',
        ),
        CorrelationHighlight(
          id: 'mock-corr-2',
          metricA: 'Daily Steps',
          metricB: 'Energy Level',
          coefficient: 0.61,
          direction: CorrelationDirection.positive,
          headline: 'Active days boost energy',
          body:
              'Days with 10,000+ steps consistently correlate with higher self-reported energy scores the following morning.',
          categoryColorHex: '#CFE1B9',
        ),
        CorrelationHighlight(
          id: 'mock-corr-3',
          metricA: 'Screen Time',
          metricB: 'Sleep Quality',
          coefficient: -0.58,
          direction: CorrelationDirection.negative,
          headline: 'Screen time hurts sleep quality',
          body:
              'Every extra 30 minutes of screen time after 9 PM is associated with a 0.4-point drop in next-day sleep quality score.',
          categoryColorHex: '#FF9F0A',
        ),
        CorrelationHighlight(
          id: 'mock-corr-4',
          metricA: 'Running Distance',
          metricB: 'Resting Heart Rate',
          coefficient: -0.49,
          direction: CorrelationDirection.negative,
          headline: 'Running lowers resting HR',
          body:
              'Weeks with 20+ km of running show a 3–5 bpm reduction in resting heart rate by the following Monday.',
          categoryColorHex: '#FF6B6B',
        ),
      ],
      suggestionCards: [
        CorrelationSuggestion(
          id: 'mock-sug-1',
          metricNeeded: 'Stress Level',
          description:
              'Track stress to unlock how it affects your sleep quality and HRV.',
          ctaLabel: 'Start Logging',
          ctaRoute: '/settings/integrations',
        ),
        CorrelationSuggestion(
          id: 'mock-sug-2',
          metricNeeded: 'Heart Rate Variability',
          description:
              'Connect a wearable to see how recovery correlates with training load.',
          ctaLabel: 'Connect App',
          ctaRoute: '/settings/integrations',
        ),
        CorrelationSuggestion(
          id: 'mock-sug-3',
          metricNeeded: 'Nutrition Calories',
          description:
              'Log meals to discover how caloric intake affects your energy and weight.',
          ctaLabel: 'Start Logging',
          ctaRoute: '/settings/integrations',
        ),
      ],
      timePeriods: [
        TimePeriodSummary(
          label: 'Feb 24 – Mar 1',
          periodStart: '2026-02-24',
          periodEnd: '2026-03-01',
          overallScore: 82,
          highlights: [
            MetricHighlight(
                label: 'Steps', value: '9,840', unit: 'steps', deltaPercent: 6.2),
            MetricHighlight(
                label: 'Sleep', value: '7.4', unit: 'hrs', deltaPercent: 2.1),
            MetricHighlight(
                label: 'HRV', value: '54', unit: 'ms', deltaPercent: 8.5),
          ],
        ),
        TimePeriodSummary(
          label: 'Feb 17 – Feb 23',
          periodStart: '2026-02-17',
          periodEnd: '2026-02-23',
          overallScore: 74,
          highlights: [
            MetricHighlight(
                label: 'Steps', value: '8,120', unit: 'steps', deltaPercent: -4.3),
            MetricHighlight(
                label: 'Sleep', value: '6.9', unit: 'hrs', deltaPercent: -5.8),
            MetricHighlight(
                label: 'HRV', value: '48', unit: 'ms', deltaPercent: -2.0),
          ],
        ),
        TimePeriodSummary(
          label: 'Feb 10 – Feb 16',
          periodStart: '2026-02-10',
          periodEnd: '2026-02-16',
          overallScore: 78,
          highlights: [
            MetricHighlight(
                label: 'Steps', value: '10,450', unit: 'steps', deltaPercent: 12.1),
            MetricHighlight(
                label: 'Sleep', value: '7.8', unit: 'hrs', deltaPercent: 4.0),
            MetricHighlight(
                label: 'HRV', value: '52', unit: 'ms', deltaPercent: 3.2),
          ],
        ),
        TimePeriodSummary(
          label: 'Feb 3 – Feb 9',
          periodStart: '2026-02-03',
          periodEnd: '2026-02-09',
          overallScore: 69,
          highlights: [
            MetricHighlight(
                label: 'Steps', value: '6,900', unit: 'steps', deltaPercent: -14.2),
            MetricHighlight(
                label: 'Sleep', value: '6.5', unit: 'hrs', deltaPercent: -8.1),
          ],
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
