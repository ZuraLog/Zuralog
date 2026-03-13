/// Insight Detail Screen — pushed from Today Feed.
///
/// Full-screen explanation of a single AI insight: charts, data sources,
/// AI reasoning, and "Discuss with Coach" action.
///
/// Full implementation: Phase 3, Task 3.2.
/// Design elevation: Phase 3 elevation pass — editorial animations & micro-interactions.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/haptics/haptic_providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/theme/category_colors.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── InsightDetailScreen ───────────────────────────────────────────────────────

/// Full-screen insight detail with charts, AI reasoning, and sources.
///
/// Navigated to via a named push route; uses a slide-up transition defined
/// in [AppRouter]. The [insightId] is read from the route path parameter.
class InsightDetailScreen extends ConsumerStatefulWidget {
  /// Creates an [InsightDetailScreen] for the given [insightId].
  const InsightDetailScreen({super.key, required this.insightId});

  /// The ID of the insight to display.
  final String insightId;

  @override
  ConsumerState<InsightDetailScreen> createState() =>
      _InsightDetailScreenState();
}

class _InsightDetailScreenState extends ConsumerState<InsightDetailScreen> {
  bool _viewEventFired = false;

  @override
  void initState() {
    super.initState();
    // Mark as read when opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(todayRepositoryProvider)
          .markInsightRead(widget.insightId)
          .catchError((Object e, StackTrace _) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(insightDetailProvider(widget.insightId));

    // Fire viewed event once when detail data is first available.
    detailAsync.whenOrNull(data: (detail) {
      if (!_viewEventFired) {
        _viewEventFired = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(analyticsServiceProvider).capture(
            event: AnalyticsEvents.insightDetailViewed,
            properties: {
              'insight_id': widget.insightId,
              'insight_type': detail.type.name,
              'category': detail.category,
            },
          );
          // First-use guard.
          SharedPreferences.getInstance().then((prefs) {
            if (prefs.getBool('analytics_first_insight_viewed') != true) {
              prefs.setBool('analytics_first_insight_viewed', true);
              ref.read(analyticsServiceProvider).capture(
                event: AnalyticsEvents.firstInsightViewed,
              );
            }
          });
        });
      }
    });

    return ZuralogScaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Theme.of(context).colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: detailAsync.whenOrNull(
          data: (detail) => Text(
            _categoryLabel(detail.category),
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      body: detailAsync.when(
        data: (detail) => _DetailBody(detail: detail),
        loading: () => const _DetailSkeleton(),
        error: (e, _) => _DetailError(
          onRetry: () =>
              ref.invalidate(insightDetailProvider(widget.insightId)),
        ),
      ),
    );
  }
}

