/// Zuralog Dashboard — Dashboard Hub Screen.
///
/// The hero "Command Center" screen of the Zuralog app.
///
/// Layout order (top → bottom):
///   A) Floating [SliverAppBar] — time-sensitive greeting + profile avatar.
///   B) [_EssentialMetricsSection] — "Today's Essentials" at-a-glance tiles.
///   C) Compact AI Insight strip — left-border accent, italic text, tap to chat.
///   D) [SliverList] of 10 [CategoryCard] widgets, one per [HealthCategory].
///      Categories with zero platform-available metrics are hidden automatically.
///   E) Connected-apps [IntegrationsRail] at the very bottom.
///
/// Data is sourced from:
///   - [categorySnapshotProvider] — today's snapshot values per category.
///   - [metricSeriesProvider]     — 7-day sparkline for the primary metric.
///   - [dashboardInsightProvider] — AI-generated natural-language insight.
///   - [userProfileProvider]      — first name for the greeting.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/analytics/domain/analytics_providers.dart';
import 'package:zuralog/features/analytics/domain/dashboard_insight.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/dashboard/domain/graph_type.dart';
import 'package:zuralog/features/dashboard/domain/health_category.dart';
import 'package:zuralog/features/dashboard/domain/health_metric.dart';
import 'package:zuralog/features/dashboard/domain/health_metric_registry.dart';
import 'package:zuralog/features/dashboard/domain/metric_series.dart';
import 'package:zuralog/features/dashboard/domain/time_range.dart';
import 'package:zuralog/features/dashboard/presentation/providers/metric_series_provider.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/category_card.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/bar_chart_graph.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/dual_line_chart.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/line_chart_graph.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/range_line_chart.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/stacked_bar_chart.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/graphs/threshold_line_chart.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/integrations_rail.dart';
import 'package:zuralog/shared/widgets/profile_avatar_button.dart';

// ── Internal constants ────────────────────────────────────────────────────────

/// Left-border accent thickness on the compact insight strip.
const double _kInsightBorderWidth = 3.0;

/// Preview metric IDs per category, ordered by display priority (Appendix A).
///
/// Keys are [HealthCategory] enum values; values are ordered lists of metric
/// IDs from [HealthMetricRegistry]. The first ID in each list is also used as
/// the primary metric for the mini graph.
const Map<HealthCategory, List<String>> _kCategoryPreviewIds = {
  HealthCategory.activity: [
    'steps',
    'active_calories_burned',
    'distance',
  ],
  HealthCategory.heart: [
    'resting_heart_rate',
    'heart_rate_variability',
    'vo2_max',
  ],
  HealthCategory.body: [
    'weight',
    'body_fat_percentage',
    'bmi',
  ],
  HealthCategory.sleep: [
    'sleep_duration',
    'sleep_stages',
  ],
  HealthCategory.vitals: [
    'oxygen_saturation',
    'blood_pressure',
    'respiratory_rate',
  ],
  HealthCategory.nutrition: [
    'dietary_energy',
    'protein',
    'carbohydrates',
  ],
  HealthCategory.cycle: [
    'menstruation_flow',
    'cervical_mucus',
  ],
  HealthCategory.wellness: [
    'mindfulness_session',
    'skin_temperature',
  ],
  HealthCategory.mobility: [
    'walking_speed',
    'walking_steadiness',
    'walking_step_length',
  ],
  HealthCategory.environment: [
    'water_temperature',
  ],
};

// ── Screen ────────────────────────────────────────────────────────────────────

/// The main Dashboard hub screen — the app's command centre.
///
/// Uses a [CustomScrollView] with a floating [SliverAppBar] header and a
/// [SliverList] body containing one [CategoryCard] per [HealthCategory].
///
/// Platform awareness: categories whose metrics are unavailable on the
/// current device platform are silently omitted from the list.
class DashboardScreen extends ConsumerWidget {
  /// Creates a [DashboardScreen].
  const DashboardScreen({super.key});

  /// Shell branch index for the Chat / AI Coach tab.
  static const int _kChatBranchIndex = 1;

