/// Zuralog Dashboard — Dashboard Screen.
///
/// The hero "Command Center" screen of the Zuralog app.
///
/// Layout order (top → bottom):
///   A) Compact AI Insight strip — left-border accent, italic text, tap to chat.
///   B) Hero row — ActivityRings (left, ~130 px) + 3 key stats (right column).
///   C) 2-column bento metric grid with 7-day sparklines.
///   D) Connected-apps IntegrationsRail at the very bottom.
///
/// Data is sourced from three Riverpod providers:
///   - [dailySummaryProvider]     — today's aggregated health metrics.
///   - [weeklyTrendsProvider]     — 7-day sparkline data.
///   - [dashboardInsightProvider] — AI-generated natural-language insight.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/analytics/domain/analytics_providers.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/analytics/domain/dashboard_insight.dart';
import 'package:zuralog/features/analytics/domain/daily_summary.dart';
import 'package:zuralog/features/analytics/domain/weekly_trends.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/activity_rings.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/integrations_rail.dart';
import 'package:zuralog/features/dashboard/presentation/widgets/metric_card.dart';
import 'package:zuralog/shared/widgets/profile_avatar_button.dart';

// ── Internal constants ────────────────────────────────────────────────────────

/// Left-border accent thickness on the compact insight strip.
const double _kInsightBorderWidth = 3.0;

// ── Screen ────────────────────────────────────────────────────────────────────

/// The main Dashboard screen — the app's command centre.
///
/// Uses a [CustomScrollView] with a floating [SliverAppBar] header and a
/// [SliverList] body.  All async data sections use `.when(data:, loading:,
/// error:)` to handle loading states gracefully.
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
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
                child: _buildHeader(context, ref, profile?.aiName ?? '...'),
              ),
            ),
          ),

          // ── Main Content ────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // A) Compact AI Insight strip
                insightAsync.when(
                  data: (insight) => _CompactInsightStrip(
                    insight: insight,
                    onTap: () =>
                        StatefulNavigationShell.of(context).goBranch(1),
                  ),
                  loading: () => const _InsightStripShimmer(),
                  error: (e, _) => _CompactInsightStrip(
                    insight: const DashboardInsight(
                      insight:
                          'Tap to chat with your AI coach for today\'s insight.',
                    ),
                    onTap: () =>
                        StatefulNavigationShell.of(context).goBranch(1),
                  ),
                ),

                const SizedBox(height: AppDimens.spaceLg),

                // B) Hero row — rings + key stats side-by-side
                summaryAsync.when(
                  data: (summary) => _HeroRow(summary: summary),
                  loading: () => const _HeroRowShimmer(),
                  error: (e, _) => const SizedBox.shrink(),
                ),

                // B2) Quick stat chips — workouts, nutrition, sleep quality
                summaryAsync.when(
                  data: (summary) => _QuickStatChips(summary: summary),
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
                ),

                const SizedBox(height: AppDimens.spaceLg),

                // C) Metrics grid — requires both summary and trends
                _buildMetricsGrid(context, summaryAsync, trendsAsync),

                const SizedBox(height: AppDimens.spaceLg),

                // D) Connected-apps rail at the very bottom
                IntegrationsRail(
                  // goBranch(2) switches to the Integrations tab.
                  onManageTap: () =>
                      StatefulNavigationShell.of(context).goBranch(2),
                ),

                // E) Bottom padding for nav bar clearance
                const SizedBox(height: AppDimens.spaceXxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  /// Builds the top greeting header row.
  ///
  /// Shows a time-sensitive greeting on the left and a profile avatar on the
  /// right.  Tapping the avatar navigates to the settings screen.
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
              style: AppTextStyles.h2.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),

        const Spacer(),

        // Right: profile avatar — opens side panel
        const ProfileAvatarButton(),
      ],
    );
  }

  // ── Metrics grid ─────────────────────────────────────────────────────────────

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

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Formats an integer with comma thousands separators (e.g., 8432 → "8,432").
  String _formatNumber(int n) {
    if (n < 1000) return '$n';
    final thousands = n ~/ 1000;
    final remainder = n % 1000;
    return '$thousands,${remainder.toString().padLeft(3, '0')}';
  }
}

// ── Hero Row ──────────────────────────────────────────────────────────────────

/// Compact hero row that shows the activity rings on the left and the three
/// key stats (Steps / Sleep / Calories Burned) in a stacked column on the
/// right.  This ensures the most important data is visible without scrolling.
///
/// Parameters:
///   summary: Today's aggregated health metrics.
class _HeroRow extends StatelessWidget {
  /// Creates a [_HeroRow] for [summary].
  const _HeroRow({required this.summary});

  /// Today's aggregated health metrics.
  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Activity Rings (left) ───────────────────────────────────────────
        // Constrained to ringDiameter width so the rings circle fits neatly
        // in the left portion of the hero row.
        SizedBox(
          width: AppDimens.ringDiameter,
          child: ActivityRings(
            showPillRow: false,
            rings: [
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
            ],
          ),
        ),

        const SizedBox(width: AppDimens.spaceMd),

        // ── Key stats column (right) ────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _KeyStatRow(
                icon: Icons.directions_walk_rounded,
                color: AppColors.primary,
                label: 'Steps',
                value: _formatSteps(summary.steps),
                unit: 'steps',
              ),
              const SizedBox(height: AppDimens.spaceSm),
              _KeyStatRow(
                icon: Icons.bedtime_rounded,
                color: AppColors.secondaryLight,
                label: 'Sleep',
                value: summary.sleepHours.toStringAsFixed(1),
                unit: 'hrs',
              ),
              const SizedBox(height: AppDimens.spaceSm),
              _KeyStatRow(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.accentLight,
                label: 'Calories',
                value: '${summary.caloriesBurned}',
                unit: 'kcal',
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Formats step count with comma separator.
  static String _formatSteps(int n) {
    if (n < 1000) return '$n';
    final thousands = n ~/ 1000;
    final remainder = n % 1000;
    return '$thousands,${remainder.toString().padLeft(3, '0')}';
  }
}

