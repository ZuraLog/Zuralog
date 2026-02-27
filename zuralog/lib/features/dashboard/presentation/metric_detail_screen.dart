/// Zuralog Dashboard — Metric Detail Screen.
///
/// A full-detail screen for a single health metric identified by [metricId]
/// within its parent [HealthCategory].
///
/// The screen is structured with a pinned [SliverAppBar] and a sticky
/// [TimeRangeSelector] header above the scrollable content body. The body
/// switches between loading, error, and data states via Riverpod's
/// [AsyncValue.when] pattern.
///
/// When data is available, [_DetailBody] renders:
///   1. A full-size [MetricGraphTile] (non-compact).
///   2. A stats card with Avg / Min / Max / Total / Trend columns.
///   3. A data log of the last 10 data points.
///
/// If [metricId] is not found in [HealthMetricRegistry], a centered error
/// message is shown instead of the full layout.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/dashboard/domain/health_category.dart';
import 'package:zuralog/features/dashboard/domain/health_metric.dart';
import 'package:zuralog/features/dashboard/domain/health_metric_registry.dart';
import 'package:zuralog/features/dashboard/domain/metric_series.dart';
import 'package:zuralog/features/dashboard/domain/metric_stats.dart';
import 'package:zuralog/features/dashboard/presentation/providers/metric_series_provider.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/metric_graph_tile.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/time_range_selector.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Formats [date] as "MMM d, yyyy" without the intl package.
///
/// Example output: `"Feb 27, 2026"`.
String _formatDate(DateTime date) {
  const List<String> months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Full-detail screen for a single health metric.
///
/// Looks up the [HealthMetric] via [HealthMetricRegistry.byId] using
/// [metricId]. Shows a graceful error state if the metric is not found.
///
/// Usage:
/// ```dart
/// MetricDetailScreen(
///   category: HealthCategory.activity,
///   metricId: 'steps',
/// )
/// ```
class MetricDetailScreen extends ConsumerWidget {
  /// Creates a [MetricDetailScreen].
  const MetricDetailScreen({
    required this.category,
    required this.metricId,
    super.key,
  });

  /// The parent category; used for accent colour and back-navigation context.
  final HealthCategory category;

  /// The unique metric identifier to look up in [HealthMetricRegistry].
  final String metricId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HealthMetric? metric = HealthMetricRegistry.byId(metricId);

    if (metric == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(),
        body: const _UnknownMetricError(),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext ctx, bool _) => [
          SliverAppBar(
            title: Text(metric.displayName, style: AppTextStyles.h2),
            pinned: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
              child: const TimeRangeSelector(),
            ),
          ),
        ],
        body: _MetricDetailBody(
          metric: metric,
          category: category,
        ),
      ),
    );
  }
}

// ── Body (consumer-level data watcher) ────────────────────────────────────────

/// Watches [metricSeriesProvider] and delegates to loading / error / data UIs.
class _MetricDetailBody extends ConsumerWidget {
  const _MetricDetailBody({
    required this.metric,
    required this.category,
  });

  final HealthMetric metric;
  final HealthCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeRange = ref.watch(selectedTimeRangeProvider);
    final seriesAsync =
        ref.watch(metricSeriesProvider((metric.id, timeRange)));

    return seriesAsync.when(
      loading: () => const _DetailShimmer(),
      error: (Object e, _) => const _DetailError(),
      data: (MetricSeries series) => _DetailBody(
        metric: metric,
        series: series,
        category: category,
      ),
    );
  }
}

// ── Detail body ───────────────────────────────────────────────────────────────

/// The full data-loaded content of [MetricDetailScreen].
///
/// Renders three sections inside a [SingleChildScrollView]:
///   1. A full-size [MetricGraphTile] with compact = false.
///   2. A stats card (Avg / Min / Max / Total / Trend).
///   3. A data log of the last 10 data points.
class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.metric,
    required this.series,
    required this.category,
  });

  /// The health metric being displayed.
  final HealthMetric metric;

  /// The time-series data for [metric].
  final MetricSeries series;

  /// The parent category; provides the accent colour.
  final HealthCategory category;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Full-size graph tile.
          MetricGraphTile(
            metric: metric,
            series: series,
            accentColor: category.accentColor,
            compact: false,
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // 2. Stats row card.
          _StatsCard(stats: series.stats, accentColor: category.accentColor),
          const SizedBox(height: AppDimens.spaceMd),

          // 3. Data log.
          _DataLogCard(series: series, unit: metric.unit),
          const SizedBox(height: AppDimens.spaceMd),
        ],
      ),
    );
  }
}