// ── _DetailBody ───────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});

  final InsightDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final categoryColor = categoryColorFromString(detail.category);

    return CustomScrollView(
        slivers: [
        // ── Header: full-bleed category gradient wash + title ─────────────
        SliverToBoxAdapter(
          child: ZFadeSlideIn(
            delay: Duration.zero,
            child: Stack(
              children: [
                // Edge-to-edge category-color gradient wash (10% opacity).
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            categoryColor.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceSm,
                    AppDimens.spaceMd,
                    AppDimens.spaceMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ZIconBadge(
                            icon: _insightIcon(detail.type),
                            color: categoryColor,
                            size: 48,
                            iconSize: 24,
                          ),
                          const SizedBox(width: AppDimens.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        categoryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppDimens.radiusChip,
                                    ),
                                  ),
                                  child: Text(
                                    _insightTypeLabel(detail.type),
                                     style: AppTextStyles.labelSmall.copyWith(
                                      color: categoryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      Text(
                        detail.title,
                        style: AppTextStyles.displayLarge.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      Text(
                        detail.summary,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Chart ─────────────────────────────────────────────────────────
        if (detail.dataPoints.isNotEmpty)
          SliverToBoxAdapter(
            child: ZFadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceSm,
                ),
                child: _InsightChart(
                  detail: detail,
                  categoryColor: categoryColor,
                ),
              ),
            ),
          ),

        // ── AI Reasoning ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: ZFadeSlideIn(
            delay: const Duration(milliseconds: 130),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: Text(
                'AI Analysis',
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: ZFadeSlideIn(
            delay: const Duration(milliseconds: 160),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
              ),
              // Sage-green left border stripe on reasoning card.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(AppDimens.spaceMd),
                        decoration: BoxDecoration(
                          color: colors.cardBackground,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusCard,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.psychology_outlined,
                                  size: AppDimens.iconMd,
                                  color:
                                      colors.primary.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: AppDimens.spaceSm),
                                 Text(
                                   'Reasoning',
                                   style: AppTextStyles.bodySmall.copyWith(
                                     color: colors.textSecondary,
                                     fontWeight: FontWeight.w600,
                                   ),
                                 ),
                               ],
                             ),
                             const SizedBox(height: AppDimens.spaceSm),
                             Text(
                               detail.reasoning.isNotEmpty
                                   ? detail.reasoning
                                   : 'This insight was generated from your recent health data.',
                               style: AppTextStyles.bodyLarge.copyWith(
                                 color: colors.textPrimary,
                                 height: 1.55,
                               ),
                             ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Data Sources ──────────────────────────────────────────────────
        if (detail.sources.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: ZFadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceLg,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: Text(
                  'Data Sources',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ZFadeSlideIn(
              delay: const Duration(milliseconds: 220),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: Wrap(
                  spacing: AppDimens.spaceSm,
                  runSpacing: AppDimens.spaceSm,
                  children: [
                    for (final src in detail.sources) _SourceChip(source: src),
                  ],
                ),
              ),
            ),
          ),
        ],

        // ── Discuss with Coach CTA ─────────────────────────────────────
        SliverToBoxAdapter(
          child: ZFadeSlideIn(
            delay: const Duration(milliseconds: 260),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceXxl,
              ),
              child: _PressScaleButton(
                onPressed: () {
                  ref.read(hapticServiceProvider).medium();
                  ref.read(analyticsServiceProvider).capture(
                    event: AnalyticsEvents.insightDetailCoachTapped,
                    properties: {
                      'insight_id': detail.id,
                      'insight_type': detail.type.name,
                    },
                  );
                  final prefill = 'I\'d like to discuss this insight: ${detail.title}'.length > 500
                      ? 'I\'d like to discuss this insight: ${detail.title}'.substring(0, 500)
                      : 'I\'d like to discuss this insight: ${detail.title}';
                  ref.read(coachPrefillProvider.notifier).state = prefill;
                  context.go(RouteNames.coachPath);
                },
                child: FilledButton.icon(
                  onPressed: null, // handled by _PressScaleButton
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                  ),
                  label: const Text('Discuss with Coach'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: AppColors.primaryButtonText,
                    disabledBackgroundColor: colors.primary,
                    disabledForegroundColor: AppColors.primaryButtonText,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ],
      );
  }
}

// ── _PressScaleButton ─────────────────────────────────────────────────────────

/// Wraps any widget with a spring press-scale effect.
class _PressScaleButton extends StatelessWidget {
  const _PressScaleButton({required this.child, required this.onPressed});

  final Widget child;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ZuralogSpringButton(
      onTap: onPressed,
      child: child,
    );
  }
}

// ── _InsightChart ─────────────────────────────────────────────────────────────

/// Bar chart rendered from [InsightDetail.dataPoints].
class _InsightChart extends StatelessWidget {
  const _InsightChart({
    required this.detail,
    required this.categoryColor,
  });

  final InsightDetail detail;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final points = detail.dataPoints;
    final maxY = points.map((p) => p.value).reduce(math.max) * 1.2;

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.chartTitle != null) ...[
            Text(
              detail.chartTitle!,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: colors.border.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            points[idx].label,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].value,
                          color: categoryColor,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            color: categoryColor.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                ],
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colors.surface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final unit = detail.chartUnit ?? '';
                      return BarTooltipItem(
                        '${rod.toY.toStringAsFixed(1)} $unit',
                        AppTextStyles.bodySmall.copyWith(
                          color: colors.textPrimary,
                        ),
                      );
                    },
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 400),
            ),
          ),
          if (detail.chartUnit != null) ...[
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              detail.chartUnit!,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── _SourceChip ───────────────────────────────────────────────────────────────

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});

  final InsightSource source;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _sourceIcon(source.iconName),
            size: 14,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            source.name,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _DetailSkeleton ───────────────────────────────────────────────────────────

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ZLoadingSkeleton(width: 200, height: 34),
          const SizedBox(height: AppDimens.spaceMd),
          const ZLoadingSkeleton(width: double.infinity, height: 16),
          const SizedBox(height: 8),
          const ZLoadingSkeleton(width: 280, height: 16),
          const SizedBox(height: AppDimens.spaceLg),
          const ZLoadingSkeleton(width: double.infinity, height: 180),
          const SizedBox(height: AppDimens.spaceLg),
          const ZLoadingSkeleton(width: 120, height: 18),
          const SizedBox(height: AppDimens.spaceSm),
          const ZLoadingSkeleton(width: double.infinity, height: 100),
        ],
      ),
    );
  }
}

// ── _DetailError ──────────────────────────────────────────────────────────────

class _DetailError extends StatelessWidget {
  const _DetailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Could not load insight',
            style: AppTextStyles.titleMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Try again',
              style: AppTextStyles.bodyLarge.copyWith(color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Returns a display label for an [InsightType].
String _insightTypeLabel(InsightType type) {
  switch (type) {
    case InsightType.anomaly:
      return 'Anomaly';
    case InsightType.correlation:
      return 'Correlation';
    case InsightType.trend:
      return 'Trend';
    case InsightType.recommendation:
      return 'Recommendation';
    case InsightType.achievement:
      return 'Achievement';
    case InsightType.unknown:
      return 'Insight';
  }
}

/// Returns the title-cased category label.
String _categoryLabel(String category) =>
    category.isEmpty
        ? 'Health'
        : category[0].toUpperCase() + category.substring(1);

/// Returns an icon for the given [InsightType].
IconData _insightIcon(InsightType type) {
  switch (type) {
    case InsightType.anomaly:
      return Icons.warning_amber_rounded;
    case InsightType.correlation:
      return Icons.compare_arrows_rounded;
    case InsightType.trend:
      return Icons.trending_up_rounded;
    case InsightType.recommendation:
      return Icons.tips_and_updates_rounded;
    case InsightType.achievement:
      return Icons.emoji_events_rounded;
    case InsightType.unknown:
      return Icons.lightbulb_outline_rounded;
  }
}

/// Returns a material icon for an integration source icon name.
IconData _sourceIcon(String iconName) {
  switch (iconName.toLowerCase()) {
    case 'apple_health':
      return Icons.favorite_rounded;
    case 'strava':
      return Icons.directions_run_rounded;
    case 'fitbit':
      return Icons.watch_rounded;
    case 'garmin':
      return Icons.gps_fixed_rounded;
    case 'whoop':
      return Icons.monitor_heart_rounded;
    case 'oura':
      return Icons.ring_volume_rounded;
    default:
      return Icons.device_hub_rounded;
  }
}
