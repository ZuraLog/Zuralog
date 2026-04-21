/// All Data — long-form magazine spread across every health category.
///
/// One scrollable document that reads like a premium wellness report.
/// Anatomy, top → bottom:
///   1. Transparent [ZuralogAppBar] with back chevron.
///   2. Intro hero with eyebrow, Lora title and one-line body.
///   3. Sticky table-of-contents chips row (one per category).
///   4. Six chapters — Sleep → Activity → Heart → Nutrition → Body →
///      Wellness. Each chapter has a full-bleed banner, optional AI
///      summary, hero + primary chart + signature visual, stats grid,
///      and every metric inline with description, chart and Avg · Min ·
///      Max strip.
///   5. Footer with the generation date and a "Share this report" stub.
///
/// This screen composes every shared primitive already used on the Data
/// tab — it does not create any new ones.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/unit_converter.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/features/heart/domain/heart_models.dart';
import 'package:zuralog/features/heart/providers/heart_providers.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart'
    show UnitsSystem;
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/sleep/domain/sleep_models.dart';
import 'package:zuralog/features/sleep/providers/sleep_providers.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_hero_card.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_primary_chart.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_stats_grid.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Chapter order & params ───────────────────────────────────────────────────

const List<HealthCategory> _kChapterOrder = [
  HealthCategory.sleep,
  HealthCategory.activity,
  HealthCategory.heart,
  HealthCategory.nutrition,
  HealthCategory.body,
  HealthCategory.wellness,
];

String _chapterTagline(HealthCategory cat) {
  switch (cat) {
    case HealthCategory.sleep:
      return 'How you rested last night and across the week';
    case HealthCategory.activity:
      return 'How you moved today and this week';
    case HealthCategory.heart:
      return "How your heart's doing today";
    case HealthCategory.nutrition:
      return 'What you ate and when';
    case HealthCategory.body:
      return "How your body's composition is trending";
    case HealthCategory.wellness:
      return 'How you felt this week';
    default:
      return '';
  }
}

IconData _chapterIcon(HealthCategory cat) {
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
    default:
      return Icons.auto_graph_rounded;
  }
}

ZPatternVariant _chapterPatternVariant(HealthCategory cat) {
  switch (cat) {
    case HealthCategory.sleep:
      return ZPatternVariant.periwinkle;
    case HealthCategory.activity:
      return ZPatternVariant.green;
    case HealthCategory.heart:
      return ZPatternVariant.rose;
    case HealthCategory.nutrition:
      return ZPatternVariant.amber;
    case HealthCategory.body:
      return ZPatternVariant.skyBlue;
    case HealthCategory.wellness:
      return ZPatternVariant.purple;
    default:
      return ZPatternVariant.original;
  }
}

// ── AllDataScreen ────────────────────────────────────────────────────────────

/// The All Data screen — renders every metric across every category in
/// one long, editorial scroll.
class AllDataScreen extends ConsumerStatefulWidget {
  /// Creates the [AllDataScreen].
  const AllDataScreen({super.key});

  @override
  ConsumerState<AllDataScreen> createState() => _AllDataScreenState();
}

class _AllDataScreenState extends ConsumerState<AllDataScreen> {
  final ScrollController _scrollController = ScrollController();

