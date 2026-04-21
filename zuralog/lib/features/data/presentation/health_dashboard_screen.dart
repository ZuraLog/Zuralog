/// Data tab — editorial health briefing.
///
/// One hero Health Score card on top, followed by six
/// [ZCategorySummaryCard]s in fixed order (Sleep → Activity → Heart →
/// Nutrition → Body → Wellness). Shows a Connect-a-source CTA only when
/// fewer than three of the visible categories have data.
///
/// Keeps two behaviors from the previous masonry version:
/// - Pull-to-refresh runs an Apple Health / Health Connect sync and then
///   invalidates the three providers this screen reads.
/// - A throttled app-launch auto-sync fires once per screen lifecycle via
///   [addPostFrameCallback].
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/widgets/shimmer.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/category_summary.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Visible categories ───────────────────────────────────────────────────────

/// Fixed editorial order for the Data tab's six category cards.
const List<HealthCategory> _kVisibleCategories = [
  HealthCategory.sleep,
  HealthCategory.activity,
  HealthCategory.heart,
  HealthCategory.nutrition,
  HealthCategory.body,
  HealthCategory.wellness,
];

// ── HealthDashboardScreen ─────────────────────────────────────────────────────

/// Data tab root — editorial category briefing.
class HealthDashboardScreen extends ConsumerStatefulWidget {
  /// Creates the [HealthDashboardScreen].
  const HealthDashboardScreen({super.key});

  @override
  ConsumerState<HealthDashboardScreen> createState() =>
      _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends ConsumerState<HealthDashboardScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Fire the throttled app-launch health sync once, after the first frame,
    // so rendering is never blocked on a network round-trip.
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerSyncIfDue());
  }

  // ── Health sync constants ──────────────────────────────────────────────────

  /// SharedPreferences key for the last successful sync timestamp (ms since epoch).
  static const _kLastSyncKey = 'health_last_sync_at';

  /// SharedPreferences key for the Apple Health integration connection flag.
  static const _kAppleHealthKey = 'integration_connected_apple_health';

  /// SharedPreferences key for the Google Health Connect integration connection flag.
  static const _kHealthConnectKey = 'integration_connected_google_health_connect';

  /// Minimum gap between automatic app-launch syncs (prevents hammering the server).
  static const _kSyncThrottleHours = 1;

  // ── App-launch sync ────────────────────────────────────────────────────────

  /// Fires a background health sync if the user has a health integration
  /// connected AND hasn't synced in the last [_kSyncThrottleHours] hour(s).
  ///
  /// Called once per screen lifecycle from [initState] via addPostFrameCallback.
  /// Fire-and-forget — does not block rendering.
  Future<void> _triggerSyncIfDue() async {
    final prefs = await SharedPreferences.getInstance();

    final appleConnected =
        prefs.getBool(_kAppleHealthKey) ?? false;
    final hcConnected =
        prefs.getBool(_kHealthConnectKey) ?? false;
    if (!appleConnected && !hcConnected) return;

    final lastSyncMs = prefs.getInt(_kLastSyncKey);
    if (lastSyncMs != null) {
      final elapsed = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(lastSyncMs));
      if (elapsed.inHours < _kSyncThrottleHours) return;
    }

    // Write the timestamp BEFORE dispatching the sync (not after) so that
    // rapid tab switches or concurrent screen lifecycles cannot fire
    // multiple parallel syncs. A failed sync will extend the throttle
    // window by up to 1 hour, which is an acceptable trade-off.
    await prefs.setInt(_kLastSyncKey, DateTime.now().millisecondsSinceEpoch);

    final syncService = ref.read(healthSyncServiceProvider);
    unawaited(
      syncService.syncToCloud(days: 7).then((success) {
        debugPrint('[HealthDashboard] Auto-sync ${success ? 'succeeded' : 'failed'}');
        if (success && mounted) {
          ref.invalidate(dashboardProvider);
          ref.invalidate(healthScoreProvider);
          ref.invalidate(todayFeedProvider);
        }
      }),
    );
  }

  // ── Pull-to-refresh ────────────────────────────────────────────────────────

  Future<void> _onRefresh() async {
    // Sync latest health data to the server before refreshing screen data.
    final prefs = await SharedPreferences.getInstance();
    final appleConnected = prefs.getBool(_kAppleHealthKey) ?? false;
    final hcConnected = prefs.getBool(_kHealthConnectKey) ?? false;

    if (appleConnected || hcConnected) {
      final syncService = ref.read(healthSyncServiceProvider);
      final synced = await syncService.syncToCloud(days: 7);
      if (synced) {
        await prefs.setInt(
            _kLastSyncKey, DateTime.now().millisecondsSinceEpoch);
      }
      if (!synced && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync failed. Pull down to try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      // Prime the server cache with fresh data before invalidating providers
      // so the next read sees post-sync data instead of the stale in-memory
      // cache on the server.
      await ref
          .read(dataRepositoryProvider)
          .getDashboard(forceRefresh: true);
    }

    ref.invalidate(dashboardProvider);
    ref.invalidate(healthScoreProvider);
    ref.invalidate(todayFeedProvider);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin.

    final colors = AppColorsOf(context);

    return ZuralogScaffold(
      appBar: const ZuralogAppBar(title: 'Data'),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: _onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            0,
          ),
          children: [
            const _HealthScoreHero(),
            const SizedBox(height: AppDimens.spaceMd),
            for (var i = 0; i < _kVisibleCategories.length; i++) ...[
              _CategoryCard(category: _kVisibleCategories[i]),
              if (i < _kVisibleCategories.length - 1)
                const SizedBox(height: AppDimens.spaceSm + 4),
            ],
            const SizedBox(height: AppDimens.spaceMd),
            const _ConnectACTAIfNeeded(),
            SizedBox(
              height: AppDimens.bottomClearance(context) + AppDimens.spaceMd,
            ),
          ],
        ),
      ),
    );
  }
}

