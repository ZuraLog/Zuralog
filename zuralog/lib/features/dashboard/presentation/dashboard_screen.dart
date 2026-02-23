/// Zuralog Dashboard — Dashboard Screen.
///
/// The hero "Command Center" screen of the Zuralog app.
/// Displays a greeting header, an AI insight card, Apple Health-style activity
/// rings, a connected-apps integration rail, and a 2-column bento-grid of
/// metric cards with 7-day sparkline trends.
///
/// Data is sourced from three Riverpod providers:
/// - [dailySummaryProvider] — today's aggregated health metrics.
/// - [weeklyTrendsProvider] — 7-day sparkline data.
/// - [dashboardInsightProvider] — AI-generated natural-language insight.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/analytics/domain/analytics_providers.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/analytics/domain/dashboard_insight.dart';
import 'package:zuralog/features/analytics/domain/daily_summary.dart';
import 'package:zuralog/features/analytics/domain/weekly_trends.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/activity_rings.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/insight_card.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/integrations_rail.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/metric_card.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

/// The main Dashboard screen — the app's command centre.
///
/// Uses a [CustomScrollView] with a floating [SliverAppBar] header and a
/// [SliverList] body containing all dashboard content sections.
///
/// All async data sections use `.when(data:, loading:, error:)` to handle
/// network/cache loading states gracefully.
class DashboardScreen extends ConsumerWidget {
  /// Creates a [DashboardScreen].
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightAsync = ref.watch(dashboardInsightProvider);
    final summaryAsync = ref.watch(dailySummaryProvider);
    final trendsAsync = ref.watch(weeklyTrendsProvider);
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Floating App Bar ──────────────────────────────────────────
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
                child: _buildHeader(context, profile?.aiName ?? '...'),
              ),
            ),
          ),

          // ── Main Content ──────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // A) AI Insight Card
                insightAsync.when(
                  data: (insight) => InsightCard(
                    insight: insight,
                    // Use goBranch to switch tabs within the StatefulShellRoute
                    // — preserves branch state and avoids replacing the stack.
                    onTap: () => StatefulNavigationShell.of(context).goBranch(1),
                  ),
                  loading: () => const InsightCardShimmer(),
                  error: (e, _) => InsightCard(
                    insight: const DashboardInsight(
                      insight:
                          'Tap to chat with your AI coach for today\'s insight.',
                    ),
                    onTap: () => StatefulNavigationShell.of(context).goBranch(1),
                  ),
                ),

                const SizedBox(height: AppDimens.spaceLg),

                // B) Health Activity Rings
                summaryAsync.when(
                  data: (summary) => Center(
                    child: ActivityRings(
                      rings: _buildRings(summary),
                    ),
                  ),
                  loading: () => Center(
                    child: SizedBox(
                      height: AppDimens.ringDiameter,
                      width: AppDimens.ringDiameter,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                  error: (e, _) => const SizedBox.shrink(),
                ),

                const SizedBox(height: AppDimens.spaceLg),

                // C) Integrations Rail
                IntegrationsRail(
                  // goBranch(2) switches to the Integrations tab within
                  // the StatefulShellRoute without replacing the stack.
                  onManageTap: () =>
                      StatefulNavigationShell.of(context).goBranch(2),
                ),

                const SizedBox(height: AppDimens.spaceLg),

                // D) Metrics Grid — requires both summary and trends
                _buildMetricsGrid(context, summaryAsync, trendsAsync),

                // E) Bottom padding for nav bar clearance
                const SizedBox(height: AppDimens.spaceXxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  /// Builds the top greeting header row.
  ///
  /// Shows a time-sensitive greeting on the left and a profile avatar on the
  /// right. Tapping the avatar navigates to the settings screen.
  Widget _buildHeader(BuildContext context, String name) {
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
              style: AppTextStyles.h2.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),

        const Spacer(),

        // Right: profile avatar
        GestureDetector(
          onTap: () => context.push(RouteNames.settingsPath),
          child: CircleAvatar(
            radius: AppDimens.avatarMd / 2,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: AppDimens.iconMd,
            ),
          ),
        ),
      ],
    );
  }

  // ── Ring builder ────────────────────────────────────────────────────────────

  /// Converts a [DailySummary] into the three [RingData] entries for [ActivityRings].
  List<RingData> _buildRings(DailySummary summary) {
    return [
      RingData(
        value: summary.steps.toDouble(),
        maxValue: 10000,
        color: AppColors.primary,
        label: 'Steps',
        unit: 'steps',
      ),
      RingData(
        value: summary.sleepHours,
        maxValue: 8.0,
        color: AppColors.secondaryLight,
        label: 'Sleep',
        unit: 'hrs',
      ),
      RingData(
        value: summary.caloriesBurned.toDouble(),
        maxValue: 600,
        color: AppColors.accentLight,
        label: 'Calories',
        unit: 'kcal',
      ),
    ];
  }

  // ── Metrics grid ────────────────────────────────────────────────────────────

  /// Builds the 2-column bento metric grid.
  ///
  /// Requires both [summaryAsync] and [trendsAsync] to be loaded.
  /// Shows a [CircularProgressIndicator] while loading, and falls back to
  /// [SizedBox.shrink] on error.
  Widget _buildMetricsGrid(
    BuildContext context,
    AsyncValue<DailySummary> summaryAsync,
    AsyncValue<WeeklyTrends> trendsAsync,
  ) {
    // Both providers must be ready before rendering the grid.
    if (summaryAsync.isLoading || trendsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppDimens.spaceLg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (summaryAsync.hasError || trendsAsync.hasError) {
      return const SizedBox.shrink();
    }

    final summary = summaryAsync.requireValue;
    final trends = trendsAsync.requireValue;

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppDimens.spaceMd,
        crossAxisSpacing: AppDimens.spaceMd,
        childAspectRatio: 0.9,
      ),
      children: [
        MetricCard(
          title: 'Sleep',
          value: summary.sleepHours.toStringAsFixed(1),
          unit: 'hrs',
          icon: Icons.bedtime_rounded,
          accentColor: AppColors.secondaryLight,
          trendData: trends.sleepHours,
        ),
        MetricCard(
          title: 'Calories Burned',
          value: '${summary.caloriesBurned}',
          unit: 'kcal',
          icon: Icons.local_fire_department_rounded,
          accentColor: AppColors.accentLight,
          trendData: trends.caloriesOut.map((e) => e.toDouble()).toList(),
        ),
        MetricCard(
          title: 'Steps',
          value: _formatNumber(summary.steps),
          unit: 'steps',
          icon: Icons.directions_walk_rounded,
          accentColor: AppColors.primary,
          trendData: trends.steps.map((e) => e.toDouble()).toList(),
        ),
        MetricCard(
          title: 'Nutrition',
          value: '${summary.caloriesConsumed}',
          unit: 'kcal',
          icon: Icons.restaurant_rounded,
          accentColor: AppColors.nutrition,
          trendData: trends.caloriesIn.map((e) => e.toDouble()).toList(),
        ),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Formats an integer with comma thousands separators (e.g., 8432 → "8,432").
  String _formatNumber(int n) {
    if (n < 1000) return '$n';
    final thousands = n ~/ 1000;
    final remainder = n % 1000;
    return '$thousands,${remainder.toString().padLeft(3, '0')}';
  }
}