  /// One anchor key per chapter so we can scroll to it from the TOC.
  final Map<HealthCategory, GlobalKey> _chapterKeys = {
    for (final c in _kChapterOrder) c: GlobalKey(),
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToChapter(HealthCategory cat) {
    final key = _chapterKeys[cat];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final unitsSystem = ref.watch(unitsSystemProvider);

    return ZuralogScaffold(
      appBar: ZuralogAppBar(
        title: 'All Data',
        showProfileAvatar: false,
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          const SliverToBoxAdapter(child: _IntroHero()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTocHeader(
              onTap: _scrollToChapter,
              backgroundColor: colors.canvas,
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimens.spaceMd),
          ),
          for (final cat in _kChapterOrder)
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: _chapterKeys[cat],
                child: _Chapter(category: cat, unitsSystem: unitsSystem),
              ),
            ),
          const SliverToBoxAdapter(child: _ReportFooter()),
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppDimens.bottomClearance(context) + AppDimens.spaceMd,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _IntroHero ───────────────────────────────────────────────────────────────

/// Editorial opener. Eyebrow + serif Lora title + one-line body, with a
/// very subtle animated pattern behind.
class _IntroHero extends StatelessWidget {
  const _IntroHero();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: ZPatternOverlay(
              variant: ZPatternVariant.original,
              opacity: 0.06,
              animate: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceLg,
              AppDimens.spaceMd,
              AppDimens.spaceMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'YOUR COMPLETE HEALTH PICTURE · TODAY',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.textTertiary,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'Everything you track, in one place.',
                  style: AppTextStyles.displayLarge.copyWith(
                    fontFamily: 'Lora',
                    fontWeight: FontWeight.w600,
                    fontSize: 34,
                    height: 1.15,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'A full report of every metric across every category '
                  '— scroll through the six chapters, or jump straight '
                  'to what you need.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _StickyTocHeader ─────────────────────────────────────────────────────────

/// Sticky sliver header holding the horizontally-scrollable category chip
/// row. Pins below the app bar as the reader scrolls past it.
class _StickyTocHeader extends SliverPersistentHeaderDelegate {
  _StickyTocHeader({
    required this.onTap,
    required this.backgroundColor,
  });

  final void Function(HealthCategory) onTap;
  final Color backgroundColor;

  /// Overall height reserved for the sticky bar — tall enough for the
  /// chip row plus a thin divider beneath.
  static const double _height = 56;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colors = AppColorsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm,
          ),
          child: Row(
            children: [
              for (var i = 0; i < _kChapterOrder.length; i++) ...[
                _TocChip(
                  category: _kChapterOrder[i],
                  onTap: () => onTap(_kChapterOrder[i]),
                ),
                if (i != _kChapterOrder.length - 1)
                  const SizedBox(width: AppDimens.spaceSm),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TocChip extends StatelessWidget {
  const _TocChip({required this.category, required this.onTap});

  final HealthCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppDimens.radiusChip),
            border: Border.all(
              color: color.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_chapterIcon(category), size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                category.displayName,
                style: AppTextStyles.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _Chapter ─────────────────────────────────────────────────────────────────

/// One chapter of the report. Composes a banner, optional AI summary,
/// hero + primary chart + signature visual, stats grid and the inline
/// "all metrics" block.
class _Chapter extends ConsumerWidget {
  const _Chapter({required this.category, required this.unitsSystem});

  final HealthCategory category;
  final UnitsSystem unitsSystem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = categoryColor(category);
    final params = CategoryDetailParams(
      categoryId: category.name,
      timeRange: '7D',
    );
    final detailAsync = ref.watch(categoryDetailProvider(params));
    final metrics =
        detailAsync.valueOrNull?.metrics ?? const <MetricSeries>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChapterBanner(category: category, color: color),
        const SizedBox(height: AppDimens.spaceMd),
        _ChapterBody(
          category: category,
          color: color,
          metrics: metrics,
          unitsSystem: unitsSystem,
          isLoading: detailAsync.isLoading && !detailAsync.hasValue,
        ),
        const SizedBox(height: AppDimens.spaceXl),
      ],
    );
  }
}

// ── _ChapterBanner ───────────────────────────────────────────────────────────

/// Full-bleed 200pt banner. Vertical gradient from the category tint at
/// the top to canvas at the bottom. Holds a big icon, a Lora title and
/// a one-line tagline.
class _ChapterBanner extends StatelessWidget {
  const _ChapterBanner({required this.category, required this.color});

  final HealthCategory category;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.22),
                  colors.canvas.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: ZPatternOverlay(
              variant: _chapterPatternVariant(category),
              opacity: 0.08,
              animate: true,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_chapterIcon(category), size: 48, color: color),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  category.displayName,
                  style: AppTextStyles.displayLarge.copyWith(
                    fontFamily: 'Lora',
                    fontWeight: FontWeight.w600,
                    fontSize: 32,
                    height: 1.05,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceLg,
                  ),
                  child: Text(
                    _chapterTagline(category),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _ChapterBody ─────────────────────────────────────────────────────────────

/// Per-category body. Routes to the right chapter builder so each
/// category can pull only the providers it actually needs.
class _ChapterBody extends StatelessWidget {
  const _ChapterBody({
    required this.category,
    required this.color,
    required this.metrics,
    required this.unitsSystem,
    required this.isLoading,
  });

  final HealthCategory category;
  final Color color;
  final List<MetricSeries> metrics;
  final UnitsSystem unitsSystem;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    switch (category) {
      case HealthCategory.sleep:
        return _SleepChapterBody(
          color: color,
          metrics: metrics,
          unitsSystem: unitsSystem,
          isLoading: isLoading,
        );
      case HealthCategory.activity:
        return _ActivityChapterBody(
          color: color,
          metrics: metrics,
          unitsSystem: unitsSystem,
          isLoading: isLoading,
        );
      case HealthCategory.heart:
        return _HeartChapterBody(
          color: color,
          metrics: metrics,
          unitsSystem: unitsSystem,
          isLoading: isLoading,
        );
      case HealthCategory.nutrition:
        return _NutritionChapterBody(
          color: color,
          metrics: metrics,
          unitsSystem: unitsSystem,
          isLoading: isLoading,
        );
      case HealthCategory.body:
        return _BodyChapterBody(
          color: color,
          metrics: metrics,
          unitsSystem: unitsSystem,
          isLoading: isLoading,
        );
      case HealthCategory.wellness:
        return _WellnessChapterBody(
          color: color,
          metrics: metrics,
          unitsSystem: unitsSystem,
          isLoading: isLoading,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Sleep chapter ────────────────────────────────────────────────────────────

class _SleepChapterBody extends ConsumerWidget {
  const _SleepChapterBody({
    required this.color,
    required this.metrics,
    required this.unitsSystem,
    required this.isLoading,
  });

  final Color color;
  final List<MetricSeries> metrics;
  final UnitsSystem unitsSystem;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(sleepDaySummaryProvider);
    final trendAsync = ref.watch(sleepTrendProvider('7d'));
    final summary = summaryAsync.valueOrNull ?? SleepDaySummary.empty;
    final trendDays = trendAsync.valueOrNull ?? const <SleepTrendDay>[];
    final stillLoading = isLoading ||
        (summaryAsync.isLoading && !summaryAsync.hasValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AiSummaryBlock(text: summary.aiSummary, color: color),
        InsightHeroCard(
          eyebrow: 'Last night',
          categoryIcon: Icons.bedtime_rounded,
          categoryColor: color,
          value: (summary.durationMinutes != null)
              ? _formatDuration(summary.durationMinutes)
              : '—',
          deltaLabel: summary.avgVs7DayMinutes != null
              ? _formatMinutesDeltaVsWeek(summary.avgVs7DayMinutes!)
              : null,
          deltaIsPositive: summary.avgVs7DayMinutes != null
              ? summary.avgVs7DayMinutes! >= 0
              : null,
          qualityLabel: summary.qualityLabel,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        if (trendDays.isNotEmpty)
          InsightPrimaryChart(
            title: 'Last 7 nights',
            categoryColor: color,
            points: [
              for (final d in trendDays)
                InsightPrimaryChartPoint(
                  label: _weekdayLetter(d.date),
                  value: (d.durationMinutes ?? 0).toDouble(),
                  isToday: d.isToday,
                ),
            ],
            goalValue: 480,
            goalLabel: '8h goal',
            formatTooltip: (v) => _formatDuration(v.round()),
            formatYAxis: (v) => '${(v / 60).round()}h',
          )
        else if (stillLoading)
          const _ChapterShimmer(height: 200),
        const SizedBox(height: AppDimens.spaceMd),
        // Scaled-up stage breakdown — more presence on the page.
        if (summary.stages != null && summary.stages!.hasAnyData)
          SizedBox(
            height: 260,
            child: ZSleepStageBreakdownCard(
              deepMinutes: summary.stages!.deepMinutes ?? 0,
              remMinutes: summary.stages!.remMinutes ?? 0,
              lightMinutes: summary.stages!.lightMinutes ?? 0,
              awakeMinutes: summary.stages!.awakeMinutes ?? 0,
              categoryColor: color,
            ),
          )
        else if (stillLoading)
          const _ChapterShimmer(height: 180),
        const SizedBox(height: AppDimens.spaceMd),
        InsightStatsGrid(
          title: 'The details',
          categoryColor: color,
          tiles: <InsightStatTile>[
            InsightStatTile(
              icon: Icons.nights_stay_rounded,
              label: 'Bedtime',
              value: summary.bedtime != null
                  ? _formatTime(summary.bedtime!)
                  : '—',
            ),
            InsightStatTile(
              icon: Icons.alarm_rounded,
              label: 'Wake time',
              value: summary.wakeTime != null
                  ? _formatTime(summary.wakeTime!)
                  : '—',
            ),
            InsightStatTile(
              icon: Icons.trending_up_rounded,
              label: 'Efficiency',
              value: summary.sleepEfficiencyPct != null
                  ? '${summary.sleepEfficiencyPct!.round()}%'
                  : '—',
            ),
            InsightStatTile(
              icon: Icons.notifications_active_rounded,
              label: 'Wakeups',
              value: summary.interruptions != null
                  ? '${summary.interruptions} '
                      '${summary.interruptions == 1 ? 'time' : 'times'}'
                  : '—',
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceLg),
        _AllMetricsBlock(
          title: 'All Sleep metrics',
          metrics: metrics,
          color: color,
          unitsSystem: unitsSystem,
          isLoading: stillLoading,
          chartKindResolver: _sleepChartKind,
          goalResolver: _sleepGoalValue,
        ),
      ],
    );
  }

  static ZCategoryChartKind _sleepChartKind(MetricSeries s) {
    final id = s.metricId.toLowerCase();
    const durationIds = <String>{
      'sleep_duration',
      'deep_sleep',
      'rem_sleep',
      'light_sleep',
      'awake_time',
    };
    if (durationIds.contains(id) || id.contains('duration')) {
      return ZCategoryChartKind.bars;
    }
    return ZCategoryChartKind.line;
  }

  static double? _sleepGoalValue(MetricSeries s) {
    if (s.metricId.toLowerCase() == 'sleep_duration') return 480;
    return null;
  }
}

// ── Activity chapter ─────────────────────────────────────────────────────────

class _ActivityChapterBody extends ConsumerWidget {
  const _ActivityChapterBody({
    required this.color,
    required this.metrics,
    required this.unitsSystem,
    required this.isLoading,
  });

  final Color color;
  final List<MetricSeries> metrics;
  final UnitsSystem unitsSystem;
  final bool isLoading;

  static const double _stepGoal = 8000;
  static const double _activeMinutesGoal = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    CategorySummary? activitySummary;
    final dash = dashboardAsync.valueOrNull;
    if (dash != null) {
      for (final c in dash.categories) {
        if (c.category == HealthCategory.activity) {
          activitySummary = c;
          break;
        }
      }
    }

    final stepsSeries = _findSeries(metrics, const ['steps']);
    final activeMinutesSeries = _findSeries(
      metrics,
      const ['active_minutes', 'exercise_minutes'],
    );
    final distanceSeries =
        _findSeries(metrics, const ['distance', 'distance_m', 'distance_km']);
    final activeCaloriesSeries = _findSeries(
      metrics,
      const ['active_calories', 'calories_active', 'calories_burned'],
    );

    final todaySteps = _latestValue(stepsSeries) ??
        (activitySummary?.trend?.lastOrNull) ??
        0.0;

    final stepsTrend = _fitSevenPadHead(
      stepsSeries?.dataPoints.map((p) => p.value).toList() ??
          activitySummary?.trend ??
          const <double>[],
    );

    final avgForDelta = stepsTrend.length >= 2
        ? (stepsTrend.sublist(0, stepsTrend.length - 1).fold<double>(
                  0,
                  (a, b) => a + (b.isFinite ? b : 0),
                ) /
            (stepsTrend.length - 1))
        : null;
    final stepDelta =
        avgForDelta != null ? (todaySteps - avgForDelta).round() : null;

    final todayActiveCalories = _latestValue(activeCaloriesSeries);
    final todayDistance = _latestValue(distanceSeries);
    final todayActiveMinutes = _latestValue(activeMinutesSeries);

    final hasStepsTrend = stepsTrend.where((v) => v > 0).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InsightHeroCard(
          eyebrow: 'Today',
          categoryIcon: Icons.directions_walk_rounded,
          categoryColor: color,
          value: (activitySummary?.primaryValue != null &&
                  activitySummary!.primaryValue.trim().isNotEmpty &&
                  activitySummary.primaryValue != '—')
              ? activitySummary.primaryValue
              : (todaySteps > 0 ? _formatSteps(todaySteps) : '—'),
          deltaLabel: stepDelta != null
              ? _formatStepsDeltaVsWeek(stepDelta)
              : null,
          deltaIsPositive: stepDelta != null ? stepDelta >= 0 : null,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        if (hasStepsTrend)
          InsightPrimaryChart(
            title: "This week's steps",
            categoryColor: color,
            points: [
              for (var i = 0; i < stepsTrend.length; i++)
                InsightPrimaryChartPoint(
                  label: _generateWeekLabels()[
                      i.clamp(0, 6)],
                  value: stepsTrend[i],
                  isToday: i == stepsTrend.length - 1,
                ),
            ],
            goalValue: _stepGoal,
            goalLabel: '8k goal',
            formatTooltip: (v) => '${v.toInt()} steps',
          )
        else if (isLoading)
          const _ChapterShimmer(height: 200),
        const SizedBox(height: AppDimens.spaceMd),
        _ActivityRingCard(
          color: color,
          todaySteps: todaySteps,
          stepGoal: _stepGoal,
          activeMinutes: todayActiveMinutes,
          activeMinutesGoal: _activeMinutesGoal,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        InsightStatsGrid(
          title: 'The details',
          categoryColor: color,
          tiles: <InsightStatTile>[
            InsightStatTile(
              icon: Icons.directions_walk_rounded,
              label: 'Steps',
              value: todaySteps > 0 ? _formatSteps(todaySteps) : '—',
            ),
            InsightStatTile(
              icon: Icons.timer_rounded,
              label: 'Active minutes',
              value: todayActiveMinutes != null
                  ? '${todayActiveMinutes.round()} min'
                  : '—',
            ),
            InsightStatTile(
              icon: Icons.straighten_rounded,
              label: 'Distance',
              value: _formatDistance(todayDistance, unitsSystem),
            ),
            InsightStatTile(
              icon: Icons.local_fire_department_rounded,
              label: 'Calories',
              value: todayActiveCalories != null
                  ? '${todayActiveCalories.round()} kcal'
                  : '—',
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceLg),
        _AllMetricsBlock(
          title: 'All Activity metrics',
          metrics: metrics,
          color: color,
          unitsSystem: unitsSystem,
          isLoading: isLoading,
          chartKindResolver: _activityChartKind,
          goalResolver: (s) =>
              s.metricId.toLowerCase() == 'steps' ? _stepGoal : null,
        ),
      ],
    );
  }

  static ZCategoryChartKind _activityChartKind(MetricSeries s) {
    const countable = <String>{
      'steps',
      'active_calories',
      'calories_active',
      'calories_burned',
      'distance',
      'distance_m',
      'distance_km',
      'floors',
      'floors_climbed',
      'workouts',
      'workouts_count',
      'exercise_minutes',
      'active_minutes',
    };
    const continuous = <String>{
      'walking_speed',
      'running_pace',
      'vo2_max',
      'cardio_fitness_level',
    };
    final id = s.metricId.toLowerCase();
    if (countable.contains(id)) return ZCategoryChartKind.bars;
    if (continuous.contains(id)) return ZCategoryChartKind.line;
    return ZCategoryChartKind.line;
  }
}

class _ActivityRingCard extends StatelessWidget {
  const _ActivityRingCard({
    required this.color,
    required this.todaySteps,
    required this.stepGoal,
    required this.activeMinutes,
    required this.activeMinutesGoal,
  });

  final Color color;
  final double todaySteps;
  final double stepGoal;
  final double? activeMinutes;
  final double activeMinutesGoal;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final hasInner = activeMinutes != null && activeMinutes! > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZuralogCard(
        variant: ZCardVariant.feature,
        category: color,
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's progress",
              style: AppTextStyles.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Center(
              child: ZGoalProgressRing(
                value: todaySteps,
                goal: stepGoal,
                color: color,
                size: 220,
                centerValue: _formatSteps(todaySteps),
                centerLabel: 'steps',
                innerValue: hasInner ? activeMinutes : null,
                innerGoal: hasInner ? activeMinutesGoal : null,
                innerColor: hasInner ? colors.success : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Heart chapter ────────────────────────────────────────────────────────────

class _HeartChapterBody extends ConsumerWidget {
  const _HeartChapterBody({
    required this.color,
    required this.metrics,
    required this.unitsSystem,
    required this.isLoading,
  });

  final Color color;
  final List<MetricSeries> metrics;
  final UnitsSystem unitsSystem;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(heartDaySummaryProvider);
    final trendAsync = ref.watch(heartTrendProvider('7d'));
    final summary = summaryAsync.valueOrNull ?? HeartDaySummary.empty;
    final trendDays = trendAsync.valueOrNull ?? const <HeartTrendDay>[];
    final stillLoading = isLoading ||
        (summaryAsync.isLoading && !summaryAsync.hasValue);

    final hasTrend = trendDays
            .where((d) => d.restingHr != null && d.restingHr!.isFinite)
            .length >=
        2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AiSummaryBlock(text: summary.aiSummary, color: color),
        InsightHeroCard(
          eyebrow: 'Today',
          categoryIcon: Icons.favorite_rounded,
          categoryColor: color,
          value: (summary.restingHr != null && summary.restingHr!.isFinite)
              ? '${summary.restingHr!.round()} bpm'
              : '—',
          deltaLabel: summary.restingHrVs7Day != null
              ? _formatBpmDeltaVsWeek(summary.restingHrVs7Day!.round())
              : null,
          deltaIsPositive: summary.restingHrVs7Day != null
              ? summary.restingHrVs7Day! <= 0
              : null,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        if (hasTrend)
          _HeartRhrChart(days: trendDays, color: color)
        else if (stillLoading)
          const _ChapterShimmer(height: 200),
        const SizedBox(height: AppDimens.spaceMd),
        _HeartZonesCard(color: color),
        const SizedBox(height: AppDimens.spaceMd),
        InsightStatsGrid(
          title: 'The details',
          categoryColor: color,
          tiles: <InsightStatTile>[
            InsightStatTile(
              icon: Icons.favorite_rounded,
              label: 'Resting HR',
              value: (summary.restingHr != null && summary.restingHr!.isFinite)
                  ? '${summary.restingHr!.round()} bpm'
                  : '—',
            ),
            InsightStatTile(
              icon: Icons.monitor_heart_rounded,
              label: 'HRV',
              value: (summary.hrvMs != null && summary.hrvMs!.isFinite)
                  ? '${summary.hrvMs!.round()} ms'
                  : '—',
            ),
            InsightStatTile(
              icon: Icons.trending_up_rounded,
              label: 'Avg HR',
              value: (summary.avgHr != null && summary.avgHr!.isFinite)
                  ? '${summary.avgHr!.round()} bpm'
                  : '—',
            ),
            const InsightStatTile(
              icon: Icons.self_improvement_rounded,
              label: 'Recovery',
              value: '—',
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceLg),
        _AllMetricsBlock(
          title: 'All Heart metrics',
          metrics: metrics,
          color: color,
          unitsSystem: unitsSystem,
          isLoading: stillLoading,
          chartKindResolver: _heartChartKind,
          goalResolver: (_) => null,
        ),
      ],
    );
  }

  static ZCategoryChartKind _heartChartKind(MetricSeries s) {
    const continuous = <String>{
      'resting_heart_rate',
      'hrv',
      'max_heart_rate',
      'walking_heart_rate',
      'heart_rate',
      'avg_heart_rate',
      'respiratory_rate',
      'vo2_max',
      'spo2',
    };
    const countable = <String>{'workouts', 'workouts_count'};
    final id = s.metricId.toLowerCase();
    if (countable.contains(id)) return ZCategoryChartKind.bars;
    if (continuous.contains(id)) return ZCategoryChartKind.line;
    return ZCategoryChartKind.line;
  }
}

class _HeartRhrChart extends StatelessWidget {
  const _HeartRhrChart({required this.days, required this.color});

  final List<HeartTrendDay> days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final points = <double>[
      for (final d in days)
        (d.restingHr != null && d.restingHr!.isFinite)
            ? d.restingHr!
            : double.nan,
    ];
    final tail = points.length >= 7
        ? points.sublist(points.length - 7)
        : [
            for (var i = 0; i < 7 - points.length; i++) double.nan,
            ...points,
          ];
    var todayIndex = -1;
    for (var i = days.length - 1; i >= 0; i--) {
      if (days[i].isToday) {
        todayIndex = i + (7 - days.length);
        break;
      }
    }
    if (todayIndex < 0 && tail.any((v) => v.isFinite)) todayIndex = 6;

    final fallbackLabels = _generateWeekLabels();
    final labels = <String>[
      for (var i = 0; i < tail.length; i++)
        if (i >= 7 - days.length)
          _weekdayLetter(days[i - (7 - days.length)].date)
        else
          i < fallbackLabels.length ? fallbackLabels[i] : '',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBackground,
          border: Border.all(
            color: colors.border.withValues(alpha: 0.4),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '7-day resting HR',
              style: AppTextStyles.titleMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            SizedBox(
              height: 200,
              child: ZCategoryChart(
                kind: ZCategoryChartKind.line,
                points: tail,
                color: color,
                dayLabels: labels,
                todayIndex: todayIndex,
                formatY: (v) => '${v.round()}',
                height: 200,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartZonesCard extends StatelessWidget {
  const _HeartZonesCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZuralogCard(
        variant: ZCardVariant.feature,
        category: color,
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's heart zones",
              style: AppTextStyles.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            ZHeartZonesBar(
              minutes: const <ZHeartZone, int>{},
              categoryColor: color,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Nutrition chapter ────────────────────────────────────────────────────────

class _NutritionChapterBody extends ConsumerWidget {
  const _NutritionChapterBody({
    required this.color,
    required this.metrics,
    required this.unitsSystem,
    required this.isLoading,
  });

  final Color color;
  final List<MetricSeries> metrics;
  final UnitsSystem unitsSystem;
  final bool isLoading;

  static const double _calorieGoal = 2000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final summaryAsync = ref.watch(nutritionDaySummaryProvider);
    final trendAsync = ref.watch(nutritionTrendProvider('7d'));
    final summary = summaryAsync.valueOrNull ?? NutritionDaySummary.empty;
    final trendDays = trendAsync.valueOrNull ?? const <NutritionTrendDay>[];
    final stillLoading = isLoading ||
        (summaryAsync.isLoading && !summaryAsync.hasValue);

    final historical = trendDays
        .where((d) =>
            !d.isToday && d.calories != null && d.calories!.isFinite)
        .map((d) => d.calories!)
        .toList();
    final avgLastWeek = historical.isEmpty
        ? null
        : historical.reduce((a, b) => a + b) / historical.length;
    final todayKcal = summary.totalCalories.toDouble();
    final kcalDelta = (avgLastWeek != null && todayKcal > 0)
        ? (todayKcal - avgLastWeek).round()
        : null;
    final hasCalorieTrend = trendDays
            .where((d) => d.calories != null && d.calories!.isFinite)
            .length >=
        2;

    final carbs = summary.totalCarbsG;
    final protein = summary.totalProteinG;
    final fat = summary.totalFatG;
    final hasMacros = (carbs + protein + fat) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AiSummaryBlock(text: summary.aiSummary, color: color),
        InsightHeroCard(
          eyebrow: 'Today',
          categoryIcon: Icons.local_fire_department_rounded,
          categoryColor: color,
          value: summary.totalCalories > 0
              ? '${_formatSteps(todayKcal)} kcal'
              : '—',
          deltaLabel: kcalDelta != null
              ? _formatKcalDeltaVsWeek(kcalDelta)
              : null,
          deltaIsPositive: null,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        if (hasCalorieTrend)
          InsightPrimaryChart(
            title: '7-day calories',
            categoryColor: color,
            points: [
              for (final d in trendDays)
                InsightPrimaryChartPoint(
                  label: _weekdayLetter(d.date),
                  value: (d.calories ?? 0).toDouble(),
                  isToday: d.isToday,
                ),
            ],
            goalValue: _calorieGoal,
            goalLabel: '${_formatSteps(_calorieGoal)} goal',
            formatTooltip: (v) => '${v.toInt()} kcal',
            formatYAxis: (v) => v >= 1000
                ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k'
                : v.round().toString(),
          )
        else if (stillLoading)
          const _ChapterShimmer(height: 200),
        const SizedBox(height: AppDimens.spaceMd),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: ZuralogCard(
            variant: ZCardVariant.feature,
            category: color,
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's macros",
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                if (hasMacros) ...[
                  Center(
                    child: ZMacroDonut(
                      proteinGrams: protein,
                      carbsGrams: carbs,
                      fatGrams: fat,
                      categoryColor: color,
                      size: 220,
                      centerValue: _formatSteps(todayKcal),
                      centerLabel: 'kcal today',
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                  _MacroLegendRow(
                    dotColor: kMacroCarbsColor,
                    label: 'Carbs',
                    value: '${carbs.round()} g',
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                  _MacroLegendRow(
                    dotColor: kMacroProteinColor,
                    label: 'Protein',
                    value: '${protein.round()} g',
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                  _MacroLegendRow(
                    dotColor: kMacroFatColor,
                    label: 'Fat',
                    value: '${fat.round()} g',
                  ),
                ] else
                  Text(
                    'No meals logged yet today.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        InsightStatsGrid(
          title: 'The details',
          categoryColor: color,
          tiles: <InsightStatTile>[
            InsightStatTile(
              icon: Icons.local_fire_department_rounded,
              label: 'Calories',
              value: summary.totalCalories > 0
                  ? '${_formatSteps(summary.totalCalories.toDouble())} kcal'
                  : '—',
            ),
            InsightStatTile(
              icon: Icons.fitness_center_rounded,
              label: 'Protein',
              value: protein > 0 ? '${protein.round()}g' : '—',
            ),
            InsightStatTile(
              icon: Icons.grain_rounded,
              label: 'Carbs',
              value: carbs > 0 ? '${carbs.round()}g' : '—',
            ),
            InsightStatTile(
              icon: Icons.opacity_rounded,
              label: 'Fat',
              value: fat > 0 ? '${fat.round()}g' : '—',
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceLg),
        _AllMetricsBlock(
          title: 'All Nutrition metrics',
          metrics: metrics,
          color: color,
          unitsSystem: unitsSystem,
          isLoading: stillLoading,
          chartKindResolver: _nutritionChartKind,
          goalResolver: (s) {
            final id = s.metricId.toLowerCase();
            if (id == 'calories' ||
                id == 'calories_consumed' ||
                id == 'total_calories') {
              return _calorieGoal;
            }
            return null;
          },
        ),
      ],
    );
  }

  static ZCategoryChartKind _nutritionChartKind(MetricSeries s) {
    const countable = <String>{
      'calories',
      'calories_consumed',
      'total_calories',
      'protein',
      'protein_g',
      'carbs',
      'carbs_g',
      'fat',
      'fat_g',
      'water',
      'water_ml',
      'fiber',
      'fiber_g',
      'sugar',
      'sugar_g',
      'sodium',
      'sodium_mg',
    };
    const continuous = <String>{
      'protein_ratio',
      'carbs_ratio',
      'fat_ratio',
      'macro_ratio',
      'nutrition_score',
    };
    final id = s.metricId.toLowerCase();
    if (continuous.contains(id)) return ZCategoryChartKind.line;
    if (countable.contains(id)) return ZCategoryChartKind.bars;
    return ZCategoryChartKind.bars;
  }
}

class _MacroLegendRow extends StatelessWidget {
  const _MacroLegendRow({
    required this.dotColor,
    required this.label,
    required this.value,
  });

  final Color dotColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Body chapter ─────────────────────────────────────────────────────────────

class _BodyChapterBody extends ConsumerWidget {
  const _BodyChapterBody({
    required this.color,
    required this.metrics,
    required this.unitsSystem,
    required this.isLoading,
  });

  final Color color;
  final List<MetricSeries> metrics;
  final UnitsSystem unitsSystem;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final profile = ref.watch(userProfileProvider);

    CategorySummary? bodySummary;
    final dash = dashboardAsync.valueOrNull;
    if (dash != null) {
      for (final c in dash.categories) {
        if (c.category == HealthCategory.body) {
          bodySummary = c;
          break;
        }
      }
    }

    final weightSeries = _findSeries(metrics, const ['weight']);
    final bodyFatSeries =
        _findSeries(metrics, const ['body_fat', 'body_fat_percent']);
    final bodyTempSeries = _findSeries(
      metrics,
      const ['body_temperature', 'wrist_temperature'],
    );
    final bmiSeries = _findSeries(metrics, const ['bmi']);

    final latestWeightKg = _latestValue(weightSeries);
    final hasTodayWeight = weightSeries != null &&
        weightSeries.dataPoints.isNotEmpty &&
        weightSeries.dataPoints.last.value.isFinite;

    final rawWeightValues = weightSeries != null
        ? weightSeries.dataPoints
            .map((p) => p.value)
            .where((v) => v.isFinite)
            .toList()
        : (bodySummary?.trend ?? const <double>[]);

    double? avgForDelta;
    if (rawWeightValues.length >= 2) {
      final body = rawWeightValues.sublist(0, rawWeightValues.length - 1);
      if (body.isNotEmpty) {
        avgForDelta = body.reduce((a, b) => a + b) / body.length;
      }
    }
    final weightDeltaKg = (latestWeightKg != null && avgForDelta != null)
        ? latestWeightKg - avgForDelta
        : null;

    final latestBodyFat = _latestValue(bodyFatSeries);
    final latestBodyTemp = _latestValue(bodyTempSeries);
    final latestBmiFromMetric = _latestValue(bmiSeries);

    final heightCm = profile?.heightCm;
    final canComputeBmi = heightCm != null &&
        heightCm > 0 &&
        latestWeightKg != null &&
        latestWeightKg > 0;
    final double? bmiValue = latestBmiFromMetric ??
        (canComputeBmi
            ? latestWeightKg / math.pow(heightCm / 100.0, 2)
            : null);

    final hasWeightTrend = rawWeightValues.where((v) => v > 0).length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InsightHeroCard(
          eyebrow: hasTodayWeight ? 'Today' : 'Latest',
          categoryIcon: Icons.accessibility_new_rounded,
          categoryColor: color,
          value: (latestWeightKg != null && latestWeightKg.isFinite)
              ? _formatWeight(latestWeightKg, unitsSystem)
              : (bodySummary?.primaryValue != null &&
                      bodySummary!.primaryValue.trim().isNotEmpty &&
                      bodySummary.primaryValue != '—')
                  ? bodySummary.primaryValue
                  : '—',
          deltaLabel: (weightDeltaKg != null && weightDeltaKg.isFinite)
              ? _formatWeightDeltaVsWeek(weightDeltaKg, unitsSystem)
              : null,
          deltaIsPositive: null,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        if (hasWeightTrend)
          _BodyWeightChart(
            color: color,
            valuesKg: rawWeightValues,
            unitsSystem: unitsSystem,
          )
        else if (isLoading)
          const _ChapterShimmer(height: 200),
        const SizedBox(height: AppDimens.spaceMd),
        _BodyBmiCard(color: color, bmi: bmiValue),
        const SizedBox(height: AppDimens.spaceMd),
        InsightStatsGrid(
          title: 'The details',
          categoryColor: color,
          tiles: <InsightStatTile>[
            InsightStatTile(
              icon: Icons.monitor_weight_rounded,
              label: 'Weight',
              value: (latestWeightKg != null && latestWeightKg.isFinite)
                  ? _formatWeight(latestWeightKg, unitsSystem)
                  : '—',
            ),
            InsightStatTile(
              icon: Icons.percent_rounded,
              label: 'Body fat',
              value: (latestBodyFat != null && latestBodyFat.isFinite)
                  ? '${latestBodyFat.toStringAsFixed(latestBodyFat >= 100 ? 0 : 1)}%'
                  : '—',
            ),
            InsightStatTile(
              icon: Icons.straighten_rounded,
              label: 'BMI',
              value: (bmiValue != null && bmiValue.isFinite)
                  ? bmiValue.toStringAsFixed(1)
                  : '—',
            ),
            InsightStatTile(
              icon: Icons.thermostat_rounded,
              label: 'Body temp',
              value: (latestBodyTemp != null && latestBodyTemp.isFinite)
                  ? _formatTemperature(latestBodyTemp, unitsSystem)
                  : '—',
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceLg),
        _AllMetricsBlock(
          title: 'All Body metrics',
          metrics: metrics,
          color: color,
          unitsSystem: unitsSystem,
          isLoading: isLoading,
          chartKindResolver: (_) => ZCategoryChartKind.line,
          goalResolver: (_) => null,
        ),
      ],
    );
  }
}

class _BodyWeightChart extends StatelessWidget {
  const _BodyWeightChart({
    required this.color,
    required this.valuesKg,
    required this.unitsSystem,
  });

  final Color color;
  final List<double> valuesKg;
  final UnitsSystem unitsSystem;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final displayValues = [
      for (final v in valuesKg)
        v.isFinite ? _kgToDisplay(v, unitsSystem) : double.nan,
    ];
    final tail = _fitSevenDownsampleOrPad(displayValues);
    final todayIndex = tail.any((v) => v.isFinite) ? 6 : -1;
    final labels = _generateWeekLabels();
    final unitSuffix = unitsSystem == UnitsSystem.imperial ? 'lb' : 'kg';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBackground,
          border: Border.all(
            color: colors.border.withValues(alpha: 0.4),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '7-day weight',
              style: AppTextStyles.titleMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            SizedBox(
              height: 200,
              child: ZCategoryChart(
                kind: ZCategoryChartKind.line,
                points: tail,
                color: color,
                dayLabels: labels,
                todayIndex: todayIndex,
                formatY: (v) =>
                    '${v.toStringAsFixed(v >= 100 ? 0 : 1)} $unitSuffix',
                height: 200,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BodyBmiCard extends StatelessWidget {
  const _BodyBmiCard({required this.color, required this.bmi});

  final Color color;
  final double? bmi;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZuralogCard(
        variant: ZCardVariant.feature,
        category: color,
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BMI',
              style: AppTextStyles.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            if (bmi != null && bmi!.isFinite)
              Center(child: ZBmiGauge(bmi: bmi!, size: 220))
            else
              Text(
                'Add your height to see BMI.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Wellness chapter ─────────────────────────────────────────────────────────

class _WellnessChapterBody extends ConsumerWidget {
  const _WellnessChapterBody({
    required this.color,
    required this.metrics,
    required this.unitsSystem,
    required this.isLoading,
  });

  final Color color;
  final List<MetricSeries> metrics;
  final UnitsSystem unitsSystem;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final dashboardAsync = ref.watch(dashboardProvider);
    CategorySummary? wellnessSummary;
    final dash = dashboardAsync.valueOrNull;
    if (dash != null) {
      for (final c in dash.categories) {
        if (c.category == HealthCategory.wellness) {
          wellnessSummary = c;
          break;
        }
      }
    }

    final moodSeries = _findSeries(metrics, const ['mood']);
    final energySeries = _findSeries(metrics, const ['energy']);
    final stressSeries = _findSeries(metrics, const ['stress']);
    final mindfulSeries = _findSeries(
      metrics,
      const ['mindful_minutes', 'mindfulness', 'meditation_minutes'],
    );

    final latestMood = _latestValue(moodSeries);
    final moodUnit = moodSeries?.unit ?? '';
    final String heroValue;
    if (latestMood != null && latestMood.isFinite) {
      final looksLikeRatio =
          moodUnit.startsWith('/') || moodUnit.contains('/');
      final formattedLatest = _formatOneDecimal(latestMood);
      heroValue = looksLikeRatio
          ? '$formattedLatest $moodUnit'
          : formattedLatest;
    } else if ((wellnessSummary?.primaryValue ?? '').trim().isNotEmpty &&
        wellnessSummary!.primaryValue != '—') {
      final pv = wellnessSummary.primaryValue;
      final unit = (wellnessSummary.unit ?? '').trim();
      heroValue = unit.startsWith('/') ? '$pv $unit' : pv;
    } else {
      heroValue = '—';
    }

    final moodDelta = _deltaVsWeek(moodSeries);
    final moodPoints = _lastSevenForSeries(moodSeries);
    final energyPoints = _lastSevenForSeries(energySeries);
    final stressPoints = _lastSevenForSeries(stressSeries);
    final dayLabels = _generateWeekLabels();
    final hasMoodTrend = moodPoints.where((v) => v.isFinite).length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InsightHeroCard(
          eyebrow: 'Today',
          categoryIcon: Icons.self_improvement_rounded,
          categoryColor: color,
          value: heroValue,
          deltaLabel: (moodDelta != null && moodDelta.isFinite)
              ? _formatMoodDeltaVsWeek(moodDelta)
              : null,
          deltaIsPositive: null,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        if (hasMoodTrend)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: colors.cardBackground,
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.4),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              ),
              padding: const EdgeInsets.all(AppDimens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This week's mood",
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  SizedBox(
                    height: 120,
                    child: ZCategoryChart(
                      kind: ZCategoryChartKind.dots,
                      points: moodPoints,
                      color: color,
                      dayLabels: dayLabels,
                      todayIndex: 6,
                      height: 120,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (isLoading)
          const _ChapterShimmer(height: 160),
        const SizedBox(height: AppDimens.spaceMd),
        _WellnessGridCard(
          color: color,
          moodPoints: moodPoints,
          energyPoints: energyPoints,
          stressPoints: stressPoints,
          dayLabels: dayLabels,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        InsightStatsGrid(
          title: 'The details',
          categoryColor: color,
          tiles: <InsightStatTile>[
            InsightStatTile(
              icon: Icons.sentiment_very_satisfied_rounded,
              label: 'Mood',
              value: _scaleAvgLabel(moodSeries),
            ),
            InsightStatTile(
              icon: Icons.bolt_rounded,
              label: 'Energy',
              value: _scaleAvgLabel(energySeries),
            ),
            InsightStatTile(
              icon: Icons.spa_rounded,
              label: 'Stress',
              value: _scaleAvgLabel(stressSeries),
            ),
            InsightStatTile(
              icon: Icons.self_improvement_rounded,
              label: 'Mindful minutes',
              value: _mindfulTotalLabel(mindfulSeries),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceLg),
        _AllMetricsBlock(
          title: 'All Wellness metrics',
          metrics: metrics,
          color: color,
          unitsSystem: unitsSystem,
          isLoading: isLoading,
          chartKindResolver: _wellnessChartKind,
          goalResolver: (_) => null,
        ),
      ],
    );
  }

  static ZCategoryChartKind _wellnessChartKind(MetricSeries s) {
    const rating = <String>{'mood', 'energy', 'stress', 'focus', 'calm'};
    const countable = <String>{
      'mindful_minutes',
      'mindfulness',
      'meditation_minutes',
    };
    final id = s.metricId.toLowerCase();
    if (rating.contains(id)) return ZCategoryChartKind.dots;
    if (countable.contains(id)) return ZCategoryChartKind.bars;
    return ZCategoryChartKind.bars;
  }

  static String _scaleAvgLabel(MetricSeries? s) {
    if (s == null) return '—';
    final values = s.dataPoints
        .map((p) => p.value)
        .where((v) => v.isFinite)
        .toList();
    if (values.isEmpty) return '—';
    final avg = values.reduce((a, b) => a + b) / values.length;
    final unit = s.unit.trim();
    final formatted = _formatOneDecimal(avg);
    if (unit.isEmpty) return formatted;
    return '$formatted $unit';
  }

  static String _mindfulTotalLabel(MetricSeries? s) {
    if (s == null) return '—';
    final values = s.dataPoints
        .map((p) => p.value)
        .where((v) => v.isFinite)
        .toList();
    if (values.isEmpty) return '—';
    final total = values.reduce((a, b) => a + b);
    return '${total.round()} min';
  }
}

class _WellnessGridCard extends StatelessWidget {
  const _WellnessGridCard({
    required this.color,
    required this.moodPoints,
    required this.energyPoints,
    required this.stressPoints,
    required this.dayLabels,
  });

  final Color color;
  final List<double> moodPoints;
  final List<double> energyPoints;
  final List<double> stressPoints;
  final List<String> dayLabels;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZuralogCard(
        variant: ZCardVariant.feature,
        category: color,
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This week at a glance',
              style: AppTextStyles.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _WellnessGridRow(
              label: 'Mood',
              points: moodPoints,
              color: color,
              dayLabels: dayLabels,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _WellnessGridRow(
              label: 'Energy',
              points: energyPoints,
              color: color,
              dayLabels: dayLabels,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _WellnessGridRow(
              label: 'Stress (lower is better)',
              points: stressPoints,
              color: color,
              dayLabels: dayLabels,
            ),
          ],
        ),
      ),
    );
  }
}

class _WellnessGridRow extends StatelessWidget {
  const _WellnessGridRow({
    required this.label,
    required this.points,
    required this.color,
    required this.dayLabels,
  });

  final String label;
  final List<double> points;
  final Color color;
  final List<String> dayLabels;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final hasData = points.any((v) => v.isFinite);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (hasData)
          SizedBox(
            height: 100,
            child: ZCategoryChart(
              kind: ZCategoryChartKind.dots,
              points: points,
              color: color,
              dayLabels: dayLabels,
              todayIndex: 6,
              height: 100,
            ),
          )
        else
          SizedBox(
            height: 100,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No data yet',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── _AiSummaryBlock ──────────────────────────────────────────────────────────

/// Left-accent-bar + paragraph block used when a day summary has an
/// `aiSummary`. Activity / Body / Wellness don't have one today, so the
/// block renders nothing in those chapters.
class _AiSummaryBlock extends StatelessWidget {
  const _AiSummaryBlock({required this.text, required this.color});

  final String? text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What this tells us',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    trimmed,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: colors.textPrimary,
                      height: 1.55,
                    ),
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

// ── _AllMetricsBlock + _MetricRow ────────────────────────────────────────────

typedef _ChartKindResolver = ZCategoryChartKind Function(MetricSeries);
typedef _GoalResolver = double? Function(MetricSeries);

/// Inline list of every metric for a chapter. No per-metric card chrome
/// — just the name, value, optional delta pill, a 110pt chart, a one-line
/// description, an Avg · Min · Max strip, and a thin divider.
class _AllMetricsBlock extends StatelessWidget {
  const _AllMetricsBlock({
    required this.title,
    required this.metrics,
    required this.color,
    required this.unitsSystem,
    required this.isLoading,
    required this.chartKindResolver,
    required this.goalResolver,
  });

  final String title;
  final List<MetricSeries> metrics;
  final Color color;
  final UnitsSystem unitsSystem;
  final bool isLoading;
  final _ChartKindResolver chartKindResolver;
  final _GoalResolver goalResolver;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    if (metrics.isEmpty) {
      if (isLoading) {
        return const _ChapterShimmer(height: 140);
      }
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          for (var i = 0; i < metrics.length; i++) ...[
            _MetricRow(
              series: metrics[i],
              color: color,
              unitsSystem: unitsSystem,
              chartKind: chartKindResolver(metrics[i]),
              goalValue: goalResolver(metrics[i]),
            ),
            if (i != metrics.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.spaceMd,
                ),
                child: Container(
                  height: 1,
                  color: colors.border.withValues(alpha: 0.12),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.series,
    required this.color,
    required this.unitsSystem,
    required this.chartKind,
    required this.goalValue,
  });

  final MetricSeries series;
  final Color color;
  final UnitsSystem unitsSystem;
  final ZCategoryChartKind chartKind;
  final double? goalValue;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final unit = displayUnit(series.unit, unitsSystem);

    final points = <double>[for (final p in series.dataPoints) p.value];
    final tail = points.length >= 7
        ? points.sublist(points.length - 7)
        : [
            for (var i = 0; i < 7 - points.length; i++) double.nan,
            ...points,
          ];
    final todayIndex = points.isNotEmpty ? 6 : -1;
    final dayLabels = _generateWeekLabels();

    final values = series.dataPoints
        .map((p) => p.value)
        .where((v) => v.isFinite)
        .toList();
    final avg = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final min = values.isEmpty
        ? null
        : values.reduce((a, b) => a < b ? a : b);
    final max = values.isEmpty
        ? null
        : values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name left, value right.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                series.displayName,
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            if (series.currentValue != null)
              RichText(
                textAlign: TextAlign.right,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: series.currentValue!,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    if (unit.isNotEmpty)
                      TextSpan(
                        text: ' $unit',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        // Delta pill under the value.
        if (series.deltaPercent != null &&
            series.deltaPercent!.isFinite) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: _MetricDeltaPill(deltaPercent: series.deltaPercent!),
          ),
        ],
        const SizedBox(height: AppDimens.spaceSm),
        // Chart.
        if (series.dataPoints.length >= 2)
          SizedBox(
            height: 110,
            child: ZCategoryChart(
              kind: chartKind,
              points: tail,
              color: color,
              dayLabels: dayLabels,
              todayIndex: todayIndex,
              goalValue: goalValue,
              height: 110,
            ),
          )
        else
          SizedBox(
            height: 42,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Not enough data yet',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          ),
        const SizedBox(height: AppDimens.spaceSm),
        // One-line description.
        Text(
          _metricDescription(series.metricId),
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        // Avg · Min · Max single-line strip.
        Text(
          _avgMinMaxLine(
            avg: avg,
            min: min,
            max: max,
            metricId: series.metricId,
            unit: unit,
          ),
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textTertiary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _MetricDeltaPill extends StatelessWidget {
  const _MetricDeltaPill({required this.deltaPercent});

  final double deltaPercent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final Color bg;
    final Color fg;
    if (deltaPercent > 0) {
      bg = colors.success.withValues(alpha: 0.14);
      fg = colors.success;
    } else if (deltaPercent < 0) {
      bg = colors.warning.withValues(alpha: 0.14);
      fg = colors.warning;
    } else {
      bg = colors.surfaceRaised;
      fg = colors.textSecondary;
    }
    final sign = deltaPercent > 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        '$sign${deltaPercent.toStringAsFixed(1)}%',
        style: AppTextStyles.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── _ReportFooter ────────────────────────────────────────────────────────────

/// "Generated on [date]" + the share-report pill. The share action is a
/// stub for this task — it shows a SnackBar and no real share sheet.
class _ReportFooter extends StatelessWidget {
  const _ReportFooter();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final dateLabel = _formatReportDate(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Generated on $dateLabel',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          ZPatternPillButton(
            icon: Icons.ios_share_rounded,
            label: 'Share this report',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Share coming soon'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── _ChapterShimmer ──────────────────────────────────────────────────────────

/// Simple placeholder block for when a chapter's data is still loading.
/// We never render a full-screen error state; anything that fails quietly
/// falls back to an empty slot.
class _ChapterShimmer extends StatelessWidget {
  const _ChapterShimmer({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZLoadingSkeleton(
        width: double.infinity,
        height: height,
        borderRadius: AppDimens.radiusCard,
      ),
    );
  }
}

// ── Shared helpers ───────────────────────────────────────────────────────────

MetricSeries? _findSeries(List<MetricSeries> metrics, List<String> ids) {
  for (final id in ids) {
    for (final s in metrics) {
      if (s.metricId.toLowerCase() == id) return s;
    }
  }
  return null;
}

double? _latestValue(MetricSeries? s) {
  if (s == null) return null;
  for (var i = s.dataPoints.length - 1; i >= 0; i--) {
    final v = s.dataPoints[i].value;
    if (v.isFinite) return v;
  }
  return null;
}

double? _deltaVsWeek(MetricSeries? s) {
  if (s == null) return null;
  final finite = s.dataPoints
      .map((p) => p.value)
      .where((v) => v.isFinite)
      .toList();
  if (finite.length < 2) return null;
  final today = finite.last;
  final prior = finite.sublist(0, finite.length - 1);
  final avg = prior.reduce((a, b) => a + b) / prior.length;
  return today - avg;
}

List<double> _lastSevenForSeries(MetricSeries? s) {
  if (s == null) return List<double>.filled(7, double.nan);
  final values = s.dataPoints.map((p) => p.value).toList();
  if (values.length >= 7) return values.sublist(values.length - 7);
  return [
    for (var i = 0; i < 7 - values.length; i++) double.nan,
    ...values,
  ];
}

List<double> _fitSevenPadHead(List<double> input) {
  if (input.isEmpty) return const [0, 0, 0, 0, 0, 0, 0];
  if (input.length >= 7) return input.sublist(input.length - 7);
  return [
    for (var i = 0; i < 7 - input.length; i++) 0.0,
    ...input,
  ];
}

List<double> _fitSevenDownsampleOrPad(List<double> values) {
  if (values.isEmpty) return List.filled(7, double.nan);
  if (values.length == 7) return values;
  if (values.length < 7) {
    return [
      for (var i = 0; i < 7 - values.length; i++) double.nan,
      ...values,
    ];
  }
  final out = <double>[];
  for (var i = 0; i < 7; i++) {
    final idx = ((i * (values.length - 1)) / 6).round();
    out.add(values[idx.clamp(0, values.length - 1)]);
  }
  return out;
}

List<String> _generateWeekLabels() {
  const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final today = DateTime.now();
  final todayIdx = today.weekday - 1;
  final labels = <String>[];
  for (var i = 6; i >= 0; i--) {
    var idx = (todayIdx - i) % 7;
    if (idx < 0) idx += 7;
    labels.add(names[idx]);
  }
  return labels;
}

String _weekdayLetter(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return '';
  const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return names[d.weekday - 1];
}

String _formatDuration(int? minutes) {
  if (minutes == null || minutes <= 0) return '—';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

String _formatTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $period';
}

String _formatMinutesDeltaVsWeek(int minutes) {
  final abs = minutes.abs();
  final sign = minutes >= 0 ? '+' : '-';
  final body = abs >= 60
      ? (abs % 60 == 0 ? '${abs ~/ 60}h' : '${abs ~/ 60}h ${abs % 60}m')
      : '${abs}m';
  return '$sign$body vs last week';
}

String _formatSteps(double steps) {
  if (!steps.isFinite || steps < 0) return '0';
  final rounded = steps.round();
  final s = rounded.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final fromRight = s.length - i;
    buf.write(s[i]);
    if (fromRight > 1 && fromRight % 3 == 1) buf.write(',');
  }
  return buf.toString();
}

String _formatStepsDeltaVsWeek(int delta) {
  final sign = delta >= 0 ? '+' : '-';
  return '$sign${_formatSteps(delta.abs().toDouble())} vs last week';
}

String _formatBpmDeltaVsWeek(int delta) {
  if (delta == 0) return '0 bpm vs last week';
  final sign = delta > 0 ? '+' : '-';
  return '$sign${delta.abs()} bpm vs last week';
}

String _formatKcalDeltaVsWeek(int delta) {
  if (delta == 0) return '0 kcal vs last week';
  final sign = delta > 0 ? '+' : '-';
  return '$sign${_formatSteps(delta.abs().toDouble())} kcal vs last week';
}

String _formatMoodDeltaVsWeek(double delta) {
  if (!delta.isFinite) return '';
  final abs = delta.abs();
  final sign = delta > 0 ? '+' : (delta < 0 ? '-' : '');
  return '$sign${abs.toStringAsFixed(1)} vs last week';
}

double _kgToDisplay(double kg, UnitsSystem system) {
  if (system == UnitsSystem.imperial) return kg * 2.20462;
  return kg;
}

String _formatWeight(double kg, UnitsSystem system) {
  if (!kg.isFinite) return '—';
  final v = _kgToDisplay(kg, system);
  final unit = system == UnitsSystem.imperial ? 'lb' : 'kg';
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} $unit';
}

String _formatWeightDeltaVsWeek(double deltaKg, UnitsSystem system) {
  if (!deltaKg.isFinite) return '';
  final displayDelta = _kgToDisplay(deltaKg, system);
  final abs = displayDelta.abs();
  final unit = system == UnitsSystem.imperial ? 'lb' : 'kg';
  final sign = displayDelta > 0 ? '+' : (displayDelta < 0 ? '-' : '');
  final magnitude = abs.toStringAsFixed(abs >= 100 ? 0 : 1);
  return '$sign$magnitude $unit vs last week';
}

String _formatTemperature(double celsius, UnitsSystem system) {
  if (!celsius.isFinite) return '—';
  if (system == UnitsSystem.imperial) {
    final f = celsius * 9 / 5 + 32;
    return '${f.toStringAsFixed(1)}°F';
  }
  return '${celsius.toStringAsFixed(1)}°C';
}

String _formatDistance(double? meters, UnitsSystem system) {
  if (meters == null || !meters.isFinite) return '—';
  final km = meters / 1000.0;
  if (system == UnitsSystem.imperial) {
    final mi = km * 0.621371;
    return '${mi.toStringAsFixed(1)} mi';
  }
  return '${km.toStringAsFixed(1)} km';
}

String _formatOneDecimal(double? value) {
  if (value == null || !value.isFinite) return '—';
  return value.toStringAsFixed(1);
}

String _formatMetricValue(
  double? value, {
  required String metricId,
  required String unit,
}) {
  if (value == null || !value.isFinite) return '—';
  final id = metricId.toLowerCase();
  const durationIds = <String>{
    'sleep_duration',
    'deep_sleep',
    'rem_sleep',
    'light_sleep',
    'awake_time',
  };
  if (durationIds.contains(id) || id.contains('duration')) {
    return _formatDuration(value.round());
  }
  if (id == 'steps' || id == 'calories' || id == 'active_calories') {
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
    }
    return value.round().toString();
  }
  if (id == 'distance' || id == 'distance_m') {
    final km = value / 1000.0;
    return '${km.toStringAsFixed(1)} ${unit.isEmpty ? 'km' : unit}';
  }
  final rendered = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  if (unit.isEmpty) return rendered;
  return '$rendered $unit';
}

String _avgMinMaxLine({
  required double? avg,
  required double? min,
  required double? max,
  required String metricId,
  required String unit,
}) {
  final a = _formatMetricValue(avg, metricId: metricId, unit: unit);
  final lo = _formatMetricValue(min, metricId: metricId, unit: unit);
  final hi = _formatMetricValue(max, metricId: metricId, unit: unit);
  return 'Avg $a  ·  Min $lo  ·  Max $hi';
}

String _formatReportDate(DateTime d) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

// ── _metricDescription ───────────────────────────────────────────────────────

/// Plain-English one-line descriptions of every metric id we currently
/// expect from the backend. Unknown ids fall back to a generic caption.
String _metricDescription(String id) {
  switch (id) {
    // Sleep
    case 'sleep_duration':
      return 'How long you were actually asleep last night.';
    case 'deep_sleep':
      return 'Time your body spent in deep, restorative sleep.';
    case 'rem_sleep':
      return 'Dream sleep — when your brain consolidates memory.';
    case 'light_sleep':
      return 'Light sleep — the bulk of the night.';
    case 'awake_time':
      return 'Minutes you were awake during the night.';
    case 'sleep_efficiency':
      return 'Percent of time in bed you were actually asleep.';
    case 'bedtime':
      return 'When you fell asleep last night.';
    case 'wake_time':
      return 'When you woke up this morning.';
    case 'sleep_stages':
      return 'Breakdown of deep, REM, light and awake time.';
    // Activity
    case 'steps':
      return 'Total steps you took today.';
    case 'active_calories':
      return 'Calories burned from movement beyond resting metabolism.';
    case 'active_minutes':
    case 'exercise_minutes':
      return 'Minutes you spent in moderate-to-vigorous movement.';
    case 'distance':
      return 'How far you moved today.';
    case 'floors_climbed':
      return 'Floors climbed via stairs or elevation gain.';
    case 'workouts':
      return 'Workouts you logged today.';
    case 'walking_speed':
      return 'Your average walking pace.';
    case 'running_pace':
      return 'Your average running pace.';
    // Heart
    case 'resting_heart_rate':
      return 'Your heart rate at full rest — lower usually means better recovery.';
    case 'hrv':
      return 'Heart rate variability — a key signal for recovery and stress.';
    case 'max_heart_rate':
    case 'avg_heart_rate':
      return 'Your heart rate while you moved today.';
    case 'walking_heart_rate':
      return 'Your average heart rate during steady walking.';
    case 'respiratory_rate':
      return 'Your breathing rate at rest.';
    case 'spo2':
      return 'Blood oxygen saturation — normal is 95–100%.';
    // Nutrition
    case 'calories':
      return 'Total energy you consumed today.';
    case 'protein':
      return 'Grams of protein you ate today.';
    case 'carbs':
      return 'Grams of carbohydrates you ate today.';
    case 'fat':
      return 'Grams of fat you ate today.';
    case 'water':
      return 'Water you drank today.';
    case 'mindful_minutes':
    case 'mindfulness':
    case 'meditation_minutes':
      return 'Time you spent in meditation or focused breathing.';
    // Body
    case 'weight':
      return 'Your latest weight reading.';
    case 'body_fat':
    case 'body_fat_percent':
      return 'Estimated percentage of your weight that is body fat.';
    case 'bmi':
      return 'Body mass index — weight-to-height ratio.';
    case 'body_temperature':
    case 'wrist_temperature':
      return 'Your skin temperature deviation from your baseline.';
    case 'blood_glucose':
      return 'Blood sugar reading — normal fasting is 70–99 mg/dL.';
    case 'blood_pressure':
      return 'Systolic over diastolic blood pressure.';
    case 'vo2_max':
      return 'A fitness measure of how much oxygen your body uses at peak effort.';
    // Wellness
    case 'mood':
      return 'How you rated your mood today.';
    case 'energy':
      return 'How energetic you felt today.';
    case 'stress':
      return 'How stressful today felt — lower is better.';
    default:
      return 'Tracked measurement from your connected sources.';
  }
}