// ── _HealthScoreHero ──────────────────────────────────────────────────────────

/// Editorial Health Score hero card — the single largest number on the Data tab.
///
/// Tapping anywhere opens the score breakdown screen. Shows a shimmer skeleton
/// while the score is loading; shows the same skeleton on error so the user
/// can pull-to-refresh without seeing a broken state.
class _HealthScoreHero extends ConsumerWidget {
  const _HealthScoreHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final scoreAsync = ref.watch(healthScoreProvider);

    final Widget content = scoreAsync.when(
      loading: () => const _HeroSkeleton(),
      error: (_, _) => const _HeroSkeleton(),
      data: (data) => _HeroContent(data: data),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(RouteNames.dataScoreBreakdownPath),
      child: ZuralogCard(
        variant: ZCardVariant.hero,
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: DefaultTextStyle(
          style: TextStyle(color: colors.textPrimary),
          child: content,
        ),
      ),
    );
  }
}

// ── _HeroContent ──────────────────────────────────────────────────────────────

class _HeroContent extends StatelessWidget {
  const _HeroContent({required this.data});

  final HealthScoreData data;

  bool get _hasScore => !(data.score == 0 && data.dataDays == 0);

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final scoreText = _hasScore ? '${data.score}' : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow
        Text(
          'Your health · Today',
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textTertiary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        // Lora hero number + delta pill
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                scoreText,
                style: AppTextStyles.displayLarge.copyWith(
                  fontFamily: 'Lora',
                  fontWeight: FontWeight.w600,
                  fontSize: 56,
                  height: 1.0,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_hasScore && data.weekChange != null) ...[
              const SizedBox(width: AppDimens.spaceSm),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _HeroDeltaPill(weekChange: data.weekChange!),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppDimens.spaceSm),
        // Caption
        Text(
          _hasScore ? 'Health Score' : 'Not enough data yet',
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        // Full-width sparkline in Sage
        if (data.trend.length >= 2)
          ZMiniSparkline(
            values: data.trend,
            todayIndex: data.trend.length - 1,
            color: colors.primary,
            height: 48,
          )
        else
          const SizedBox(height: 48),
      ],
    );
  }
}