  /// Shell branch index for the Integrations tab.
  static const int _kIntegrationsBranchIndex = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightAsync = ref.watch(dashboardInsightProvider);
    final profile = ref.watch(userProfileProvider);

    // Determine visible categories for the current platform.
    final visibleCategories = HealthCategory.values
        .where((cat) => _isCategoryVisibleOnPlatform(cat))
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          // Push latest HealthKit data to Cloud Brain, then refresh UI providers.
          await ref.read(healthSyncServiceProvider).syncToCloud();
          ref.invalidate(dashboardInsightProvider);
          for (final cat in visibleCategories) {
            ref.invalidate(categorySnapshotProvider(cat));
            final primaryId = _kCategoryPreviewIds[cat]?.firstOrNull;
            if (primaryId != null) {
              ref.invalidate(
                metricSeriesProvider((primaryId, TimeRange.week)),
              );
            }
          }
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Floating App Bar ────────────────────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 72,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                  ),
                  child: _buildHeader(
                    context,
                    ref,
                    profile?.aiName ?? '...',
                  ),
                ),
              ),
            ),

            // ── A) Essential health at-a-glance tiles ───────────────────────
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              sliver: SliverToBoxAdapter(child: _EssentialMetricsSection()),
            ),

            // ── B) Compact AI Insight strip ─────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    insightAsync.when(
                      data: (insight) => _CompactInsightStrip(
                        insight: insight,
                        onTap: () => StatefulNavigationShell.of(
                          context,
                        ).goBranch(_kChatBranchIndex),
                      ),
                      loading: () => const _InsightStripShimmer(),
                      error: (e, _) => _CompactInsightStrip(
                        insight: const DashboardInsight(
                          insight:
                              'Tap to chat with your AI coach for today\'s insight.',
                        ),
                        onTap: () => StatefulNavigationShell.of(
                          context,
                        ).goBranch(_kChatBranchIndex),
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceLg),
                  ],
                ),
              ),
            ),

            // ── C) One CategoryCard per visible HealthCategory (lazy) ────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                    child: _CategoryCardLoader(
                      category: visibleCategories[i],
                    ),
                  ),
                  childCount: visibleCategories.length,
                ),
              ),
            ),

            // ── D) Integrations rail + bottom clearance ──────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: AppDimens.spaceSm),
                    IntegrationsRail(
                      onManageTap: () => StatefulNavigationShell.of(
                        context,
                      ).goBranch(_kIntegrationsBranchIndex),
                    ),
                    const SizedBox(height: AppDimens.spaceXxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  /// Builds the top greeting header row.
  ///
  /// Shows a time-sensitive greeting on the left and a profile avatar on the
  /// right. Tapping the avatar navigates to the settings screen.
  ///
  /// Parameters:
  ///   [context] — current [BuildContext].
  ///   [ref]     — Riverpod [WidgetRef].
  ///   [name]    — display name for the greeting.
  Widget _buildHeader(BuildContext context, WidgetRef ref, String name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 18
        ? 'Good Afternoon'
        : 'Good Evening';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: greeting + name
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              greeting,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              name,
              style: AppTextStyles.h2.copyWith(color: AppColors.primary),
            ),
          ],
        ),

        const Spacer(),

        // Right: profile avatar — opens side panel
        const ProfileAvatarButton(),
      ],
    );
  }
}

// ── Category platform filter ──────────────────────────────────────────────────

/// Returns `true` if [category] has at least one metric available on the
/// current device platform.
///
/// Uses [HealthMetricRegistry.byCategory] and checks
/// [HealthMetric.isAvailableOnIOS] / [HealthMetric.isAvailableOnAndroid]
/// against [Platform.isIOS] / [Platform.isAndroid].
bool _isCategoryVisibleOnPlatform(HealthCategory category) {
  final metrics = HealthMetricRegistry.byCategory(category);
  if (metrics.isEmpty) return false;
  if (Platform.isIOS) {
    return metrics.any((m) => m.isAvailableOnIOS);
  }
  if (Platform.isAndroid) {
    return metrics.any((m) => m.isAvailableOnAndroid);
  }
  // Fallback for desktop/web: show all categories.
  return true;
}

