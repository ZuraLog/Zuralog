/// Zuralog Dashboard — Metric Series Riverpod Providers.
///
/// Declares the three Riverpod providers that wire the data layer
/// ([RealMetricDataRepository]) to the presentation layer:
///
/// - [metricDataRepositoryProvider] — singleton real repository instance.
/// - [metricSeriesProvider] — family provider for one metric's time-series.
/// - [categorySnapshotProvider] — family provider for a category's hub-card
///   preview values.
///
/// Also re-exports [selectedTimeRangeProvider] from [time_range_selector.dart]
/// so consumers only need to import this file.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/features/dashboard/data/real_metric_data_repository.dart';
import 'package:zuralog/features/dashboard/domain/health_category.dart';
import 'package:zuralog/features/dashboard/domain/health_metric_registry.dart';
import 'package:zuralog/features/dashboard/domain/metric_series.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';

// Re-export so downstream code has a single import point.
export 'package:zuralog/features/dashboard/presentation/widgets/time_range_selector.dart'
    show selectedTimeRangeProvider;

// ── Repository provider ───────────────────────────────────────────────────────

/// Provider that exposes the singleton [RealMetricDataRepository].
///
/// Reads live health data from native HealthKit / Health Connect via
/// [HealthRepository], with Cloud Brain API as a fallback.
///
/// Use [ref.watch(metricDataRepositoryProvider)] inside other providers or
/// widgets to obtain the shared repository instance.
final metricDataRepositoryProvider = Provider<RealMetricDataRepository>(
  (ref) => RealMetricDataRepository(
    healthRepository: ref.watch(healthRepositoryProvider),
    analyticsRepository: ref.watch(analyticsRepositoryProvider),
  ),
);

// ── Series provider ───────────────────────────────────────────────────────────

/// Family provider that fetches the time-series for a single metric.
///
/// Key: a `(metricId, timeRange)` record — e.g. `('steps', TimeRange.week)`.
///
/// Example:
/// ```dart
/// final async = ref.watch(metricSeriesProvider(('steps', TimeRange.week)));
/// ```
///
/// Returns an [AsyncValue<MetricSeries>] containing the data points and
/// pre-computed [MetricStats] for the given metric and time window.
/// When [MetricSeries.dataPoints] is empty, no data source is connected.
final metricSeriesProvider =
    FutureProvider.autoDispose.family<MetricSeries, (String, TimeRange)>(
  (ref, args) async {
    final RealMetricDataRepository repo =
        ref.watch(metricDataRepositoryProvider);
    return repo.getMetricSeries(metricId: args.$1, timeRange: args.$2);
  },
);

// ── Category snapshot provider ────────────────────────────────────────────────

/// Family provider that fetches today's snapshot values for a [HealthCategory].
///
/// Retrieves up to four preview metric values for the given [category],
/// suitable for rendering compact summary numbers inside a dashboard hub card.
///
/// Key: [HealthCategory] enum value.
///
/// Example:
/// ```dart
/// final async = ref.watch(categorySnapshotProvider(HealthCategory.activity));
/// ```
///
/// Returns an [AsyncValue<Map<String, double>>] mapping metric IDs to their
/// most-recent single reading. Missing keys indicate no data was recorded for
/// that metric — the UI should treat these as "no data" and render dimmed.
final categorySnapshotProvider =
    FutureProvider.autoDispose.family<Map<String, double>, HealthCategory>(
  (ref, category) async {
    final RealMetricDataRepository repo =
        ref.watch(metricDataRepositoryProvider);
    final List<String> previewIds =
        HealthMetricRegistry.byCategory(category)
            .take(4)
            .map((m) => m.id)
            .toList();
    return repo.getTodaySnapshots(previewIds);
  },
);