// ── _HeroDeltaPill ────────────────────────────────────────────────────────────

/// Pill showing this week's score change vs. last week. Same red / green /
/// neutral rules used on the category cards.
class _HeroDeltaPill extends StatelessWidget {
  const _HeroDeltaPill({required this.weekChange});

  final int weekChange;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final Color background;
    final Color foreground;
    final String arrow;
    if (weekChange > 0) {
      background = colors.success.withValues(alpha: 0.14);
      foreground = colors.success;
      arrow = '↑';
    } else if (weekChange < 0) {
      background = colors.warning.withValues(alpha: 0.14);
      foreground = colors.warning;
      arrow = '↓';
    } else {
      background = colors.surfaceRaised;
      foreground = colors.textSecondary;
      arrow = '·';
    }
    final label = weekChange == 0
        ? 'Flat vs last week'
        : '$arrow ${weekChange.abs()} vs last week';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── _HeroSkeleton ─────────────────────────────────────────────────────────────

/// Shimmer placeholder with the same overall footprint as the loaded hero.
class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading health score',
      excludeSemantics: true,
      child: AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(height: 10, width: 120),
            const SizedBox(height: AppDimens.spaceSm),
            ShimmerBox(height: 56, width: 140),
            const SizedBox(height: AppDimens.spaceSm),
            ShimmerBox(height: 12, width: 90),
            const SizedBox(height: AppDimens.spaceMd),
            ShimmerBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ── _CategoryCard ─────────────────────────────────────────────────────────────

/// Single category card — wraps [ZCategorySummaryCard] with the right
/// category-level data pulled from [dashboardProvider] and [todayFeedProvider].
class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({required this.category});

  final HealthCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(dashboardProvider);
    final feedAsync = ref.watch(todayFeedProvider);

    final summary = _findSummary(dashAsync.valueOrNull, category);
    final insight = _findInsight(feedAsync.valueOrNull, category);
    final color = categoryColor(category);
    final icon = _iconFor(category);
    final name = category.displayName;

    final trend = summary?.trend ?? const <double>[];
    final hasData = summary != null &&
        trend.length >= 3 &&
        summary.primaryValue.trim().isNotEmpty &&
        summary.primaryValue != '—';

    final todayValue = _lastNonNull(trend);
    final weekAverage = _average(trend);

    final summaryLine = categorySummaryFor(
      category: category,
      todayValue: todayValue,
      weekAverage: weekAverage,
      aiHeadline: insight?.title,
    );

    final deltaDirection =
        _deltaDirection(category, summary?.deltaPercent);
    final deltaLabel = _deltaLabel(summary?.deltaPercent);