// ── Category Card Loader ──────────────────────────────────────────────────────

/// Loads snapshot data and the primary metric series for [category], then
/// renders a [CategoryCard].
///
/// Handles loading, error, and data states as per the Task 6 spec:
///   - **Loading**: card renders with placeholder `'—'` values.
///   - **Error**: card renders with `'No data'` values.
///   - **Data**: card renders real values from the snapshot map.
///
/// The mini graph uses [metricSeriesProvider] for the category's primary
/// metric. While the series loads, a surface-coloured [SizedBox] placeholder
/// is shown.
class _CategoryCardLoader extends ConsumerWidget {
  /// Creates a [_CategoryCardLoader] for [category].
  // ignore: unused_element_parameter
  const _CategoryCardLoader({super.key, required this.category});

  /// The health category to load and display.
  final HealthCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(categorySnapshotProvider(category));
    final previewIds = _kCategoryPreviewIds[category] ?? [];
    final primaryId = previewIds.firstOrNull;

    // Load the series for the primary metric (for the mini graph).
    final seriesAsync = primaryId != null
        ? ref.watch(metricSeriesProvider((primaryId, TimeRange.week)))
        : null;

    // Resolve the primary HealthMetric object for the mini graph.
    final primaryMetric =
        primaryId != null ? HealthMetricRegistry.byId(primaryId) : null;

    // Build mini graph widget based on series state.
    final Widget? miniGraph = _buildMiniGraph(
      context,
      seriesAsync,
      primaryMetric,
      category,
    );