// ── Stats card ────────────────────────────────────────────────────────────────

/// A [ZuralogCard] displaying five aggregate stat columns side-by-side.
///
/// Columns: Avg | Min | Max | Total | Trend.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats, required this.accentColor});

  /// Pre-computed aggregate stats to display.
  final MetricStats stats;

  /// Category accent colour used for positive trend colouring.
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final trendPositive = stats.trendPercent >= 0;
    final trendLabel =
        '${trendPositive ? '+' : ''}${stats.trendPercent.toStringAsFixed(1)}%';
    final trendColor = trendPositive ? accentColor : AppColors.textSecondary;

    return ZuralogCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatColumn(
            label: 'Avg',
            value: stats.average.toStringAsFixed(1),
          ),
          _StatColumn(
            label: 'Min',
            value: stats.min.toStringAsFixed(1),
          ),
          _StatColumn(
            label: 'Max',
            value: stats.max.toStringAsFixed(1),
          ),
          _StatColumn(
            label: 'Total',
            value: stats.total.toStringAsFixed(1),
          ),
          _StatColumn(
            label: 'Trend',
            value: trendLabel,
            valueColor: trendColor,
          ),
        ],
      ),
    );
  }
}

/// A single label + value column cell within the [_StatsCard] row.
class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    this.valueColor,
  });

  /// The stat label (e.g. "Avg", "Min").
  final String label;

  /// The formatted value string.
  final String value;

  /// Optional colour override applied to the value text.
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.labelXs.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Text(
          value,
          style: AppTextStyles.caption.copyWith(
            color: valueColor ?? primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Data log card ─────────────────────────────────────────────────────────────

/// A [ZuralogCard] listing the last 10 data points in the series.
///
/// Each row shows: "{date}: {value} {unit}".
class _DataLogCard extends StatelessWidget {
  const _DataLogCard({required this.series, required this.unit});

  /// The series whose last 10 data points are displayed.
  final MetricSeries series;

  /// The unit abbreviation appended after each value.
  final String unit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    final points = series.dataPoints.length > 10
        ? series.dataPoints.sublist(series.dataPoints.length - 10)
        : List.of(series.dataPoints);

    // Show most recent first.
    final reversed = points.reversed.toList();

    return ZuralogCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Data',
            style: AppTextStyles.h3.copyWith(color: textColor),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          if (reversed.isEmpty)
            Text(
              'No data recorded',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            ...reversed.map(
              (point) => Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppDimens.spaceXs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(point.timestamp),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${point.value.toStringAsFixed(1)} $unit',
                      style: AppTextStyles.caption.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Loading shimmer ───────────────────────────────────────────────────────────

/// Loading placeholder shown while [metricSeriesProvider] is pending.
///
/// Renders stacked muted containers that approximate the full-detail layout.
class _DetailShimmer extends StatelessWidget {
  const _DetailShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerColor = isDark ? AppColors.surfaceDark : AppColors.borderLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        children: [
          // Graph placeholder.
          ZuralogCard(
            padding: EdgeInsets.zero,
            child: Container(
              height: 260,
              decoration: BoxDecoration(
                color: shimmerColor,
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          // Stats placeholder.
          ZuralogCard(
            padding: EdgeInsets.zero,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: shimmerColor,
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          // Log placeholder.
          ZuralogCard(
            padding: EdgeInsets.zero,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: shimmerColor,
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error states ──────────────────────────────────────────────────────────────

/// Centered error widget shown when the series provider emits an error.
class _DetailError extends StatelessWidget {
  const _DetailError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceXl),
        child: Text(
          'Failed to load metric data.\nPlease pull down to try again.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Centered error widget shown when [metricId] is not in the registry.
class _UnknownMetricError extends StatelessWidget {
  const _UnknownMetricError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceXl),
        child: Text(
          'Metric not found.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
