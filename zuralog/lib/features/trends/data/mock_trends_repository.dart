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
      suggestionCards: const [
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

  // ── Available Metrics ────────────────────────────────────────────────────────

  @override
  Future<AvailableMetricList> getAvailableMetrics() async {
    await _delay();
    return const AvailableMetricList(
      metrics: [
        AvailableMetric(
            id: 'steps', label: 'Daily Steps', category: 'activity', unit: 'steps'),
        AvailableMetric(
            id: 'active_energy',
            label: 'Active Energy',
            category: 'activity',
            unit: 'kcal'),
        AvailableMetric(
            id: 'running_distance',
            label: 'Running Distance',
            category: 'activity',
            unit: 'km'),
        AvailableMetric(
            id: 'sleep_duration',
            label: 'Sleep Duration',
            category: 'sleep',
            unit: 'hrs'),
        AvailableMetric(
            id: 'sleep_quality',
            label: 'Sleep Quality',
            category: 'sleep',
            unit: 'score'),
        AvailableMetric(
            id: 'deep_sleep',
            label: 'Deep Sleep',
            category: 'sleep',
            unit: 'hrs'),
        AvailableMetric(
            id: 'hrv', label: 'HRV', category: 'heart', unit: 'ms'),
        AvailableMetric(
            id: 'resting_hr',
            label: 'Resting Heart Rate',
            category: 'heart',
            unit: 'bpm'),
        AvailableMetric(
            id: 'screen_time',
            label: 'Screen Time',
            category: 'wellness',
            unit: 'hrs'),
        AvailableMetric(
            id: 'energy_level',
            label: 'Energy Level',
            category: 'wellness',
            unit: 'score'),
        AvailableMetric(
            id: 'stress_score',
            label: 'Stress Score',
            category: 'wellness',
            unit: 'score'),
      ],
    );
  }

  // ── Correlation Analysis ─────────────────────────────────────────────────────

  @override
  Future<CorrelationAnalysis> getCorrelationAnalysis({
    required String metricAId,
    required String metricBId,
    required int lagDays,
    required CorrelationTimeRange timeRange,
  }) async {
    await _delay();

    // Generate mock scatter points for a convincing plot
    const points = [
      ScatterPoint(x: 6.5, y: 44.0, date: '2026-01-05'),
      ScatterPoint(x: 7.0, y: 48.0, date: '2026-01-06'),
      ScatterPoint(x: 7.5, y: 52.0, date: '2026-01-07'),
      ScatterPoint(x: 8.0, y: 56.0, date: '2026-01-08'),
      ScatterPoint(x: 6.0, y: 42.0, date: '2026-01-09'),
      ScatterPoint(x: 8.5, y: 60.0, date: '2026-01-10'),
      ScatterPoint(x: 7.2, y: 50.0, date: '2026-01-11'),
      ScatterPoint(x: 7.8, y: 55.0, date: '2026-01-12'),
      ScatterPoint(x: 5.5, y: 38.0, date: '2026-01-13'),
      ScatterPoint(x: 9.0, y: 65.0, date: '2026-01-14'),
    ];

    return CorrelationAnalysis(
      metricA: AvailableMetric(
        id: metricAId,
        label: _labelForMetric(metricAId),
        category: _categoryForMetric(metricAId),
        unit: _unitForMetric(metricAId),
      ),
      metricB: AvailableMetric(
        id: metricBId,
        label: _labelForMetric(metricBId),
        category: _categoryForMetric(metricBId),
        unit: _unitForMetric(metricBId),
      ),
      coefficient: 0.72,
      interpretation: 'Strong positive correlation',
      aiAnnotation:
          'There is a strong positive relationship between ${_labelForMetric(metricAId)} '
          'and ${_labelForMetric(metricBId)}. Based on ${timeRange.label} of data'
          '${lagDays > 0 ? ' with a +${lagDays}d lag' : ''}, '
          'increasing ${_labelForMetric(metricAId)} is consistently associated with '
          'higher ${_labelForMetric(metricBId)} values.',
      scatterPoints: points,
      lagDays: lagDays,
      timeRange: timeRange,
    );
  }

  String _labelForMetric(String id) {
    const labels = {
      'steps': 'Daily Steps',
      'active_energy': 'Active Energy',
      'running_distance': 'Running Distance',
      'sleep_duration': 'Sleep Duration',
      'sleep_quality': 'Sleep Quality',
      'deep_sleep': 'Deep Sleep',
      'hrv': 'HRV',
      'resting_hr': 'Resting Heart Rate',
      'screen_time': 'Screen Time',
      'energy_level': 'Energy Level',
      'stress_score': 'Stress Score',
    };
    return labels[id] ?? id;
  }

  String _categoryForMetric(String id) {
    const categories = {
      'steps': 'activity',
      'active_energy': 'activity',
      'running_distance': 'activity',
      'sleep_duration': 'sleep',
      'sleep_quality': 'sleep',
      'deep_sleep': 'sleep',
      'hrv': 'heart',
      'resting_hr': 'heart',
      'screen_time': 'wellness',
      'energy_level': 'wellness',
      'stress_score': 'wellness',
    };
    return categories[id] ?? 'other';
  }

  String _unitForMetric(String id) {
    const units = {
      'steps': 'steps',
      'active_energy': 'kcal',
      'running_distance': 'km',
      'sleep_duration': 'hrs',
      'sleep_quality': 'score',
      'deep_sleep': 'hrs',
      'hrv': 'ms',
      'resting_hr': 'bpm',
      'screen_time': 'hrs',
      'energy_level': 'score',
      'stress_score': 'score',
    };
    return units[id] ?? '';
  }

  // ── Reports ──────────────────────────────────────────────────────────────────

  @override
  Future<ReportList> getReports({int page = 1}) async {
    await _delay();
    if (page > 1) {
      return const ReportList(reports: [], hasMore: false);
    }
    return const ReportList(
      hasMore: false,
      reports: [
        GeneratedReport(
          id: 'mock-report-feb-2026',
          title: 'February 2026 Health Report',
          periodStart: '2026-02-01',
          periodEnd: '2026-02-28',
          generatedAt: '2026-03-01T06:00:00Z',
          categorySummaries: [
            ReportCategorySummary(
              category: 'activity',
              categoryLabel: 'Activity',
              averageScore: 78,
              deltaVsPrior: 5.2,
              keyMetric: 'Avg Steps',
              keyMetricValue: '9,240/day',
            ),
            ReportCategorySummary(
              category: 'sleep',
              categoryLabel: 'Sleep',
              averageScore: 71,
              deltaVsPrior: -2.1,
              keyMetric: 'Avg Duration',
              keyMetricValue: '7.2 hrs',
            ),
            ReportCategorySummary(
              category: 'heart',
              categoryLabel: 'Heart',
              averageScore: 84,
              deltaVsPrior: 3.8,
              keyMetric: 'Avg HRV',
              keyMetricValue: '51 ms',
            ),
          ],
          topCorrelations: [
            CorrelationHighlight(
              id: 'rep-corr-1',
              metricA: 'Sleep Duration',
              metricB: 'HRV',
              coefficient: 0.72,
              direction: CorrelationDirection.positive,
              headline: 'More sleep → higher HRV',
              body: 'Strong positive relationship observed across the month.',
              categoryColorHex: '#30D158',
            ),
          ],
          aiRecommendations: [
            'Try to maintain 8 hours of sleep on weekdays — your HRV improves significantly the next morning.',
            'Your step count drops on Tuesdays and Thursdays. Consider a short walk after lunch on those days.',
            'Screen time after 10 PM is your biggest sleep quality disruptor. A 30-minute cutoff could add ~0.5 hrs of deep sleep.',
          ],
          trendDirections: [
            TrendDirection(
                metricLabel: 'Daily Steps', direction: 'up', changePercent: 6.2),
            TrendDirection(
                metricLabel: 'Sleep Quality',
                direction: 'down',
                changePercent: -2.1),
            TrendDirection(
                metricLabel: 'HRV', direction: 'up', changePercent: 3.8),
            TrendDirection(
                metricLabel: 'Resting HR', direction: 'flat', changePercent: 0.4),
          ],
          goalAdherence: const [
            GoalAdherenceItem(
              goalLabel: '10,000 Steps Daily',
              targetValue: '10000',
              unit: 'steps',
              achievedPercent: 0.75,
              streakDays: 5,
            ),
            GoalAdherenceItem(
              goalLabel: '8 Hours Sleep',
              targetValue: '8',
              unit: 'hrs',
              achievedPercent: 0.54,
              streakDays: 2,
            ),
            GoalAdherenceItem(
              goalLabel: '3 Workouts/Week',
              targetValue: '3',
              unit: 'sessions',
              achievedPercent: 0.87,
              streakDays: 3,
            ),
          ],
        ),
        GeneratedReport(
          id: 'mock-report-jan-2026',
          title: 'January 2026 Health Report',
          periodStart: '2026-01-01',
          periodEnd: '2026-01-31',
          generatedAt: '2026-02-01T06:00:00Z',
          categorySummaries: [
            ReportCategorySummary(
              category: 'activity',
              categoryLabel: 'Activity',
              averageScore: 72,
              deltaVsPrior: -1.5,
              keyMetric: 'Avg Steps',
              keyMetricValue: '8,100/day',
            ),
            ReportCategorySummary(
              category: 'sleep',
              categoryLabel: 'Sleep',
              averageScore: 74,
              deltaVsPrior: 1.2,
              keyMetric: 'Avg Duration',
              keyMetricValue: '7.5 hrs',
            ),
          ],
          topCorrelations: [],
          aiRecommendations: [
            'January showed solid sleep consistency — keep it up heading into February.',
          ],
          trendDirections: [
            TrendDirection(
                metricLabel: 'Daily Steps', direction: 'flat', changePercent: 1.1),
            TrendDirection(
                metricLabel: 'Sleep Quality',
                direction: 'up',
                changePercent: 3.5),
          ],
          goalAdherence: const [
            GoalAdherenceItem(
              goalLabel: '10,000 Steps Daily',
              targetValue: '10000',
              unit: 'steps',
              achievedPercent: 0.68,
              streakDays: 3,
            ),
            GoalAdherenceItem(
              goalLabel: '8 Hours Sleep',
              targetValue: '8',
              unit: 'hrs',
              achievedPercent: 0.61,
              streakDays: 4,
            ),
          ],
        ),
      ],
    );
  }

  // ── Data Sources ─────────────────────────────────────────────────────────────

  @override
  Future<DataSourceList> getDataSources() async {
    await _delay();
    final now = DateTime.now();
    return DataSourceList(
      sources: [
        DataSource(
          integrationId: 'apple_health',
          name: 'Apple Health',
          isConnected: true,
          lastSyncedAt:
              now.subtract(const Duration(hours: 1)).toUtc().toIso8601String(),
          freshness: DataFreshness.fresh,
          dataTypes: ['Steps', 'Sleep', 'Heart Rate', 'HRV', 'Active Energy'],
          hasError: false,
        ),
        DataSource(
          integrationId: 'strava',
          name: 'Strava',
          isConnected: true,
          lastSyncedAt:
              now.subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
          freshness: DataFreshness.fresh,
          dataTypes: ['Running', 'Cycling', 'Swimming'],
          hasError: false,
        ),
        DataSource(
          integrationId: 'fitbit',
          name: 'Fitbit',
          isConnected: true,
          lastSyncedAt:
              now.subtract(const Duration(minutes: 30)).toUtc().toIso8601String(),
          freshness: DataFreshness.fresh,
          dataTypes: ['Steps', 'Sleep Stages', 'Resting HR', 'SpO2'],
          hasError: false,
        ),
      ],
    );
  }

  // ── Cache Invalidation ────────────────────────────────────────────────────────

  @override
  void invalidateAll() {
    // No-op: mock has no cache state.
  }
}