    return snapshotAsync.when(
      loading: () => CategoryCard(
        category: category,
        previews: _loadingPreviews(previewIds),
        miniGraph: miniGraph,
        onTap: () => context.go('/dashboard/${category.name}'),
      ),
      error: (err, st) => CategoryCard(
        category: category,
        previews: _errorPreviews(previewIds),
        miniGraph: miniGraph,
        onTap: () => context.go('/dashboard/${category.name}'),
      ),
      data: (snapshot) => CategoryCard(
        category: category,
        previews: _dataPreviews(previewIds, snapshot),
        miniGraph: miniGraph,
        onTap: () => context.go('/dashboard/${category.name}'),
      ),
    );
  }

  // ── Preview builders ─────────────────────────────────────────────────────

  /// Builds placeholder [MetricPreview] rows while the snapshot is loading.
  ///
  /// Shows `'—'` as the value and an empty unit string for each preview ID.
  List<MetricPreview> _loadingPreviews(List<String> ids) => ids
      .map(
        (id) => MetricPreview(
          label: HealthMetricRegistry.byId(id)?.displayName ?? id,
          value: '—',
          unit: '',
        ),
      )
      .toList();

  /// Builds error [MetricPreview] rows when the snapshot fails.
  ///
  /// Shows `'No data'` as the value and an empty unit string for each ID.
  List<MetricPreview> _errorPreviews(List<String> ids) => ids
      .map(
        (id) => MetricPreview(
          label: HealthMetricRegistry.byId(id)?.displayName ?? id,
          value: 'No data',
          unit: '',
        ),
      )
      .toList();

  /// Builds data [MetricPreview] rows from a [snapshot] map.
  ///
  /// Falls back to `'—'` for any metric ID not present in [snapshot].
  List<MetricPreview> _dataPreviews(
    List<String> ids,
    Map<String, double> snapshot,
  ) =>
      ids.map((id) {
        final metric = HealthMetricRegistry.byId(id);
        final raw = snapshot[id];
        final label = metric?.displayName ?? id;
        final unit = metric?.unit ?? '';
        if (raw == null) {
          return MetricPreview(label: label, value: '—', unit: unit);
        }
        // Format integers without decimals; floats to 1 decimal place.
        final formatted =
            raw == raw.truncateToDouble() && raw < 10000
                ? raw.toInt().toString()
                : raw.toStringAsFixed(1);
        return MetricPreview(label: label, value: formatted, unit: unit);
      }).toList();

  // ── Mini graph builder ───────────────────────────────────────────────────

  /// Builds the compact mini graph widget from the series async state.
  ///
  /// Returns the raw chart widget at 60px height via [_buildRawMiniGraph]
  /// when data is available. While loading or on error a surface-coloured
  /// placeholder via [_graphPlaceholder] is shown instead.
  ///
  /// Parameters:
  ///   [context]     — current [BuildContext].
  ///   [seriesAsync] — nullable async series for the primary metric.
  ///   [metric]      — the [HealthMetric] definition for graph type dispatch.
  ///   [category]    — category providing the accent colour.
  ///
  /// Returns `null` when no primary metric or series provider exists.
  Widget? _buildMiniGraph(
    BuildContext context,
    AsyncValue<MetricSeries>? seriesAsync,
    HealthMetric? metric,
    HealthCategory category,
  ) {
    if (seriesAsync == null || metric == null) return null;

    return seriesAsync.when(
      loading: () => _graphPlaceholder(context),
      error: (err, st) => _graphPlaceholder(context),
      data: (series) => _buildRawMiniGraph(series, metric, category.accentColor),
    );
  }

  /// Builds a raw 60px chart widget without any header, subtitle, or stats row.
  ///
  /// Dispatches on [metric.graphType] and returns the appropriate low-level
  /// chart widget constrained to 60px height. Defaults to [LineChartGraph]
  /// for any unhandled [GraphType].
  ///
  /// Parameters:
  ///   [series]      — the time-series data to render.
  ///   [metric]      — provides the [GraphType] for dispatch.
  ///   [accentColor] — accent colour forwarded to the chart widget.
  Widget _buildRawMiniGraph(
    MetricSeries series,
    HealthMetric metric,
    Color accentColor,
  ) {
    final Widget chart = switch (metric.graphType) {
      GraphType.bar => BarChartGraph(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: true,
        ),
      GraphType.rangeLine => RangeLineChart(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: true,
        ),
      GraphType.dualLine => DualLineChart(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: true,
        ),
      GraphType.stackedBar => StackedBarChart(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: true,
        ),
      GraphType.thresholdLine => ThresholdLineChart(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: true,
        ),
      _ => LineChartGraph(
          series: series,
          timeRange: series.timeRange,
          accentColor: accentColor,
          compact: true,
        ),
    };
    return SizedBox(height: 60, child: chart);
  }

  /// Returns a 60px tall surface-coloured placeholder used while the mini
  /// graph series is loading or has errored.
  ///
  /// Parameters:
  ///   [context] — current [BuildContext] for theme access.
  Widget _graphPlaceholder(BuildContext context) => Container(
        height: 60,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
      );
}

// ── Essential Metrics Section ─────────────────────────────────────────────────

/// Describes one essential metric tile shown in [_EssentialMetricsSection].
///
/// Bundles together all the static display metadata and provider key that a
/// single [_EssentialStatTile] needs, keeping the grid builder clean and
/// declarative.
class _EssentialTileConfig {
  /// Creates an [_EssentialTileConfig].
  ///
  /// [metricId]    — the [HealthMetric] id used to call [metricSeriesProvider].
  ///
  /// [label]       — short display label shown below the value.
  ///
  /// [icon]        — icon rendered inside the accent badge.
  ///
  /// [accentColor] — badge background tint and thin left-border colour.
  ///
  /// [category]    — destination category for tap navigation.
  ///
  /// [useTotal]    — when `true`, uses [MetricStats.total]; otherwise uses
  ///   [MetricStats.average].
  ///
  /// [unit]        — unit abbreviation appended to the displayed value.
  const _EssentialTileConfig({
    required this.metricId,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.category,
    required this.useTotal,
    required this.unit,
  });

  /// Unique metric id — matches [HealthMetric.id].
  final String metricId;

  /// Short label shown below the numeric value.
  final String label;

  /// Icon rendered in the accent badge.
  final IconData icon;

