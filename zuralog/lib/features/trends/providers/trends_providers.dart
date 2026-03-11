/// Zuralog — Trends Tab Riverpod Providers.
///
/// All state for the Trends tab (Trends Home, Correlations, Reports,
/// Data Sources) is managed here.
///
/// Provider inventory:
/// - [trendsRepositoryProvider]         — singleton repository
/// - [trendsHomeProvider]               — async aggregated Trends Home data
/// - [availableMetricsProvider]         — async list of metrics for picker
/// - [selectedMetricAProvider]          — transient: selected metric A ID
/// - [selectedMetricBProvider]          — transient: selected metric B ID
/// - [selectedLagDaysProvider]          — transient: lag offset (0-3)
/// - [selectedTimeRangeProvider]        — transient: time range (7D/30D/90D/custom)
/// - [customDateStartProvider]          — transient: custom range start date
/// - [customDateEndProvider]            — transient: custom range end date
/// - [correlationAnalysisProvider]      — async correlation result (family)
/// - [reportsProvider]                  — async reports list
/// - [dataSourcesProvider]              — async data sources list
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/trends/data/trends_repository.dart';
import 'package:zuralog/features/trends/domain/trends_models.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Singleton [TrendsRepositoryInterface] wired to the shared [apiClientProvider].
///
/// Always uses the real [TrendsRepository] backed by the Cloud Brain API.
/// Mock repositories are available for unit tests via provider overrides.
final trendsRepositoryProvider = Provider<TrendsRepositoryInterface>((ref) {
  return TrendsRepository(apiClient: ref.read(apiClientProvider));
});

// ── Trends Home ───────────────────────────────────────────────────────────────

/// Async provider for the aggregated Trends Home screen data.
///
/// Never puts the UI into an error state. All failures resolve to an empty
/// [TrendsHomeData] so the screen always reaches the [data:] branch and
/// renders the appropriate empty state instead of a connection error.
///
/// Invalidate with [ref.invalidate(trendsHomeProvider)] after a
/// pull-to-refresh.
final trendsHomeProvider = FutureProvider<TrendsHomeData>((ref) async {
  final repo = ref.read(trendsRepositoryProvider);
  try {
    return await repo.getTrendsHome();
  } catch (_) {
    return const TrendsHomeData(
      correlationHighlights: [],
      timePeriods: [],
      hasEnoughData: false,
    );
  }
});

// ── Available Metrics ─────────────────────────────────────────────────────────

/// Async provider for the list of metrics available in the correlation picker.
///
/// Long-lived cache — metrics rarely change. Invalidate on pull-to-refresh.
final availableMetricsProvider = FutureProvider<AvailableMetricList>((ref) async {
  final repo = ref.read(trendsRepositoryProvider);
  return repo.getAvailableMetrics();
});

// ── Correlations Explorer Transient State ─────────────────────────────────────

/// Transient: ID of the first metric selected in the picker.
final selectedMetricAProvider = StateProvider<String?>((ref) => null);

/// Transient: ID of the second metric selected in the picker.
final selectedMetricBProvider = StateProvider<String?>((ref) => null);

/// Transient: lag offset in days (0-3) for the correlation analysis.
final selectedLagDaysProvider = StateProvider<int>((ref) => 0);

/// Transient: time range for the correlation analysis.
final selectedTimeRangeProvider =
    StateProvider<CorrelationTimeRange>((ref) => CorrelationTimeRange.thirtyDays);

/// Transient: start date when [selectedTimeRangeProvider] is [CorrelationTimeRange.custom].
final customDateStartProvider = StateProvider<DateTime?>((ref) => null);

/// Transient: end date when [selectedTimeRangeProvider] is [CorrelationTimeRange.custom].
final customDateEndProvider = StateProvider<DateTime?>((ref) => null);

// ── Correlation Analysis ──────────────────────────────────────────────────────

/// Key for parameterising the correlation analysis provider.
class CorrelationKey {
  const CorrelationKey({
    required this.metricAId,
    required this.metricBId,
    required this.lagDays,
    required this.timeRange,
    this.customStart,
    this.customEnd,
  });

  final String metricAId;
  final String metricBId;
  final int lagDays;
  final CorrelationTimeRange timeRange;

  /// Set when [timeRange] is [CorrelationTimeRange.custom].
  final DateTime? customStart;

  /// Set when [timeRange] is [CorrelationTimeRange.custom].
  final DateTime? customEnd;

  @override
  bool operator ==(Object other) =>
      other is CorrelationKey &&
      other.metricAId == metricAId &&
      other.metricBId == metricBId &&
      other.lagDays == lagDays &&
      other.timeRange == timeRange &&
      other.customStart == customStart &&
      other.customEnd == customEnd;

  @override
  int get hashCode =>
      Object.hash(metricAId, metricBId, lagDays, timeRange, customStart, customEnd);
}

/// Family provider for a specific correlation analysis.
///
/// Pass a [CorrelationKey] to select the metric pair, lag, and time range.
final correlationAnalysisProvider =
    FutureProvider.family<CorrelationAnalysis, CorrelationKey>(
  (ref, key) async {
    final repo = ref.read(trendsRepositoryProvider);
    return repo.getCorrelationAnalysis(
      metricAId: key.metricAId,
      metricBId: key.metricBId,
      lagDays: key.lagDays,
      timeRange: key.timeRange,
      customStart: key.customStart,
      customEnd: key.customEnd,
    );
  },
);

// ── Reports ───────────────────────────────────────────────────────────────────

/// Async provider for the first page of generated monthly reports.
///
/// Invalidate with [ref.invalidate(reportsProvider)] after a pull-to-refresh.
final reportsProvider = FutureProvider<ReportList>((ref) async {
  final repo = ref.read(trendsRepositoryProvider);
  return repo.getReports();
});

// ── Data Sources ──────────────────────────────────────────────────────────────

/// Async provider for the full list of data sources (integration sync status).
///
/// Invalidate with [ref.invalidate(dataSourcesProvider)] after pull-to-refresh.
final dataSourcesProvider = FutureProvider<DataSourceList>((ref) async {
  final repo = ref.read(trendsRepositoryProvider);
  return repo.getDataSources();
});
