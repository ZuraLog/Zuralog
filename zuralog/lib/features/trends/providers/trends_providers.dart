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
/// - [selectedTimeRangeProvider]        — transient: time range (7D/30D/90D)
/// - [correlationAnalysisProvider]      — async correlation result (family)
/// - [reportsProvider]                  — async reports list
/// - [dataSourcesProvider]              — async data sources list
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/trends/data/trends_repository.dart';
import 'package:zuralog/features/trends/domain/trends_models.dart';

// ── Repository ────────────────────────────────────────────────────────────────

/// Singleton [TrendsRepository] wired to the shared [apiClientProvider].
final trendsRepositoryProvider = Provider<TrendsRepository>((ref) {
  return TrendsRepository(apiClient: ref.read(apiClientProvider));
});

// ── Trends Home ───────────────────────────────────────────────────────────────

/// Async provider for the aggregated Trends Home screen data.
///
/// Invalidate with [ref.invalidate(trendsHomeProvider)] after a
/// pull-to-refresh.
final trendsHomeProvider = FutureProvider<TrendsHomeData>((ref) async {
  final repo = ref.read(trendsRepositoryProvider);
  return repo.getTrendsHome();
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

// ── Correlation Analysis ──────────────────────────────────────────────────────

/// Key for parameterising the correlation analysis provider.
class CorrelationKey {
  const CorrelationKey({
    required this.metricAId,
    required this.metricBId,
    required this.lagDays,
    required this.timeRange,
  });

  final String metricAId;
  final String metricBId;
  final int lagDays;
  final CorrelationTimeRange timeRange;

  @override
  bool operator ==(Object other) =>
      other is CorrelationKey &&
      other.metricAId == metricAId &&
      other.metricBId == metricBId &&
      other.lagDays == lagDays &&
      other.timeRange == timeRange;

  @override
  int get hashCode =>
      Object.hash(metricAId, metricBId, lagDays, timeRange);
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