  /// Accent colour for the badge background (20% opacity) and left border.
  final Color accentColor;

  /// Destination [HealthCategory] for tap navigation.
  final HealthCategory category;

  /// When `true`, reads [MetricStats.total]; when `false`, reads
  /// [MetricStats.average].
  final bool useTotal;

  /// Unit abbreviation appended to the value string.
  final String unit;
}

/// Static ordered list of the five essential health metrics shown at the
/// top of the dashboard.
///
/// Order: Steps | Active Calories | Resting HR | Sleep Duration | HRV.
///
/// Declared as a non-const list because [HealthCategory.accentColor] is a
/// non-const enum field and cannot appear in a `const` initialiser.
// ignore: prefer_const_declarations
final List<_EssentialTileConfig> _kEssentialTiles = [
  _EssentialTileConfig(
    metricId: 'steps',
    label: 'Steps',
    icon: Icons.directions_walk_rounded,
    accentColor: HealthCategory.activity.accentColor,
    category: HealthCategory.activity,
    useTotal: true,
    unit: 'steps',
  ),
  _EssentialTileConfig(
    metricId: 'active_calories_burned',
    label: 'Active Cal',
    icon: Icons.local_fire_department_rounded,
    accentColor: HealthCategory.activity.accentColor,
    category: HealthCategory.activity,
    useTotal: true,
    unit: 'kcal',
  ),
  _EssentialTileConfig(
    metricId: 'resting_heart_rate',
    label: 'Resting HR',
    icon: Icons.favorite_rounded,
    accentColor: HealthCategory.heart.accentColor,
    category: HealthCategory.heart,
    useTotal: false,
    unit: 'bpm',
  ),
  _EssentialTileConfig(
    metricId: 'sleep_duration',
    label: 'Sleep',
    icon: Icons.bedtime_rounded,
    accentColor: HealthCategory.sleep.accentColor,
    category: HealthCategory.sleep,
    useTotal: false,
    unit: 'hr',
  ),
  _EssentialTileConfig(
    metricId: 'heart_rate_variability',
    label: 'HRV',
    icon: Icons.monitor_heart_rounded,
    accentColor: HealthCategory.heart.accentColor,
    category: HealthCategory.heart,
    useTotal: false,
    unit: 'ms',
  ),
];

/// "Today's Essentials" at-a-glance section shown at the top of the dashboard.
///
/// Renders five [_EssentialStatTile]s in a responsive 2-row grid:
///   - Row 1: Steps | Active Calories | Resting HR  (3 equal columns).
///   - Row 2: Sleep Duration | HRV  (2 equal columns).
///
/// Each tile watches [metricSeriesProvider] for today's value and taps
/// through to the corresponding category detail screen.
class _EssentialMetricsSection extends ConsumerWidget {
  /// Creates an [_EssentialMetricsSection].
  const _EssentialMetricsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Split into row 1 (first 3) and row 2 (last 2).
    final row1 = _kEssentialTiles.sublist(0, 3);
    final row2 = _kEssentialTiles.sublist(3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppDimens.spaceMd),
        // Section header label.
        Text(
          "Today's Essentials",
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),

        // Row 1: 3-column grid (Steps, Active Cal, Resting HR).
        Row(
          children: row1.map((cfg) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: cfg == row1.last ? 0 : AppDimens.spaceXs,
                ),
                child: _EssentialStatTile(config: cfg, ref: ref),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: AppDimens.spaceXs),

        // Row 2: 2-column grid (Sleep, HRV).
        Row(
          children: row2.map((cfg) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: cfg == row2.last ? 0 : AppDimens.spaceXs,
                ),
                child: _EssentialStatTile(config: cfg, ref: ref),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: AppDimens.spaceMd),
      ],
    );
  }
}

