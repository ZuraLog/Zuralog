/// Zuralog Dashboard — Category Detail Screen.
///
/// Displays all health metrics for a given [HealthCategory] as a scrollable
/// list of [MetricGraphTile] cards, preceded by a pinned [SliverAppBar] and
/// a [TimeRangeSelector] sticky header.
///
/// Each tile is loaded asynchronously via [metricSeriesProvider], showing
/// shimmer placeholders while loading and error tiles on failure. The list
/// supports pull-to-refresh, which invalidates all active metric series
/// providers for the category and triggers a fresh fetch.
///
/// Platform filtering hides metrics not available on the current device:
/// - iOS: only metrics with an `hkIdentifier` are shown.
/// - Android: only metrics with an `hcRecordType` are shown.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/dashboard/domain/health_category.dart';
import 'package:zuralog/features/dashboard/domain/health_metric.dart';
import 'package:zuralog/features/dashboard/domain/health_metric_registry.dart';
import 'package:zuralog/features/dashboard/presentation/providers/metric_series_provider.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/metric_graph_tile.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/time_range_selector.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

/// A full-screen view listing all health metrics for one [HealthCategory].
///
/// The screen is parameterised by [category] and renders every metric whose
/// platform availability matches the running device. Tapping a tile navigates
/// to [MetricDetailScreen] for that metric via [GoRouter].
///
/// Usage:
/// ```dart
/// CategoryDetailScreen(category: HealthCategory.activity)
/// ```
class CategoryDetailScreen extends ConsumerWidget {
  /// Creates a [CategoryDetailScreen] for the given [category].
  const CategoryDetailScreen({required this.category, super.key});

  /// The health category whose metrics are displayed.
  final HealthCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext ctx, bool _) => [
          SliverAppBar(
            title: Text(category.displayName, style: AppTextStyles.h2),
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
        body: _CategoryMetricsList(category: category),
      ),
    );
  }
}

// ── Body list (Consumer-wrapped for RefreshIndicator + data) ──────────────────

/// The scrollable body of [CategoryDetailScreen].
///
/// Wraps a [RefreshIndicator] around the metric list. On refresh, invalidates
/// every [metricSeriesProvider] entry for the category so data is re-fetched.
class _CategoryMetricsList extends ConsumerWidget {
  const _CategoryMetricsList({required this.category});

  /// The category whose metrics are listed.
  final HealthCategory category;

  /// Applies the platform availability filter to [metrics].
  ///
  /// Returns only metrics available on the current device. Gracefully falls
  /// back to returning all metrics if the platform check throws (e.g., tests).
  List<HealthMetric> _filterByPlatform(List<HealthMetric> metrics) {
    try {
      if (Platform.isAndroid) {
        return metrics.where((m) => m.isAvailableOnAndroid).toList();
      }
      if (Platform.isIOS) {
        return metrics.where((m) => m.isAvailableOnIOS).toList();
      }
    } catch (_) {
      // Platform check unavailable (tests / web). Return all.
    }
    return metrics;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeRange = ref.watch(selectedTimeRangeProvider);
    final allMetrics = HealthMetricRegistry.byCategory(category);
    final metrics = _filterByPlatform(allMetrics);

    if (metrics.isEmpty) {
      return _EmptyState(category: category);
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Invalidate all series providers for this category's metrics.
        for (final metric in allMetrics) {
          ref.invalidate(metricSeriesProvider((metric.id, timeRange)));
        }
        // Give auto-dispose providers a moment to re-subscribe.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        itemCount: metrics.length,
        separatorBuilder: (BuildContext ctx, int index) =>
            const SizedBox(height: AppDimens.spaceMd),
        itemBuilder: (BuildContext ctx, int i) {
          final metric = metrics[i];
          final seriesAsync =
              ref.watch(metricSeriesProvider((metric.id, timeRange)));

          return seriesAsync.when(
            loading: () => const _GraphTileShimmer(),
            error: (Object e, _) => _GraphTileError(metric: metric),
            data: (series) => MetricGraphTile(
              metric: metric,
              series: series,
              accentColor: category.accentColor,
              onTap: () => context.go(
                '/dashboard/${category.name}/${metric.id}',
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

/// Centered empty-state widget shown when no metrics pass the platform filter.
///
/// Displays the category icon, a primary message, and a subtitle prompting the
/// user to connect a health platform.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.category});

  /// The category with no available metrics.
  final HealthCategory category;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 56,
              color: category.accentColor,
            ),
            const SizedBox(height: AppDimens.spaceLg),
            Text(
              'No metrics available',
              style: AppTextStyles.h3.copyWith(color: textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Connect Apple Health or Health Connect to get started',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

/// A loading placeholder that mimics the shape of a [MetricGraphTile].
///
/// Uses a muted surface-coloured container to indicate that data is loading
/// without requiring an external shimmer package.
class _GraphTileShimmer extends StatelessWidget {
  const _GraphTileShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerColor = isDark ? AppColors.surfaceDark : AppColors.borderLight;

    return ZuralogCard(
      padding: EdgeInsets.zero,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: shimmerColor,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
      ),
    );
  }
}

// ── Error tile ────────────────────────────────────────────────────────────────

/// An error tile rendered when [metricSeriesProvider] emits an error.
///
/// Shows the metric's display name alongside a generic error message,
/// centred inside a [ZuralogCard].
class _GraphTileError extends StatelessWidget {
  const _GraphTileError({required this.metric});

  /// The metric that failed to load.
  final HealthMetric metric;

  @override
  Widget build(BuildContext context) {
    return ZuralogCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Text(
            'Failed to load ${metric.displayName}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