// ── Key Stat Row ──────────────────────────────────────────────────────────────

/// A single stat row inside the [_HeroRow] right column.
///
/// Shows a coloured icon, a bold value + unit, and a muted label.
///
/// Parameters:
///   icon:  Material icon glyph.
///   color: Accent colour for the icon and value text.
///   label: Human-readable metric name (e.g. `'Steps'`).
///   value: Formatted current value (e.g. `'8,432'`).
///   unit:  Unit abbreviation (e.g. `'steps'`).
class _KeyStatRow extends StatelessWidget {
  /// Creates a [_KeyStatRow].
  const _KeyStatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
  });

  /// Icon glyph.
  final IconData icon;

  /// Accent colour.
  final Color color;

  /// Metric label.
  final String label;

  /// Formatted value string.
  final String value;

  /// Unit abbreviation.
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Coloured icon in a small tinted circle.
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: AppDimens.iconSm),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value $unit',
                style: AppTextStyles.h3.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Hero Row Shimmer ──────────────────────────────────────────────────────────

/// Placeholder rendered while [dailySummaryProvider] is loading.
class _HeroRowShimmer extends StatelessWidget {
  /// Creates a [_HeroRowShimmer].
  const _HeroRowShimmer();

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Row(
      children: [
        // Rings placeholder circle.
        Container(
          width: AppDimens.ringDiameter,
          height: AppDimens.ringDiameter,
          decoration: BoxDecoration(
            color: surface.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppDimens.spaceMd),
        // Stats placeholder bars.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(3, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ── Compact Insight Strip ─────────────────────────────────────────────────────

/// A compact, left-border accent insight strip that replaces the heavy
/// gradient [InsightCard] hero for the redesigned dashboard layout.
///
/// Uses a 3px left border in [AppColors.primary] with an italic insight
/// snippet.  Tapping navigates to the chat screen.
///
/// Parameters:
///   insight: The AI-generated insight to display.
///   onTap:   Callback to navigate to the chat screen.
class _CompactInsightStrip extends StatelessWidget {
  /// Creates a [_CompactInsightStrip].
  const _CompactInsightStrip({
    required this.insight,
    this.onTap,
  });

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

// ── Quick Stat Chips ──────────────────────────────────────────────────────────

/// A compact horizontal strip of cardiovascular stat chips below the hero row.
///
/// Shows three metrics that are distinct from the hero rings and right-column
/// stats (steps/sleep/calories), focusing on heart-health signals:
///   - Resting Heart Rate (RHR) in bpm.
///   - Heart Rate Variability (HRV) in ms.
///   - Cardio Fitness Level (VO2 max estimate) in mL/kg/min.
///
/// Displays `'—'` for any field that has not yet been reported by the device.
///
/// Parameters:
///   summary: Today's aggregated health metrics.
class _QuickStatChips extends StatelessWidget {
  /// Creates a [_QuickStatChips] strip.
  const _QuickStatChips({required this.summary});

  /// Today's aggregated health metrics.
  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.surfaceDark.withValues(alpha: 0.6)
        : AppColors.surfaceLight.withValues(alpha: 0.8);

    final rhr = summary.restingHeartRate != null
        ? '${summary.restingHeartRate} bpm'
        : '—';

    final hrv = summary.hrv != null
        ? '${summary.hrv!.toStringAsFixed(0)} ms'
        : '—';

    final cardio = summary.cardioFitnessLevel != null
        ? '${summary.cardioFitnessLevel!.toStringAsFixed(1)} mL/kg'
        : '—';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatChip(
            icon: Icons.favorite_rounded,
            label: 'Resting HR',
            value: rhr,
            bgColor: bgColor,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          // HRV: Android=RMSSD, iOS=SDNN — different metrics, displayed under
          // same label. Subtitle clarifies which metric is shown per platform.
          _StatChip(
            icon: Icons.monitor_heart_outlined,
            label: 'HRV',
            value: hrv,
            bgColor: bgColor,
            subtitle: Platform.isAndroid ? 'RMSSD' : 'SDNN',
          ),
          const SizedBox(width: AppDimens.spaceSm),
          _StatChip(
            icon: Icons.directions_run_rounded,
            label: 'Cardio Fitness',
            value: cardio,
            bgColor: bgColor,
          ),
        ],
      ),
    );
  }
}

// ── Stat Chip ─────────────────────────────────────────────────────────────────

/// A single chip in the [_QuickStatChips] strip.
///
/// Displays an icon, a bold value, a muted label, and an optional subtitle
/// (e.g. a platform-specific metric qualifier) in a compact rounded card.
class _StatChip extends StatelessWidget {
  /// Creates a [_StatChip].
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.bgColor,
    this.subtitle,
  });

  /// Icon glyph.
  final IconData icon;

  /// Human-readable metric name.
  final String label;

  /// Formatted value string.
  final String value;

  /// Background fill colour for the chip.
  final Color bgColor;

  /// Optional qualifier shown below the [label] in a lighter style.
  ///
  /// Useful for platform-specific metric names (e.g. `'RMSSD'` on Android,
  /// `'SDNN'` on iOS). Omit or pass `null` to hide the subtitle row.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        border: Border.all(
          color: cs.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppDimens.iconSm, color: cs.onSurfaceVariant),
          const SizedBox(width: AppDimens.spaceXs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: AppTextStyles.caption.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 9,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ],
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