/// A single compact stat tile used inside [_EssentialMetricsSection].
///
/// Layout (horizontal):
///   [accent badge | icon] → [value (H3) + label (caption)]
///
/// A thin left border in [config.accentColor] provides subtle category
/// identity without competing with the card background.
///
/// Tapping navigates to `/dashboard/{category.name}`.
class _EssentialStatTile extends StatelessWidget {
  /// Creates an [_EssentialStatTile].
  ///
  /// [config] — static display metadata for this tile.
  ///
  /// [ref]    — Riverpod [WidgetRef] forwarded from the parent
  ///   [_EssentialMetricsSection] so we can watch providers.
  const _EssentialStatTile({
    required this.config,
    required this.ref,
  });

  /// Display metadata and provider key for this tile.
  final _EssentialTileConfig config;

  /// Riverpod ref from the parent [ConsumerWidget].
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(
      metricSeriesProvider((config.metricId, TimeRange.day)),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    // Resolve display value.
    final String displayValue = seriesAsync.when(
      loading: () => '—',
      error: (err, st) => '—',
      data: (series) {
        final raw =
            config.useTotal ? series.stats.total : series.stats.average;
        if (raw == 0.0) return '—';
        // Whole-number metrics (steps, kcal) shown without decimals.
        if (raw == raw.truncateToDouble() && raw < 100000) {
          return raw.toInt().toString();
        }
        return raw.toStringAsFixed(1);
      },
    );

    return GestureDetector(
      onTap: () => GoRouter.of(context).go('/dashboard/${config.category.name}'),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
          border: Border(
            left: BorderSide(color: config.accentColor, width: 3),
            top: isDark
                ? BorderSide(color: Theme.of(context).colorScheme.outline)
                : BorderSide.none,
            right: isDark
                ? BorderSide(color: Theme.of(context).colorScheme.outline)
                : BorderSide.none,
            bottom: isDark
                ? BorderSide(color: Theme.of(context).colorScheme.outline)
                : BorderSide.none,
          ),
          boxShadow: isDark ? null : AppDimens.cardShadowLight,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceSm,
          vertical: AppDimens.spaceXs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Accent icon badge ──────────────────────────────────────────
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: config.accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                config.icon,
                color: config.accentColor,
                size: AppDimens.iconSm,
              ),
            ),
            const SizedBox(width: AppDimens.spaceXs),

            // ── Value + label column ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Value row with unit.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          displayValue,
                          style: AppTextStyles.h3.copyWith(color: textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        config.unit,
                        style: AppTextStyles.labelXs.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    config.label,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact Insight Strip ─────────────────────────────────────────────────────

/// A compact, left-border accent insight strip that replaces the heavy
/// gradient InsightCard hero for the redesigned dashboard layout.
///
/// Uses a 3px left border in [AppColors.primary] with an italic insight
/// snippet. Tapping navigates to the chat screen.
///
/// Parameters:
///   insight: The AI-generated insight to display.
///   onTap:   Callback to navigate to the chat screen.
class _CompactInsightStrip extends StatelessWidget {
  /// Creates a [_CompactInsightStrip].
  const _CompactInsightStrip({required this.insight, this.onTap});

  /// The AI-generated insight.
  final DashboardInsight insight;

  /// Called when the strip is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppColors.primary,
              width: _kInsightBorderWidth,
            ),
          ),
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(AppDimens.radiusSm),
            bottomRight: Radius.circular(AppDimens.radiusSm),
          ),
        ),
        child: Row(
          children: [
            // AI sparkle icon.
            Icon(
              Icons.auto_awesome_rounded,
              size: AppDimens.iconSm,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppDimens.spaceSm),
            // Italic insight text.
            Expanded(
              child: Text(
                insight.insight,
                style: AppTextStyles.body.copyWith(
                  color: cs.onSurface,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppDimens.spaceXs),
            // Chevron tap hint.
            Icon(
              Icons.chevron_right_rounded,
              size: AppDimens.iconMd,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Insight Strip Shimmer ─────────────────────────────────────────────────────

/// Loading placeholder for [_CompactInsightStrip].
class _InsightStripShimmer extends StatelessWidget {
  /// Creates an [_InsightStripShimmer].
  const _InsightStripShimmer();

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
    );
  }
}