    return ZCategorySummaryCard(
      categoryName: name,
      icon: icon,
      color: color,
      heroValue: hasData ? summary.primaryValue : '—',
      summaryLine: hasData ? summaryLine : 'No data yet.',
      trend: trend,
      todayIndex: trend.isNotEmpty ? trend.length - 1 : -1,
      deltaLabel: hasData ? deltaLabel : null,
      deltaDirection: deltaDirection,
      isNoData: !hasData,
      onTap: () => context.push('/data/category/${category.name}'),
      onConnectTap: () =>
          context.push(RouteNames.settingsIntegrationsPath),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static CategorySummary? _findSummary(
      DashboardData? dash, HealthCategory cat) {
    if (dash == null) return null;
    for (final s in dash.categories) {
      if (s.category == cat) return s;
    }
    return null;
  }

  /// Returns the first insight whose category slug matches [cat.name].
  /// Insight titles are already plain-English, so we use them verbatim as the
  /// summary line when available.
  static InsightCard? _findInsight(TodayFeedData? feed, HealthCategory cat) {
    if (feed == null) return null;
    final slug = cat.name;
    for (final insight in feed.insights) {
      if (insight.category.toLowerCase() == slug) return insight;
    }
    return null;
  }

  static double? _lastNonNull(List<double> values) {
    for (var i = values.length - 1; i >= 0; i--) {
      if (values[i] > 0) return values[i];
    }
    return null;
  }

  static double? _average(List<double> values) {
    final nonZero = values.where((v) => v > 0).toList();
    if (nonZero.isEmpty) return null;
    return nonZero.reduce((a, b) => a + b) / nonZero.length;
  }

  /// Resting heart rate is the one category in this six-card set where lower
  /// is better, so we flip the direction there.
  static ZCategoryDelta _deltaDirection(
      HealthCategory cat, double? deltaPercent) {
    if (deltaPercent == null) return ZCategoryDelta.none;
    final lowerIsBetter = cat == HealthCategory.heart;
    if (deltaPercent.abs() < 1.0) return ZCategoryDelta.flat;
    final isUp = deltaPercent > 0;
    final isBetter = lowerIsBetter ? !isUp : isUp;
    return isBetter ? ZCategoryDelta.better : ZCategoryDelta.worse;
  }

  static String? _deltaLabel(double? deltaPercent) {
    if (deltaPercent == null) return null;
    final arrow = deltaPercent > 0
        ? '↑'
        : (deltaPercent < 0 ? '↓' : '·');
    final pct = deltaPercent.abs().round();
    if (pct == 0) return 'Flat vs last week';
    return '$arrow $pct% vs last week';
  }

  static IconData _iconFor(HealthCategory cat) {
    switch (cat) {
      case HealthCategory.sleep:
        return Icons.bedtime_rounded;
      case HealthCategory.activity:
        return Icons.directions_walk_rounded;
      case HealthCategory.heart:
        return Icons.favorite_rounded;
      case HealthCategory.nutrition:
        return Icons.local_fire_department_rounded;
      case HealthCategory.body:
        return Icons.accessibility_new_rounded;
      case HealthCategory.wellness:
        return Icons.self_improvement_rounded;
      // Defensive fallback — the six visible categories never hit these
      // branches, but the switch must be exhaustive.
      case HealthCategory.vitals:
        return Icons.monitor_heart_rounded;
      case HealthCategory.cycle:
        return Icons.calendar_today_rounded;
      case HealthCategory.mobility:
        return Icons.directions_run_rounded;
      case HealthCategory.environment:
        return Icons.wb_sunny_rounded;
    }
  }
}

// ── _ConnectACTAIfNeeded ──────────────────────────────────────────────────────

/// Renders a "Connect a source" feature card only when fewer than three of
/// the six visible categories have usable data. Hidden once the user has
/// enough data flowing to fill out the page.
class _ConnectACTAIfNeeded extends ConsumerWidget {
  const _ConnectACTAIfNeeded();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(dashboardProvider);
    final dash = dashAsync.valueOrNull;
    final withData = _countWithData(dash);
    if (withData >= 3) return const SizedBox.shrink();

    final colors = AppColorsOf(context);
    return ZuralogCard(
      variant: ZCardVariant.feature,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect a source',
            style: AppTextStyles.titleMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'Link Apple Health, Health Connect, or a wearable to see your full picture.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          ZPatternPillButton(
            icon: Icons.add_rounded,
            label: 'Connect a source',
            onPressed: () =>
                context.push(RouteNames.settingsIntegrationsPath),
          ),
        ],
      ),
    );
  }

  static int _countWithData(DashboardData? dash) {
    if (dash == null) return 0;
    var count = 0;
    for (final cat in _kVisibleCategories) {
      final summary = dash.categories.firstWhere(
        (s) => s.category == cat,
        orElse: () => const CategorySummary(
          category: HealthCategory.activity,
          primaryValue: '',
          trend: null,
        ),
      );
      final trend = summary.trend ?? const <double>[];
      final hasValue = summary.primaryValue.trim().isNotEmpty &&
          summary.primaryValue != '—';
      if (trend.length >= 3 && hasValue) count++;
    }
    return count;
  }
}
