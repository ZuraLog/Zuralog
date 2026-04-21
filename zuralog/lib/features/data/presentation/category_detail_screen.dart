/// Category Detail Screen — pushed from Health Dashboard.
///
/// Drill-down into a specific health category (Activity, Sleep, Heart, etc.).
///
/// Sleep and Activity use a richer "magazine" body: hero value, 7-day
/// primary chart, a category signature visual (sleep stage donut /
/// activity goal ring), a 2×2 stats grid, and per-metric cards with
/// chart types matched to each sub-metric.
///
/// Every other category still renders the original flat line-chart list
/// until their own redesign pass lands.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import 'package:zuralog/shared/widgets/time_range_selector.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── CategoryDetailScreen ──────────────────────────────────────────────────────

/// Category detail screen parameterised by [categoryId].
class CategoryDetailScreen extends ConsumerStatefulWidget {
  /// Creates a [CategoryDetailScreen] for the given [categoryId].
  const CategoryDetailScreen({super.key, required this.categoryId});

  /// The category identifier slug (e.g. "activity", "sleep", "heart").
  final String categoryId;

  @override
  ConsumerState<CategoryDetailScreen> createState() =>
      _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  TimeRange _selectedRange = TimeRange.days7;
  DateTimeRange? _customRange;

  HealthCategory get _category =>
      HealthCategory.fromString(widget.categoryId) ?? HealthCategory.activity;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final cat = _category;
    final color = categoryColor(cat);
    final unitsSystem = ref.watch(unitsSystemProvider);
    // When custom is selected with a picked range, encode dates into the
    // time range key so the cache treats it as a distinct entry.
    final timeRangeKey = _selectedRange == TimeRange.custom && _customRange != null
        ? 'custom:${_customRange!.start.toIso8601String()}|${_customRange!.end.toIso8601String()}'
        : _selectedRange.label;
    final params = CategoryDetailParams(
      categoryId: widget.categoryId,
      timeRange: timeRangeKey,
    );
    final detailAsync = ref.watch(categoryDetailProvider(params));

    return ZuralogScaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Text(cat.displayName, style: AppTextStyles.displaySmall),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Time range selector ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: TimeRangeSelector(
              value: _selectedRange,
              onChanged: (range) =>
                  setState(() => _selectedRange = range),
              customDateRange: _customRange,
              onCustomRangePicked: (range) => setState(() {
                _customRange = range;
                _selectedRange = TimeRange.custom;
              }),
            ),
          ),

          // ── Content ────────────────────────────────────────────────────────
          Expanded(
            child: switch (cat) {
              HealthCategory.sleep => _SleepDetailBody(
                  color: color,
                  detailAsync: detailAsync,
                  unitsSystem: unitsSystem,
                ),
              HealthCategory.activity => _ActivityDetailBody(
                  color: color,
                  detailAsync: detailAsync,
                  unitsSystem: unitsSystem,
                ),
              HealthCategory.heart => _HeartDetailBody(
                  color: color,
                  detailAsync: detailAsync,
                  unitsSystem: unitsSystem,
                ),
              HealthCategory.nutrition => _NutritionDetailBody(
                  color: color,
                  detailAsync: detailAsync,
                  unitsSystem: unitsSystem,
                ),
              HealthCategory.body => _BodyDetailBody(
                  color: color,
                  detailAsync: detailAsync,
                  unitsSystem: unitsSystem,
                  selectedRange: _selectedRange,
                ),
              _ => _buildLegacyBody(
                  context, colors, cat, color, unitsSystem, detailAsync),
            },
          ),
        ],
      ),
    );
  }

  // Legacy rendering for every category except Sleep — flat list of line
  // charts. Each category gets its own magazine body in follow-up work.
  Widget _buildLegacyBody(
    BuildContext context,
    AppColorsOf colors,
    HealthCategory cat,
    Color color,
    UnitsSystem unitsSystem,
    AsyncValue<CategoryDetailData> detailAsync,
  ) {
    return detailAsync.when(
      loading: () => _buildSkeletons(),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Could not load ${cat.displayName}',
              style: AppTextStyles.bodyLarge
                  .copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
      data: (detail) {
        if (detail.metrics.isEmpty) {
          return Center(
            child: Text(
              'No metrics for ${cat.displayName} yet.',
              style: AppTextStyles.bodyLarge
                  .copyWith(color: colors.textSecondary),
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceXs,
            AppDimens.spaceMd,
            AppDimens.bottomNavHeight + AppDimens.spaceMd,
          ),
          itemCount: detail.metrics.length,
          itemBuilder: (context, i) {
            return _MetricChartCard(
              series: detail.metrics[i],
              color: color,
              displayUnit:
                  displayUnit(detail.metrics[i].unit, unitsSystem),
              onTap: () => context
                  .push('/data/metric/${detail.metrics[i].metricId}'),
            );
          },
        );
      },
    );
  }

  Widget _buildSkeletons() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      itemCount: 3,
      itemBuilder: (context, index) => const _MetricCardSkeleton(),
    );
  }
}

// ── _SleepDetailBody ──────────────────────────────────────────────────────────

/// Magazine-layout body for the Sleep category detail screen.
///
/// Sections, top to bottom:
///  1. Hero card (last night's duration + delta + quality label).
///  2. 7-night bar chart with 8h dashed goal line.
///  3. Sleep stage donut for last night.
///  4. 2×2 stats grid — bedtime / wake / efficiency / wakeups.
///  5. One card per sub-metric (bars for durations, line for efficiency).
///  6. AI analysis card when a summary is available.
class _SleepDetailBody extends ConsumerWidget {
  const _SleepDetailBody({
    required this.color,
    required this.detailAsync,
    required this.unitsSystem,
  });

  final Color color;
  final AsyncValue<CategoryDetailData> detailAsync;
  final UnitsSystem unitsSystem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(sleepDaySummaryProvider);
    final trendAsync = ref.watch(sleepTrendProvider('7d'));

    final summary = summaryAsync.valueOrNull ?? SleepDaySummary.empty;
    final trendDays = trendAsync.valueOrNull ?? const <SleepTrendDay>[];
    final metrics = detailAsync.valueOrNull?.metrics ?? const <MetricSeries>[];
    final isLoading = summaryAsync.isLoading && !summaryAsync.hasValue ||
        detailAsync.isLoading && !detailAsync.hasValue;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        AppDimens.spaceXs,
        0,
        AppDimens.bottomNavHeight + AppDimens.spaceMd,
      ),
      children: [
        // 1. Hero card
        _SleepHero(summary: summary, color: color),
        const SizedBox(height: AppDimens.spaceMd),

        // 2. 7-night primary chart
        if (trendDays.isNotEmpty)
          _SleepPrimaryChart(days: trendDays, color: color)
        else if (isLoading)
          const _ChartSkeleton()
        else
          const SizedBox.shrink(),
        const SizedBox(height: AppDimens.spaceMd),

        // 3. Stage breakdown
        if (summary.stages != null && summary.stages!.hasAnyData)
          ZSleepStageBreakdownCard(
            deepMinutes: summary.stages!.deepMinutes ?? 0,
            remMinutes: summary.stages!.remMinutes ?? 0,
            lightMinutes: summary.stages!.lightMinutes ?? 0,
            awakeMinutes: summary.stages!.awakeMinutes ?? 0,
            categoryColor: color,
          )
        else if (isLoading)
          const _StageSkeleton()
        else
          const SizedBox.shrink(),
        const SizedBox(height: AppDimens.spaceMd),

        // 4. Stats grid
        _SleepStatsGrid(summary: summary, color: color),
        const SizedBox(height: AppDimens.spaceMd),

        // 5. Per-metric cards
        if (metrics.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Sleep metrics',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColorsOf(context).textPrimary,
                    ),
                  ),
                ),
                for (var i = 0; i < metrics.length; i++) ...[
                  _SleepMetricCard(
                    series: metrics[i],
                    color: color,
                    displayUnit: displayUnit(metrics[i].unit, unitsSystem),
                  ),
                  if (i != metrics.length - 1)
                    const SizedBox(height: AppDimens.spaceMd),
                ],
              ],
            ),
          )
        else if (isLoading) ...[
          const SizedBox(height: AppDimens.spaceSm),
          const _MetricListSkeleton(),
        ],

        // 6. AI analysis
        if ((summary.aiSummary ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceMd),
          _AiAnalysisCard(text: summary.aiSummary!, color: color),
        ],
      ],
    );
  }
}

// ── _ActivityDetailBody ──────────────────────────────────────────────────────

/// Magazine-layout body for the Activity category detail screen.
///
/// Sections, top to bottom:
///  1. Hero card (today's steps + delta vs 7-day average).
///  2. 7-day bar chart with the 8k step goal line.
///  3. Today's progress ring — steps vs goal (+ optional active-cal inner ring).
///  4. 2×2 stats grid — steps / active minutes / distance / calories.
///  5. One card per sub-metric (bars for countables, line for continuous).
class _ActivityDetailBody extends ConsumerWidget {
  const _ActivityDetailBody({
    required this.color,
    required this.detailAsync,
    required this.unitsSystem,
  });

  final Color color;
  final AsyncValue<CategoryDetailData> detailAsync;
  final UnitsSystem unitsSystem;

  /// Daily step target. Kept local so the Activity branch doesn't need
  /// a new provider — tracked to move to user preferences in a follow-up.
  static const double _stepGoal = 8000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    // Locate the activity summary inside the dashboard, if present.
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

    final metrics = detailAsync.valueOrNull?.metrics ?? const <MetricSeries>[];
    final isLoading = dashboardAsync.isLoading && !dashboardAsync.hasValue ||
        detailAsync.isLoading && !detailAsync.hasValue;

    // ── Derive key values from metrics (with fallbacks) ───────────────────
    final stepsSeries = _findSeries(metrics, const ['steps']);
    final activeCaloriesSeries = _findSeries(
      metrics,
      const ['active_calories', 'calories_active', 'calories_burned'],
    );
    final distanceSeries = _findSeries(
      metrics,
      const ['distance', 'distance_m', 'distance_km'],
    );
    final activeMinutesSeries = _findSeries(
      metrics,
      const ['active_minutes', 'exercise_minutes'],
    );

    // Today's step count — prefer the latest raw metric point; fall back
    // to the dashboard primary value.
    final todaySteps = _latestValue(stepsSeries) ??
        (activitySummary?.trend?.lastOrNull) ??
        0.0;

    // 7-day trend of steps — prefer metric data points, else dashboard trend.
    final stepsTrend = _sevenDayValues(
      stepsSeries?.dataPoints.map((p) => p.value).toList() ??
          activitySummary?.trend ??
          const <double>[],
    );

    // 7-day average for delta calculation (excludes today when possible).
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

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        AppDimens.spaceXs,
        0,
        AppDimens.bottomNavHeight + AppDimens.spaceMd,
      ),
      children: [
        // 1. Hero card
        _ActivityHero(
          color: color,
          todaySteps: todaySteps,
          stepDelta: stepDelta,
          primaryValueOverride: activitySummary?.primaryValue,
        ),
        const SizedBox(height: AppDimens.spaceMd),

        // 2. 7-day primary chart (steps)
        if (stepsTrend.where((v) => v > 0).isNotEmpty)
          _ActivityPrimaryChart(
            color: color,
            values: stepsTrend,
          )
        else if (isLoading)
          const _ChartSkeleton()
        else
          const SizedBox.shrink(),
        const SizedBox(height: AppDimens.spaceMd),

        // 3. Signature visual — goal progress ring
        _ActivityGoalRingCard(
          color: color,
          todaySteps: todaySteps,
          stepGoal: _stepGoal,
          activeMinutes: todayActiveMinutes,
        ),
        const SizedBox(height: AppDimens.spaceMd),

        // 4. Stats grid
        _ActivityStatsGrid(
          color: color,
          unitsSystem: unitsSystem,
          steps: todaySteps,
          activeMinutes: todayActiveMinutes,
          distanceMeters: todayDistance,
          activeCalories: todayActiveCalories,
        ),
        const SizedBox(height: AppDimens.spaceMd),

        // 5. Per-metric cards
        if (metrics.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Activity metrics',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColorsOf(context).textPrimary,
                    ),
                  ),
                ),
                for (var i = 0; i < metrics.length; i++) ...[
                  _ActivityMetricCard(
                    series: metrics[i],
                    color: color,
                    displayUnit: displayUnit(metrics[i].unit, unitsSystem),
                    stepGoal: _stepGoal,
                  ),
                  if (i != metrics.length - 1)
                    const SizedBox(height: AppDimens.spaceMd),
                ],
              ],
            ),
          )
        else if (isLoading) ...[
          const SizedBox(height: AppDimens.spaceSm),
          const _MetricListSkeleton(),
        ],
      ],
    );
  }

  /// Finds the first metric series whose id matches any of [candidateIds].
  static MetricSeries? _findSeries(
    List<MetricSeries> metrics,
    List<String> candidateIds,
  ) {
    for (final id in candidateIds) {
      for (final s in metrics) {
        if (s.metricId.toLowerCase() == id) return s;
      }
    }
    return null;
  }

  /// Returns the latest finite value from a series, or `null`.
  static double? _latestValue(MetricSeries? s) {
    if (s == null) return null;
    for (var i = s.dataPoints.length - 1; i >= 0; i--) {
      final v = s.dataPoints[i].value;
      if (v.isFinite) return v;
    }
    return null;
  }

  /// Normalises an input list to exactly 7 entries, padding the head with
  /// 0.0 when too short and keeping the tail otherwise.
  static List<double> _sevenDayValues(List<double> input) {
    if (input.isEmpty) return const [0, 0, 0, 0, 0, 0, 0];
    if (input.length >= 7) {
      return input.sublist(input.length - 7);
    }
    return [
      for (var i = 0; i < 7 - input.length; i++) 0.0,
      ...input,
    ];
  }
}

// ── _ActivityHero ────────────────────────────────────────────────────────────

class _ActivityHero extends StatelessWidget {
  const _ActivityHero({
    required this.color,
    required this.todaySteps,
    required this.stepDelta,
    required this.primaryValueOverride,
  });

  final Color color;
  final double todaySteps;
  final int? stepDelta;

  /// Pre-formatted dashboard primary value (e.g. "8,432"). When provided
  /// this is preferred so the hero number matches the dashboard card.
  final String? primaryValueOverride;

  @override
  Widget build(BuildContext context) {
    final formattedValue =
        (primaryValueOverride != null && primaryValueOverride!.trim().isNotEmpty)
            ? primaryValueOverride!
            : _formatSteps(todaySteps);

    return InsightHeroCard(
      eyebrow: 'Today',
      categoryIcon: Icons.directions_walk_rounded,
      categoryColor: color,
      value: formattedValue,
      deltaLabel:
          stepDelta != null ? _formatStepsDeltaVsWeek(stepDelta!) : null,
      // Positive delta is a good thing for steps.
      deltaIsPositive: stepDelta != null ? stepDelta! >= 0 : null,
    );
  }
}

// ── _ActivityPrimaryChart ────────────────────────────────────────────────────

class _ActivityPrimaryChart extends StatelessWidget {
  const _ActivityPrimaryChart({required this.color, required this.values});

  final Color color;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final labels = _generateWeekLabels();
    return InsightPrimaryChart(
      title: "This week's steps",
      categoryColor: color,
      points: [
        for (var i = 0; i < values.length; i++)
          InsightPrimaryChartPoint(
            label: i < labels.length ? labels[i] : '',
            value: values[i],
            isToday: i == values.length - 1,
          ),
      ],
      goalValue: 8000,
      goalLabel: '8k goal',
      formatTooltip: (v) => '${v.toInt()} steps',
    );
  }
}

// ── _ActivityGoalRingCard ────────────────────────────────────────────────────

/// Feature card that hosts [ZGoalProgressRing] — today's steps vs goal,
/// optionally overlaid with an active-minutes inner ring.
class _ActivityGoalRingCard extends StatelessWidget {
  const _ActivityGoalRingCard({
    required this.color,
    required this.todaySteps,
    required this.stepGoal,
    required this.activeMinutes,
  });

  final Color color;
  final double todaySteps;
  final double stepGoal;
  final double? activeMinutes;

  /// Daily active minutes target — matches the WHO 30 min/day guideline.
  static const double _activeMinutesGoal = 30;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final hasInner = activeMinutes != null && activeMinutes! > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZFadeSlideIn(
        delay: const Duration(milliseconds: 210),
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
                  size: 180,
                  centerValue: _formatSteps(todaySteps),
                  centerLabel: 'steps',
                  innerValue: hasInner ? activeMinutes : null,
                  innerGoal: hasInner ? _activeMinutesGoal : null,
                  innerColor: hasInner ? colors.success : null,
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              // Legend row
              Row(
                children: [
                  Expanded(
                    child: _RingLegendRow(
                      dotColor: color,
                      label: 'Steps',
                      value:
                          '${_formatSteps(todaySteps)} / ${_formatSteps(stepGoal)}',
                    ),
                  ),
                ],
              ),
              if (hasInner) ...[
                const SizedBox(height: AppDimens.spaceXs),
                _RingLegendRow(
                  dotColor: colors.success,
                  label: 'Active minutes',
                  value:
                      '${activeMinutes!.round()} / ${_activeMinutesGoal.toInt()} min',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RingLegendRow extends StatelessWidget {
  const _RingLegendRow({
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

// ── _ActivityStatsGrid ───────────────────────────────────────────────────────

class _ActivityStatsGrid extends StatelessWidget {
  const _ActivityStatsGrid({
    required this.color,
    required this.unitsSystem,
    required this.steps,
    required this.activeMinutes,
    required this.distanceMeters,
    required this.activeCalories,
  });

  final Color color;
  final UnitsSystem unitsSystem;
  final double steps;
  final double? activeMinutes;
  final double? distanceMeters;
  final double? activeCalories;

  @override
  Widget build(BuildContext context) {
    // Distance: API stores in meters; convert to km/mi for display.
    String distanceLabel() {
      if (distanceMeters == null || !distanceMeters!.isFinite) return '—';
      final km = distanceMeters! / 1000.0;
      if (unitsSystem == UnitsSystem.imperial) {
        final mi = km * 0.621371;
        return '${mi.toStringAsFixed(1)} mi';
      }
      return '${km.toStringAsFixed(1)} km';
    }

    final tiles = <InsightStatTile>[
      InsightStatTile(
        icon: Icons.directions_walk_rounded,
        label: 'Steps',
        value: steps > 0 ? _formatSteps(steps) : '—',
      ),
      InsightStatTile(
        icon: Icons.timer_rounded,
        label: 'Active minutes',
        value: activeMinutes != null
            ? '${activeMinutes!.round()} min'
            : '—',
      ),
      InsightStatTile(
        icon: Icons.straighten_rounded,
        label: 'Distance',
        value: distanceLabel(),
      ),
      InsightStatTile(
        icon: Icons.local_fire_department_rounded,
        label: 'Calories',
        value: activeCalories != null
            ? '${activeCalories!.round()} kcal'
            : '—',
      ),
    ];

    return InsightStatsGrid(
      title: 'The details',
      categoryColor: color,
      tiles: tiles,
    );
  }
}

// ── _ActivityMetricCard ──────────────────────────────────────────────────────

/// Per-metric card for Activity. Picks a chart kind based on whether the
/// metric is countable (bars) or continuous (line).
class _ActivityMetricCard extends StatelessWidget {
  const _ActivityMetricCard({
    required this.series,
    required this.color,
    required this.displayUnit,
    required this.stepGoal,
  });

  final MetricSeries series;
  final Color color;
  final String displayUnit;
  final double stepGoal;

  /// Metric IDs that are countable-per-day (bars).
  static const _countableMetricIds = <String>{
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

  /// Metric IDs that are continuous (line).
  static const _continuousMetricIds = <String>{
    'walking_speed',
    'running_pace',
    'vo2_max',
    'cardio_fitness_level',
  };

  bool get _isCountable {
    final id = series.metricId.toLowerCase();
    return _countableMetricIds.contains(id);
  }

  bool get _isContinuous {
    final id = series.metricId.toLowerCase();
    return _continuousMetricIds.contains(id);
  }

  ZCategoryChartKind get _chartKind {
    if (_isCountable) return ZCategoryChartKind.bars;
    if (_isContinuous) return ZCategoryChartKind.line;
    // Unknown metric → line (safer default for fractional values).
    return ZCategoryChartKind.line;
  }

  double? get _goalValue {
    if (series.metricId.toLowerCase() == 'steps') return stepGoal;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final points = <double>[
      for (final p in series.dataPoints) p.value,
    ];
    // Pad/crop to 7 for the slim chart primitive, which expects 7 labels.
    final tail = points.length >= 7
        ? points.sublist(points.length - 7)
        : [
            for (var i = 0; i < 7 - points.length; i++) double.nan,
            ...points,
          ];
    final todayIndex = points.isNotEmpty ? 6 : -1;
    final dayLabels = _generateWeekLabels();

    final values = series.dataPoints.map((p) => p.value).toList();
    final avg = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final min = values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);
    final max = values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);

    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: color,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name + delta pill
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
              if (series.deltaPercent != null)
                _MetricCardDeltaPill(deltaPercent: series.deltaPercent!),
            ],
          ),
          const SizedBox(height: 4),
          // Hero value
          if (series.currentValue != null)
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: series.currentValue!,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      height: 1.15,
                    ),
                  ),
                  if (displayUnit.isNotEmpty)
                    TextSpan(
                      text: ' $displayUnit',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppDimens.spaceSm),
          // Chart slot
          if (series.dataPoints.length >= 2)
            SizedBox(
              height: 110,
              child: ZCategoryChart(
                kind: _chartKind,
                points: tail,
                color: color,
                dayLabels: dayLabels,
                todayIndex: todayIndex,
                goalValue: _goalValue,
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
          const SizedBox(height: AppDimens.spaceMd),
          // Avg / Min / Max strip
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Avg',
                  value: _formatActivityMetricValue(
                    avg,
                    metricId: series.metricId,
                    unit: displayUnit,
                  ),
                ),
              ),
              Expanded(
                child: _StatChip(
                  label: 'Min',
                  value: _formatActivityMetricValue(
                    min,
                    metricId: series.metricId,
                    unit: displayUnit,
                  ),
                ),
              ),
              Expanded(
                child: _StatChip(
                  label: 'Max',
                  value: _formatActivityMetricValue(
                    max,
                    metricId: series.metricId,
                    unit: displayUnit,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _HeartDetailBody ─────────────────────────────────────────────────────────

/// Magazine-layout body for the Heart category detail screen.
///
/// Sections, top to bottom:
///  1. Hero card (today's resting HR + delta vs 7-day resting HR average).
///  2. 7-day resting-HR line chart (no goal line).
///  3. Heart zones stacked bar (empty-state placeholder — no zone data yet).
///  4. 2×2 stats grid — RHR / HRV / Avg HR / Recovery.
///  5. One card per sub-metric (line for continuous HR metrics, bars for
///     countable metrics like workouts).
///  6. AI analysis card when a summary is available.
///
/// Notes on adaptations vs the original brief:
///  - The dashboard/today backend does not expose a maximum heart rate
///    field, so the third stats tile substitutes `avgHr` (Avg HR).
///  - There is no recovery score field yet — the Recovery tile renders
///    a dash until the backend adds one.
///  - [HeartDaySummary] has no per-zone minute breakdown, so the zones
///    card always uses [ZHeartZonesBar]'s empty-state placeholder.
class _HeartDetailBody extends ConsumerWidget {
  const _HeartDetailBody({
    required this.color,
    required this.detailAsync,
    required this.unitsSystem,
  });

  final Color color;
  final AsyncValue<CategoryDetailData> detailAsync;
  final UnitsSystem unitsSystem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(heartDaySummaryProvider);
    final trendAsync = ref.watch(heartTrendProvider('7d'));

    final summary = summaryAsync.valueOrNull ?? HeartDaySummary.empty;
    final trendDays = trendAsync.valueOrNull ?? const <HeartTrendDay>[];
    final metrics = detailAsync.valueOrNull?.metrics ?? const <MetricSeries>[];
    final isLoading = summaryAsync.isLoading && !summaryAsync.hasValue ||
        detailAsync.isLoading && !detailAsync.hasValue;

    // At least two resting-HR points are required for a meaningful line.
    final hasTrend = trendDays
            .where((d) => d.restingHr != null && d.restingHr!.isFinite)
            .length >=
        2;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        AppDimens.spaceXs,
        0,
        AppDimens.bottomNavHeight + AppDimens.spaceMd,
      ),
      children: [
        // 1. Hero card
        _HeartHero(summary: summary, color: color),
        const SizedBox(height: AppDimens.spaceMd),

        // 2. 7-day resting HR line chart
        if (hasTrend)
          _HeartPrimaryChart(days: trendDays, color: color)
        else if (isLoading)
          const _ChartSkeleton()
        else
          const SizedBox.shrink(),
        const SizedBox(height: AppDimens.spaceMd),

        // 3. Heart zones bar (empty state — no zone field yet)
        _HeartZonesCard(
          color: color,
          // No per-zone minute data on HeartDaySummary today — pass empty
          // so the bar renders its placeholder and the legend shows 0 min.
          minutes: const <ZHeartZone, int>{},
        ),
        const SizedBox(height: AppDimens.spaceMd),

        // 4. Stats grid
        _HeartStatsGrid(summary: summary, color: color),
        const SizedBox(height: AppDimens.spaceMd),

        // 5. Per-metric cards
        if (metrics.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Heart metrics',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColorsOf(context).textPrimary,
                    ),
                  ),
                ),
                for (var i = 0; i < metrics.length; i++) ...[
                  _HeartMetricCard(
                    series: metrics[i],
                    color: color,
                    displayUnit: displayUnit(metrics[i].unit, unitsSystem),
                  ),
                  if (i != metrics.length - 1)
                    const SizedBox(height: AppDimens.spaceMd),
                ],
              ],
            ),
          )
        else if (isLoading) ...[
          const SizedBox(height: AppDimens.spaceSm),
          const _MetricListSkeleton(),
        ],

        // 6. AI analysis
        if ((summary.aiSummary ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceMd),
          _AiAnalysisCard(text: summary.aiSummary!, color: color),
        ],
      ],
    );
  }
}

// ── _HeartHero ───────────────────────────────────────────────────────────────

class _HeartHero extends StatelessWidget {
  const _HeartHero({required this.summary, required this.color});

  final HeartDaySummary summary;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final rhr = summary.restingHr;
    final delta = summary.restingHrVs7Day;

    // Lower resting HR is better. A positive delta (RHR rose) is bad, and
    // a negative delta (RHR dropped) is good. Invert the sign for the
    // hero's "is positive?" flag so the pill tints correctly.
    final deltaIsPositive = delta == null
        ? null
        : (delta <= 0); // RHR dropped or flat → treated as good

    return InsightHeroCard(
      eyebrow: 'Today',
      categoryIcon: Icons.favorite_rounded,
      categoryColor: color,
      value: (rhr != null && rhr.isFinite) ? '${rhr.round()} bpm' : '—',
      deltaLabel:
          delta != null ? _formatHeartRateDeltaVsWeek(delta.round()) : null,
      deltaIsPositive: deltaIsPositive,
    );
  }
}

// ── _HeartPrimaryChart ───────────────────────────────────────────────────────

/// Feature-variant card wrapping a 200pt resting-HR line chart. Styled to
/// match [InsightPrimaryChart]'s card chrome (surface fill, border, title
/// row, radiusCard, spaceLg padding) so the Heart body feels cohesive with
/// the other categories' primary charts.
class _HeartPrimaryChart extends StatelessWidget {
  const _HeartPrimaryChart({required this.days, required this.color});

  final List<HeartTrendDay> days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    // Build the 7 raw values, aligned oldest → newest, with NaN for gaps.
    final points = <double>[
      for (final d in days)
        (d.restingHr != null && d.restingHr!.isFinite)
            ? d.restingHr!
            : double.nan,
    ];
    // Pad the head with NaN if there are fewer than 7 days of history.
    final tail = points.length >= 7
        ? points.sublist(points.length - 7)
        : [
            for (var i = 0; i < 7 - points.length; i++) double.nan,
            ...points,
          ];

    // Today is the last day in the series if it's marked, else the last
    // index when data exists.
    var todayIndex = -1;
    for (var i = days.length - 1; i >= 0; i--) {
      if (days[i].isToday) {
        todayIndex = i + (7 - days.length);
        break;
      }
    }
    if (todayIndex < 0 && tail.any((v) => v.isFinite)) {
      todayIndex = 6;
    }

    // Day labels: derive from trend dates when possible, else fall back to
    // the shared week-label helper.
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
      child: ZFadeSlideIn(
        delay: const Duration(milliseconds: 180),
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
      ),
    );
  }
}

// ── _HeartZonesCard ──────────────────────────────────────────────────────────

/// Feature card hosting [ZHeartZonesBar] — today's effort split across
/// Resting / Fat burn / Cardio / Peak zones. When no zone data is
/// available the bar draws a dim placeholder.
class _HeartZonesCard extends StatelessWidget {
  const _HeartZonesCard({
    required this.color,
    required this.minutes,
  });

  final Color color;
  final Map<ZHeartZone, int> minutes;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZFadeSlideIn(
        delay: const Duration(milliseconds: 210),
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
                minutes: minutes,
                categoryColor: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _HeartStatsGrid ──────────────────────────────────────────────────────────

class _HeartStatsGrid extends StatelessWidget {
  const _HeartStatsGrid({required this.summary, required this.color});

  final HeartDaySummary summary;
  final Color color;

  @override
  Widget build(BuildContext context) {
    String formatBpm(double? v) =>
        (v != null && v.isFinite) ? '${v.round()} bpm' : '—';
    String formatMs(double? v) =>
        (v != null && v.isFinite) ? '${v.round()} ms' : '—';

    final tiles = <InsightStatTile>[
      InsightStatTile(
        icon: Icons.favorite_rounded,
        label: 'Resting HR',
        value: formatBpm(summary.restingHr),
      ),
      InsightStatTile(
        icon: Icons.monitor_heart_rounded,
        label: 'HRV',
        value: formatMs(summary.hrvMs),
      ),
      // No max HR field on HeartDaySummary yet — substitute Avg HR so the
      // tile shows real data instead of a placeholder.
      InsightStatTile(
        icon: Icons.trending_up_rounded,
        label: 'Avg HR',
        value: formatBpm(summary.avgHr),
      ),
      // No recovery score field on HeartDaySummary yet — renders a dash.
      const InsightStatTile(
        icon: Icons.self_improvement_rounded,
        label: 'Recovery',
        value: '—',
      ),
    ];

    return InsightStatsGrid(
      title: 'The details',
      categoryColor: color,
      tiles: tiles,
    );
  }
}

// ── _HeartMetricCard ─────────────────────────────────────────────────────────

/// Per-metric card for Heart. Continuous rate-like metrics (resting HR,
/// HRV, max HR, walking HR) render as a line; countable metrics like
/// workouts-per-day render as bars; everything else defaults to a line.
class _HeartMetricCard extends StatelessWidget {
  const _HeartMetricCard({
    required this.series,
    required this.color,
    required this.displayUnit,
  });

  final MetricSeries series;
  final Color color;
  final String displayUnit;

  /// Metric ids that read best as a line (continuous rate-like).
  static const _continuousMetricIds = <String>{
    'resting_heart_rate',
    'hrv',
    'max_heart_rate',
    'walking_heart_rate',
    'heart_rate',
    'respiratory_rate',
    'vo2_max',
    'spo2',
  };

  /// Metric ids that read best as bars (countable-per-day).
  static const _countableMetricIds = <String>{
    'workouts',
    'workouts_count',
  };

  bool get _isContinuous {
    final id = series.metricId.toLowerCase();
    return _continuousMetricIds.contains(id);
  }

  bool get _isCountable {
    final id = series.metricId.toLowerCase();
    return _countableMetricIds.contains(id);
  }

  ZCategoryChartKind get _chartKind {
    if (_isCountable) return ZCategoryChartKind.bars;
    if (_isContinuous) return ZCategoryChartKind.line;
    // Unknown — line is the safer default for Heart metrics, which are
    // overwhelmingly rate-like.
    return ZCategoryChartKind.line;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final points = <double>[
      for (final p in series.dataPoints) p.value,
    ];
    final tail = points.length >= 7
        ? points.sublist(points.length - 7)
        : [
            for (var i = 0; i < 7 - points.length; i++) double.nan,
            ...points,
          ];
    final todayIndex = points.isNotEmpty ? 6 : -1;
    final dayLabels = _generateWeekLabels();

    final values = series.dataPoints.map((p) => p.value).toList();
    final avg = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final min = values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);
    final max = values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);

    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: color,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name + delta pill
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
              if (series.deltaPercent != null)
                _MetricCardDeltaPill(deltaPercent: series.deltaPercent!),
            ],
          ),
          const SizedBox(height: 4),
          // Hero value
          if (series.currentValue != null)
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: series.currentValue!,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      height: 1.15,
                    ),
                  ),
                  if (displayUnit.isNotEmpty)
                    TextSpan(
                      text: ' $displayUnit',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppDimens.spaceSm),
          // Chart slot
          if (series.dataPoints.length >= 2)
            SizedBox(
              height: 110,
              child: ZCategoryChart(
                kind: _chartKind,
                points: tail,
                color: color,
                dayLabels: dayLabels,
                todayIndex: todayIndex,
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
          const SizedBox(height: AppDimens.spaceMd),
          // Avg / Min / Max strip
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Avg',
                  value: _formatMetricValue(
                    avg,
                    metricId: series.metricId,
                    unit: displayUnit,
                  ),
                ),
              ),
              Expanded(
                child: _StatChip(
                  label: 'Min',
                  value: _formatMetricValue(
                    min,
                    metricId: series.metricId,
                    unit: displayUnit,
                  ),
                ),
              ),
              Expanded(
                child: _StatChip(
                  label: 'Max',
                  value: _formatMetricValue(
                    max,
                    metricId: series.metricId,
                    unit: displayUnit,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _NutritionDetailBody ─────────────────────────────────────────────────────

/// Magazine-layout body for the Nutrition category detail screen.
///
/// Sections, top to bottom:
///  1. Hero card (today's calories + delta vs last-week average).
///  2. 7-day calorie bar chart with 2,000 kcal goal line.
///  3. Macro donut — today's carbs / protein / fat split, with legend.
///  4. 2×2 stats grid — calories / protein / carbs / fat.
///  5. One card per sub-metric (bars for countable totals, line for continuous).
///  6. AI analysis card when a summary is available.
///
/// Notes on adaptations vs the original brief:
///  - [NutritionDaySummary] has no calorie goal field today, so the
///    primary chart defaults to 2,000 kcal and labels it "2,000 goal".
///  - Calorie trend can be higher or lower — neither direction is
///    "better" — so the hero uses [deltaIsPositive] = `null` and the
///    pill renders in a neutral tint.
class _NutritionDetailBody extends ConsumerWidget {
  const _NutritionDetailBody({
    required this.color,
    required this.detailAsync,
    required this.unitsSystem,
  });

  final Color color;
  final AsyncValue<CategoryDetailData> detailAsync;
  // ignore: unused_element_parameter
  final UnitsSystem unitsSystem;

  /// Daily calorie target used for the primary chart's goal line. Kept
  /// local because [NutritionDaySummary] doesn't carry a goal field yet
  /// — tracked to move to user preferences in a follow-up.
  static const double _calorieGoal = 2000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(nutritionDaySummaryProvider);
    final trendAsync = ref.watch(nutritionTrendProvider('7d'));

    final summary = summaryAsync.valueOrNull ?? NutritionDaySummary.empty;
    final trendDays =
        trendAsync.valueOrNull ?? const <NutritionTrendDay>[];
    final metrics = detailAsync.valueOrNull?.metrics ?? const <MetricSeries>[];
    final isLoading = summaryAsync.isLoading && !summaryAsync.hasValue ||
        detailAsync.isLoading && !detailAsync.hasValue;

    // Delta vs last-week average calories. Skips today when computing
    // the average so the hero pill compares "today vs the days before".
    final historical = trendDays
        .where((d) => !d.isToday && d.calories != null && d.calories!.isFinite)
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

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        AppDimens.spaceXs,
        0,
        AppDimens.bottomNavHeight + AppDimens.spaceMd,
      ),
      children: [
        // 1. Hero card
        _NutritionHero(
          color: color,
          totalKcal: summary.totalCalories,
          kcalDelta: kcalDelta,
        ),
        const SizedBox(height: AppDimens.spaceMd),

        // 2. 7-day calorie bar chart
        if (hasCalorieTrend)
          _NutritionPrimaryChart(
            days: trendDays,
            color: color,
            goalValue: _calorieGoal,
          )
        else if (isLoading)
          const _ChartSkeleton()
        else
          const SizedBox.shrink(),
        const SizedBox(height: AppDimens.spaceMd),

        // 3. Macro donut (signature visual)
        _NutritionMacroDonutCard(summary: summary, color: color),
        const SizedBox(height: AppDimens.spaceMd),

        // 4. Stats grid
        _NutritionStatsGrid(summary: summary, color: color),
        const SizedBox(height: AppDimens.spaceMd),

        // 5. Per-metric cards
        if (metrics.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Nutrition metrics',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColorsOf(context).textPrimary,
                    ),
                  ),
                ),
                for (var i = 0; i < metrics.length; i++) ...[
                  _NutritionMetricCard(
                    series: metrics[i],
                    color: color,
                    displayUnit: displayUnit(metrics[i].unit, unitsSystem),
                    calorieGoal: _calorieGoal,
                  ),
                  if (i != metrics.length - 1)
                    const SizedBox(height: AppDimens.spaceMd),
                ],
              ],
            ),
          )
        else if (isLoading) ...[
          const SizedBox(height: AppDimens.spaceSm),
          const _MetricListSkeleton(),
        ],

        // 6. AI analysis
        if ((summary.aiSummary ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceMd),
          _AiAnalysisCard(text: summary.aiSummary!, color: color),
        ],
      ],
    );
  }
}

// ── _NutritionHero ───────────────────────────────────────────────────────────

class _NutritionHero extends StatelessWidget {
  const _NutritionHero({
    required this.color,
    required this.totalKcal,
    required this.kcalDelta,
  });

  final Color color;
  final int totalKcal;
  final int? kcalDelta;

  @override
  Widget build(BuildContext context) {
    return InsightHeroCard(
      eyebrow: 'Today',
      categoryIcon: Icons.local_fire_department_rounded,
      categoryColor: color,
      value: totalKcal > 0 ? '${_formatSteps(totalKcal.toDouble())} kcal' : '—',
      deltaLabel:
          kcalDelta != null ? _formatCalorieDeltaVsWeek(kcalDelta!) : null,
      // Calorie delta is direction-agnostic — neither "up" nor "down" is
      // objectively better. `null` keeps the pill in the neutral tint.
      deltaIsPositive: null,
    );
  }
}

// ── _NutritionPrimaryChart ──────────────────────────────────────────────────

class _NutritionPrimaryChart extends StatelessWidget {
  const _NutritionPrimaryChart({
    required this.days,
    required this.color,
    required this.goalValue,
  });

  final List<NutritionTrendDay> days;
  final Color color;
  final double goalValue;

  @override
  Widget build(BuildContext context) {
    return InsightPrimaryChart(
      title: '7-day calories',
      categoryColor: color,
      points: [
        for (final d in days)
          InsightPrimaryChartPoint(
            label: _weekdayLetter(d.date),
            value: (d.calories ?? 0).toDouble(),
            isToday: d.isToday,
          ),
      ],
      goalValue: goalValue,
      goalLabel: '${_formatSteps(goalValue)} goal',
      formatTooltip: (v) => '${v.toInt()} kcal',
      formatYAxis: (v) => v >= 1000
          ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k'
          : v.round().toString(),
    );
  }
}

// ── _NutritionMacroDonutCard ────────────────────────────────────────────────

/// Feature card hosting [ZMacroDonut] — today's carbs / protein / fat
/// split, with a legend row per macro underneath. Renders a friendly
/// empty-state caption when no macros have been logged yet today.
class _NutritionMacroDonutCard extends StatelessWidget {
  const _NutritionMacroDonutCard({
    required this.summary,
    required this.color,
  });

  final NutritionDaySummary summary;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final carbs = summary.totalCarbsG;
    final protein = summary.totalProteinG;
    final fat = summary.totalFatG;
    final totalMacros = carbs + protein + fat;
    final hasData = totalMacros > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZFadeSlideIn(
        delay: const Duration(milliseconds: 210),
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
              if (hasData) ...[
                Center(
                  child: ZMacroDonut(
                    proteinGrams: protein,
                    carbsGrams: carbs,
                    fatGrams: fat,
                    categoryColor: color,
                    centerValue:
                        _formatSteps(summary.totalCalories.toDouble()),
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
    );
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

// ── _NutritionStatsGrid ─────────────────────────────────────────────────────

class _NutritionStatsGrid extends StatelessWidget {
  const _NutritionStatsGrid({required this.summary, required this.color});

  final NutritionDaySummary summary;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tiles = <InsightStatTile>[
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
        value:
            summary.totalProteinG > 0 ? '${summary.totalProteinG.round()}g' : '—',
      ),
      InsightStatTile(
        icon: Icons.grain_rounded,
        label: 'Carbs',
        value:
            summary.totalCarbsG > 0 ? '${summary.totalCarbsG.round()}g' : '—',
      ),
      InsightStatTile(
        icon: Icons.opacity_rounded,
        label: 'Fat',
        value: summary.totalFatG > 0 ? '${summary.totalFatG.round()}g' : '—',
      ),
    ];

    return InsightStatsGrid(
      title: 'The details',
      categoryColor: color,
      tiles: tiles,
    );
  }
}

// ── _NutritionMetricCard ────────────────────────────────────────────────────

/// Per-metric card for Nutrition. Countable daily totals (calories,
/// macros, water) render as bars; any continuous/ratio metric renders
/// as a line; unknowns default to bars.
class _NutritionMetricCard extends StatelessWidget {
  const _NutritionMetricCard({
    required this.series,
    required this.color,
    required this.displayUnit,
    required this.calorieGoal,
  });

  final MetricSeries series;
  final Color color;
  final String displayUnit;
  final double calorieGoal;

  /// Metric ids that are countable-per-day (bars).
  static const _countableMetricIds = <String>{
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

  /// Metric ids that read best as a line (continuous ratios or scores).
  static const _continuousMetricIds = <String>{
    'protein_ratio',
    'carbs_ratio',
    'fat_ratio',
    'macro_ratio',
    'nutrition_score',
  };

  bool get _isCountable {
    final id = series.metricId.toLowerCase();
    return _countableMetricIds.contains(id);
  }

  bool get _isContinuous {
    final id = series.metricId.toLowerCase();
    return _continuousMetricIds.contains(id);
  }

  ZCategoryChartKind get _chartKind {
    if (_isContinuous) return ZCategoryChartKind.line;
    if (_isCountable) return ZCategoryChartKind.bars;
    // Unknown metric → bars (safer default for daily totals, which
    // dominate the Nutrition category).
    return ZCategoryChartKind.bars;
  }

  double? get _goalValue {
    final id = series.metricId.toLowerCase();
    if (id == 'calories' ||
        id == 'calories_consumed' ||
        id == 'total_calories') {
      return calorieGoal;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final points = <double>[
      for (final p in series.dataPoints) p.value,
    ];
    // Pad/crop to 7 for the slim chart primitive, which expects 7 labels.
    final tail = points.length >= 7
        ? points.sublist(points.length - 7)
        : [
            for (var i = 0; i < 7 - points.length; i++) double.nan,
            ...points,
          ];
    final todayIndex = points.isNotEmpty ? 6 : -1;
    final dayLabels = _generateWeekLabels();

    final values = series.dataPoints.map((p) => p.value).toList();
    final avg = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final min = values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);
    final max = values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);

    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: color,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name + delta pill
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
              if (series.deltaPercent != null)
                _MetricCardDeltaPill(deltaPercent: series.deltaPercent!),
            ],
          ),
          const SizedBox(height: 4),
          // Hero value
          if (series.currentValue != null)
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: series.currentValue!,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      height: 1.15,
                    ),
                  ),
                  if (displayUnit.isNotEmpty)
                    TextSpan(
                      text: ' $displayUnit',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppDimens.spaceSm),
          // Chart slot
          if (series.dataPoints.length >= 2)
            SizedBox(
              height: 110,
              child: ZCategoryChart(
                kind: _chartKind,
                points: tail,
                color: color,
                dayLabels: dayLabels,
                todayIndex: todayIndex,
                goalValue: _goalValue,
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
          const SizedBox(height: AppDimens.spaceMd),
          // Avg / Min / Max strip
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Avg',
                  value: _formatMetricValue(
                    avg,
                    metricId: series.metricId,
                    unit: displayUnit,
                  ),
                ),
              ),
              Expanded(
                child: _StatChip(
                  label: 'Min',
                  value: _formatMetricValue(
                    min,
                    metricId: series.metricId,
                    unit: displayUnit,
                  ),
                ),
              ),
              Expanded(
                child: _StatChip(
                  label: 'Max',
                  value: _formatMetricValue(
                    max,
                    metricId: series.metricId,
                    unit: displayUnit,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _BodyDetailBody ──────────────────────────────────────────────────────────

/// Magazine-layout body for the Body category detail screen.
///
/// Sections, top to bottom:
///  1. Hero card (latest weight + delta vs 7-day average).
///  2. Weight line chart over the selected time range (title dynamic).
///  3. BMI signature gauge — empty-state caption when height is unknown.
///  4. 2×2 stats grid — Weight / Body fat / BMI / Body temp.
///  5. One card per sub-metric (continuous body metrics render as lines).
///  6. AI analysis card when a body day summary field ever exposes one
///     (skipped today — no `aiSummary` on any body model).
///
/// Notes on adaptations vs the brief:
///  - There is no `bodyDaySummaryProvider` or `BodyDaySummary` in the
///    codebase today. Body latest values are pulled from
///    [categoryDetailProvider]'s metric series with
///    [dashboardProvider]'s [CategorySummary] as a fallback for the
///    hero value.
///  - BMI is computed from weight + height because the model doesn't
///    expose a BMI value directly. Height comes from
///    [userProfileProvider]'s `heightCm` field; when that is null we
///    render the empty-state caption and skip the gauge.
///  - Weight delta direction is neither "up good" nor "down good" — the
///    hero pill stays neutral (`deltaIsPositive: null`).
class _BodyDetailBody extends ConsumerWidget {
  const _BodyDetailBody({
    required this.color,
    required this.detailAsync,
    required this.unitsSystem,
    required this.selectedRange,
  });

  final Color color;
  final AsyncValue<CategoryDetailData> detailAsync;
  final UnitsSystem unitsSystem;

  /// The active time-range tab (7D / 30D / 90D / Custom) — drives the
  /// dynamic primary-chart title.
  final TimeRange selectedRange;

  /// Metric ids that read best as a line in the per-metric cards — every
  /// real body metric is continuous.
  static const _continuousMetricIds = <String>{
    'weight',
    'body_fat',
    'bmi',
    'body_temperature',
    'wrist_temperature',
    'spo2',
    'blood_glucose',
    'lean_body_mass',
    'waist_circumference',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final profile = ref.watch(userProfileProvider);

    // Locate the body summary inside the dashboard, if present.
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

    final metrics = detailAsync.valueOrNull?.metrics ?? const <MetricSeries>[];
    final isLoading = dashboardAsync.isLoading && !dashboardAsync.hasValue ||
        detailAsync.isLoading && !detailAsync.hasValue;

    // Primary weight series — prefer the metric points, fall back to the
    // dashboard trend (which is already 7 values in display units).
    final weightSeries = _findSeries(metrics, const ['weight']);
    final bodyFatSeries = _findSeries(metrics, const ['body_fat', 'body_fat_percent']);
    final bodyTempSeries = _findSeries(
      metrics,
      const ['body_temperature', 'wrist_temperature'],
    );
    final bmiSeries = _findSeries(metrics, const ['bmi']);

    // Latest weight — prefer raw metric value (already in API units), fall
    // back to the dashboard primaryValue (pre-formatted). The raw value is
    // kept in kg because metric values are stored metric and converted at
    // display time, matching Activity's distance handling.
    final latestWeightKg = _latestValue(weightSeries);
    final hasTodayWeight = weightSeries != null &&
        weightSeries.dataPoints.isNotEmpty &&
        weightSeries.dataPoints.last.value.isFinite;

    // 7-day (or selected-range) raw weight values for the chart + delta.
    final rawWeightValues = weightSeries != null
        ? weightSeries.dataPoints
            .map((p) => p.value)
            .where((v) => v.isFinite)
            .toList()
        : (bodySummary?.trend ?? const <double>[]);

    // Average of the trend excluding the last point for delta.
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

    // Latest body fat / BMI / temp.
    final latestBodyFat = _latestValue(bodyFatSeries);
    final latestBodyTemp = _latestValue(bodyTempSeries);
    final latestBmiFromMetric = _latestValue(bmiSeries);

    // Compute BMI from weight + height when the metric isn't directly
    // reported. Height is stored in cm on the user profile; skip when
    // unknown so we never fabricate the value.
    final heightCm = profile?.heightCm;
    final canComputeBmi = heightCm != null &&
        heightCm > 0 &&
        latestWeightKg != null &&
        latestWeightKg > 0;
    final double? bmiValue = latestBmiFromMetric ??
        (canComputeBmi
            ? latestWeightKg / math.pow(heightCm / 100.0, 2)
            : null);

    // Pre-formatted dashboard weight (e.g. "78.2"). Prefer this for the
    // hero value so the number matches the category card.
    final dashboardWeightLabel = bodySummary?.primaryValue;
    final dashboardWeightUnit = bodySummary?.unit;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        AppDimens.spaceXs,
        0,
        AppDimens.bottomNavHeight + AppDimens.spaceMd,
      ),
      children: [
        // 1. Hero card
        _BodyHero(
          color: color,
          weightKg: latestWeightKg,
          weightDeltaKg: weightDeltaKg,
          unitsSystem: unitsSystem,
          fallbackPrimaryValue: dashboardWeightLabel,
          fallbackUnit: dashboardWeightUnit,
          hasTodayWeight: hasTodayWeight,
        ),
        const SizedBox(height: AppDimens.spaceMd),

        // 2. Primary chart — weight line over the selected range.
        if (rawWeightValues.where((v) => v > 0).length >= 2)
          _BodyPrimaryChart(
            color: color,
            valuesKg: rawWeightValues,
            selectedRange: selectedRange,
            unitsSystem: unitsSystem,
          )
        else if (isLoading)
          const _ChartSkeleton()
        else
          const SizedBox.shrink(),
        const SizedBox(height: AppDimens.spaceMd),

        // 3. Signature visual — BMI gauge (or height-missing caption).
        _BodyBmiCard(color: color, bmi: bmiValue),
        const SizedBox(height: AppDimens.spaceMd),

        // 4. Stats grid
        _BodyStatsGrid(
          color: color,
          unitsSystem: unitsSystem,
          weightKg: latestWeightKg,
          bodyFatPct: latestBodyFat,
          bmi: bmiValue,
          bodyTempC: latestBodyTemp,
        ),
        const SizedBox(height: AppDimens.spaceMd),

        // 5. Per-metric cards
        if (metrics.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Body metrics',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColorsOf(context).textPrimary,
                    ),
                  ),
                ),
                for (var i = 0; i < metrics.length; i++) ...[
                  _BodyMetricCard(
                    series: metrics[i],
                    color: color,
                    displayUnit: displayUnit(metrics[i].unit, unitsSystem),
                    continuousMetricIds: _continuousMetricIds,
                  ),
                  if (i != metrics.length - 1)
                    const SizedBox(height: AppDimens.spaceMd),
                ],
              ],
            ),
          )
        else if (isLoading) ...[
          const SizedBox(height: AppDimens.spaceSm),
          const _MetricListSkeleton(),
        ],
      ],
    );
  }

  /// Finds the first metric series whose id matches any of [candidateIds].
  static MetricSeries? _findSeries(
    List<MetricSeries> metrics,
    List<String> candidateIds,
  ) {
    for (final id in candidateIds) {
      for (final s in metrics) {
        if (s.metricId.toLowerCase() == id) return s;
      }
    }
    return null;
  }

  /// Returns the latest finite value from a series, or `null`.
  static double? _latestValue(MetricSeries? s) {
    if (s == null) return null;
    for (var i = s.dataPoints.length - 1; i >= 0; i--) {
      final v = s.dataPoints[i].value;
      if (v.isFinite) return v;
    }
    return null;
  }
}

// ── _BodyHero ────────────────────────────────────────────────────────────────

class _BodyHero extends StatelessWidget {
  const _BodyHero({
    required this.color,
    required this.weightKg,
    required this.weightDeltaKg,
    required this.unitsSystem,
    required this.fallbackPrimaryValue,
    required this.fallbackUnit,
    required this.hasTodayWeight,
  });

  final Color color;
  final double? weightKg;
  final double? weightDeltaKg;
  final UnitsSystem unitsSystem;

  /// Dashboard primary value label (e.g. "78.2"). Used when a raw metric
  /// weight isn't available so the hero stays in sync with the card.
  final String? fallbackPrimaryValue;

  /// Dashboard primary value unit ("kg" / "lb") — paired with the
  /// fallback label above.
  final String? fallbackUnit;

  /// Whether the weight series has a finite value at its tail (today).
  /// Drives the eyebrow wording ("Today" vs "Latest").
  final bool hasTodayWeight;

  @override
  Widget build(BuildContext context) {
    final String formattedValue;
    if (weightKg != null && weightKg!.isFinite) {
      formattedValue = _formatWeight(weightKg!, unitsSystem);
    } else if (fallbackPrimaryValue != null &&
        fallbackPrimaryValue!.trim().isNotEmpty) {
      final unit = (fallbackUnit != null && fallbackUnit!.isNotEmpty)
          ? ' ${displayUnit(fallbackUnit!, unitsSystem)}'
          : '';
      formattedValue = '$fallbackPrimaryValue$unit';
    } else {
      formattedValue = '—';
    }

    final deltaLabel = (weightDeltaKg != null && weightDeltaKg!.isFinite)
        ? _formatWeightDeltaVsWeek(weightDeltaKg!, unitsSystem)
        : null;

    return InsightHeroCard(
      eyebrow: hasTodayWeight ? 'Today' : 'Latest',
      categoryIcon: Icons.accessibility_new_rounded,
      categoryColor: color,
      value: formattedValue,
      deltaLabel: deltaLabel,
      // Weight delta direction is direction-agnostic for the hero pill —
      // neither gaining nor losing is universally "better".
      deltaIsPositive: null,
    );
  }
}

// ── _BodyPrimaryChart ────────────────────────────────────────────────────────

/// Feature-variant card wrapping a 200pt weight line chart. Styled to
/// match [InsightPrimaryChart]'s card chrome (surface fill, title row,
/// radiusCard, spaceLg padding) so the Body body feels cohesive with the
/// other categories' primary charts.
class _BodyPrimaryChart extends StatelessWidget {
  const _BodyPrimaryChart({
    required this.color,
    required this.valuesKg,
    required this.selectedRange,
    required this.unitsSystem,
  });

  final Color color;
  final List<double> valuesKg;
  final TimeRange selectedRange;
  final UnitsSystem unitsSystem;

  String get _title {
    switch (selectedRange) {
      case TimeRange.days7:
        return '7-day weight';
      case TimeRange.days30:
        return '30-day weight';
      case TimeRange.days90:
        return '90-day weight';
      case TimeRange.custom:
        return 'Weight trend';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    // Convert to display units for the chart axis.
    final displayValues = [
      for (final v in valuesKg)
        v.isFinite ? _kgToDisplay(v, unitsSystem) : double.nan,
    ];

    // The slim chart primitive expects 7 entries. When the series is
    // longer (30D/90D) we downsample by taking evenly-spaced indexes so
    // the shape stays readable without invisible clutter.
    final tail = _fitSeven(displayValues);
    final todayIndex = tail.any((v) => v.isFinite) ? 6 : -1;

    // Labels: for 7D, use weekday letters. For longer ranges we keep the
    // labels blank — downsampled x-axis would mislabel points.
    final labels = selectedRange == TimeRange.days7
        ? _generateWeekLabels()
        : const ['', '', '', '', '', '', ''];

    final unitSuffix = unitsSystem == UnitsSystem.imperial ? 'lb' : 'kg';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZFadeSlideIn(
        delay: const Duration(milliseconds: 180),
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
                _title,
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
                  formatY: (v) => '${v.toStringAsFixed(v >= 100 ? 0 : 1)} '
                      '$unitSuffix',
                  height: 200,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Downsamples or pads [values] to exactly seven entries. When the
  /// series is shorter than seven the head is padded with NaN so the
  /// line starts with the first known value.
  static List<double> _fitSeven(List<double> values) {
    if (values.isEmpty) {
      return List.filled(7, double.nan);
    }
    if (values.length == 7) return values;
    if (values.length < 7) {
      return [
        for (var i = 0; i < 7 - values.length; i++) double.nan,
        ...values,
      ];
    }
    // Evenly sample 7 indexes from a longer series.
    final out = <double>[];
    for (var i = 0; i < 7; i++) {
      final idx = ((i * (values.length - 1)) / 6).round();
      out.add(values[idx.clamp(0, values.length - 1)]);
    }
    return out;
  }
}

// ── _BodyBmiCard ─────────────────────────────────────────────────────────────

/// Feature card hosting [ZBmiGauge] — today's BMI with coloured bands
/// and a needle. Falls back to an empty-state caption when height is
/// unknown so we never fabricate the value.
class _BodyBmiCard extends StatelessWidget {
  const _BodyBmiCard({required this.color, required this.bmi});

  final Color color;
  final double? bmi;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZFadeSlideIn(
        delay: const Duration(milliseconds: 210),
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
                Center(child: ZBmiGauge(bmi: bmi!))
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
      ),
    );
  }
}

// ── _BodyStatsGrid ───────────────────────────────────────────────────────────

class _BodyStatsGrid extends StatelessWidget {
  const _BodyStatsGrid({
    required this.color,
    required this.unitsSystem,
    required this.weightKg,
    required this.bodyFatPct,
    required this.bmi,
    required this.bodyTempC,
  });

  final Color color;
  final UnitsSystem unitsSystem;
  final double? weightKg;
  final double? bodyFatPct;
  final double? bmi;
  final double? bodyTempC;

  @override
  Widget build(BuildContext context) {
    final tiles = <InsightStatTile>[
      InsightStatTile(
        icon: Icons.monitor_weight_rounded,
        label: 'Weight',
        value: (weightKg != null && weightKg!.isFinite)
            ? _formatWeight(weightKg!, unitsSystem)
            : '—',
      ),
      InsightStatTile(
        icon: Icons.percent_rounded,
        label: 'Body fat',
        value: (bodyFatPct != null && bodyFatPct!.isFinite)
            ? '${bodyFatPct!.toStringAsFixed(bodyFatPct! >= 100 ? 0 : 1)}%'
            : '—',
      ),
      InsightStatTile(
        icon: Icons.straighten_rounded,
        label: 'BMI',
        value:
            (bmi != null && bmi!.isFinite) ? bmi!.toStringAsFixed(1) : '—',
      ),
      InsightStatTile(
        icon: Icons.thermostat_rounded,
        label: 'Body temp',
        value: (bodyTempC != null && bodyTempC!.isFinite)
            ? _formatTemperature(bodyTempC!, unitsSystem)
            : '—',
      ),
    ];

    return InsightStatsGrid(
      title: 'The details',
      categoryColor: color,
      tiles: tiles,
    );
  }
}

// ── _BodyMetricCard ──────────────────────────────────────────────────────────

/// Per-metric card for Body. Every body sub-metric is continuous by
/// nature, so all charts render as a line (a catch-all also lines).
class _BodyMetricCard extends StatelessWidget {
  const _BodyMetricCard({
    required this.series,
    required this.color,
    required this.displayUnit,
    required this.continuousMetricIds,
  });

  final MetricSeries series;
  final Color color;
  final String displayUnit;
  final Set<String> continuousMetricIds;

  ZCategoryChartKind get _chartKind {
    // Body metrics are continuous (weight, body fat, BMI, temperatures,
    // SpO2, glucose). Catch-all also lines — bars don't fit anything on
    // the Body screen.
    return ZCategoryChartKind.line;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final points = <double>[
      for (final p in series.dataPoints) p.value,
    ];
    // Pad/crop to 7 for the slim chart primitive, which expects 7 labels.
    final tail = points.length >= 7
        ? points.sublist(points.length - 7)
        : [
            for (var i = 0; i < 7 - points.length; i++) double.nan,
            ...points,
          ];
    final todayIndex = points.isNotEmpty ? 6 : -1;
    final dayLabels = _generateWeekLabels();

    final values = series.dataPoints.map((p) => p.value).toList();
    final avg = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final min = values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);
    final max = values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);

    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: color,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name + delta pill
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
              if (series.deltaPercent != null)
                _MetricCardDeltaPill(deltaPercent: series.deltaPercent!),
            ],
          ),
          const SizedBox(height: 4),
          // Hero value
          if (series.currentValue != null)
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: series.currentValue!,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      height: 1.15,
                    ),
                  ),
                  if (displayUnit.isNotEmpty)
                    TextSpan(
                      text: ' $displayUnit',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppDimens.spaceSm),
          // Chart slot
          if (series.dataPoints.length >= 2)
            SizedBox(
              height: 110,
              child: ZCategoryChart(
                kind: _chartKind,
                points: tail,
                color: color,
                dayLabels: dayLabels,
                todayIndex: todayIndex,
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
          const SizedBox(height: AppDimens.spaceMd),
          // Avg / Min / Max strip
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Avg',
                  value: _formatMetricValue(
                    avg,
                    metricId: series.metricId,
                    unit: displayUnit,
                  ),
                ),
              ),
              Expanded(
                child: _StatChip(
                  label: 'Min',
                  value: _formatMetricValue(
                    min,
                    metricId: series.metricId,
                    unit: displayUnit,
                  ),
                ),
              ),
              Expanded(
                child: _StatChip(
                  label: 'Max',
                  value: _formatMetricValue(
                    max,
                    metricId: series.metricId,
                    unit: displayUnit,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _SleepHero ────────────────────────────────────────────────────────────────

class _SleepHero extends StatelessWidget {
  const _SleepHero({required this.summary, required this.color});

  final SleepDaySummary summary;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final duration = summary.durationMinutes;
    final delta = summary.avgVs7DayMinutes;

    return InsightHeroCard(
      eyebrow: 'Last night',
      categoryIcon: Icons.bedtime_rounded,
      categoryColor: color,
      value: duration != null ? _formatDuration(duration) : '—',
      deltaLabel: delta != null ? _formatDeltaVsWeek(delta) : null,
      deltaIsPositive: delta != null ? delta >= 0 : null,
      qualityLabel: summary.qualityLabel,
    );
  }
}

// ── _SleepPrimaryChart ────────────────────────────────────────────────────────

class _SleepPrimaryChart extends StatelessWidget {
  const _SleepPrimaryChart({required this.days, required this.color});

  final List<SleepTrendDay> days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InsightPrimaryChart(
      title: 'Last 7 nights',
      categoryColor: color,
      points: [
        for (final d in days)
          InsightPrimaryChartPoint(
            label: _weekdayLetter(d.date),
            value: (d.durationMinutes ?? 0).toDouble(),
            isToday: d.isToday,
          ),
      ],
      goalValue: 480, // 8 hours in minutes
      goalLabel: '8h goal',
      formatTooltip: (v) => _formatDuration(v.round()),
      formatYAxis: (v) => '${(v / 60).round()}h',
    );
  }
}

// ── _SleepStatsGrid ───────────────────────────────────────────────────────────

class _SleepStatsGrid extends StatelessWidget {
  const _SleepStatsGrid({required this.summary, required this.color});

  final SleepDaySummary summary;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tiles = <InsightStatTile>[
      InsightStatTile(
        icon: Icons.nights_stay_rounded,
        label: 'Bedtime',
        value: summary.bedtime != null ? _formatTime(summary.bedtime!) : '—',
      ),
      InsightStatTile(
        icon: Icons.alarm_rounded,
        label: 'Wake time',
        value: summary.wakeTime != null ? _formatTime(summary.wakeTime!) : '—',
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
            ? '${summary.interruptions} ${summary.interruptions == 1 ? 'time' : 'times'}'
            : '—',
      ),
    ];

    return InsightStatsGrid(
      title: 'The details',
      categoryColor: color,
      tiles: tiles,
    );
  }
}

// ── _SleepMetricCard ──────────────────────────────────────────────────────────

/// One card per metric returned by [categoryDetailProvider]. Picks a chart
/// kind based on the metric id / unit:
///  - durations + stage lengths → [ZCategoryChartKind.bars]
///  - efficiency / % metrics   → [ZCategoryChartKind.line]
///  - everything else          → [ZCategoryChartKind.line]
class _SleepMetricCard extends StatelessWidget {
  const _SleepMetricCard({
    required this.series,
    required this.color,
    required this.displayUnit,
  });

  final MetricSeries series;
  final Color color;
  final String displayUnit;

  static const _durationMetricIds = <String>{
    'sleep_duration',
    'deep_sleep',
    'rem_sleep',
    'light_sleep',
    'awake_time',
  };

  bool get _isDurationMetric {
    final id = series.metricId.toLowerCase();
    if (_durationMetricIds.contains(id)) return true;
    return id.contains('duration');
  }

  bool get _isPercentMetric {
    final id = series.metricId.toLowerCase();
    if (series.unit == '%') return true;
    return id.contains('efficiency') || id.contains('score');
  }

  ZCategoryChartKind get _chartKind {
    if (_isDurationMetric) return ZCategoryChartKind.bars;
    if (_isPercentMetric) return ZCategoryChartKind.line;
    return ZCategoryChartKind.line;
  }

  double? get _goalValue {
    if (series.metricId.toLowerCase() == 'sleep_duration') return 480;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final points = <double>[
      for (final p in series.dataPoints) p.value,
    ];
    // Pad/crop to 7 for the slim chart primitive, which expects 7 labels.
    final tail = points.length >= 7
        ? points.sublist(points.length - 7)
        : [
            for (var i = 0; i < 7 - points.length; i++) double.nan,
            ...points,
          ];
    final todayIndex = points.isNotEmpty ? 6 : -1;
    final dayLabels = _generateWeekLabels();

    final values = series.dataPoints.map((p) => p.value).toList();
    final avg = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final min = values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);
    final max = values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);

    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: color,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name + delta pill
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
              if (series.deltaPercent != null)
                _MetricCardDeltaPill(deltaPercent: series.deltaPercent!),
            ],
          ),
          const SizedBox(height: 4),
          // Hero value
          if (series.currentValue != null)
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: series.currentValue!,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      height: 1.15,
                    ),
                  ),
                  if (displayUnit.isNotEmpty)
                    TextSpan(
                      text: ' $displayUnit',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppDimens.spaceSm),
          // Chart slot
          if (series.dataPoints.length >= 2)
            SizedBox(
              height: 110,
              child: ZCategoryChart(
                kind: _chartKind,
                points: tail,
                color: color,
                dayLabels: dayLabels,
                todayIndex: todayIndex,
                goalValue: _goalValue,
                formatY: _isDurationMetric
                    ? (v) => '${(v / 60).round()}h'
                    : null,
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
          const SizedBox(height: AppDimens.spaceMd),
          // Avg / Min / Max strip
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Avg',
                  value: _formatMetricValue(
                    avg,
                    metricId: series.metricId,
                    unit: displayUnit,
                  ),
                ),
              ),
              Expanded(
                child: _StatChip(
                  label: 'Min',
                  value: _formatMetricValue(
                    min,
                    metricId: series.metricId,
                    unit: displayUnit,
                  ),
                ),
              ),
              Expanded(
                child: _StatChip(
                  label: 'Max',
                  value: _formatMetricValue(
                    max,
                    metricId: series.metricId,
                    unit: displayUnit,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _MetricCardDeltaPill ──────────────────────────────────────────────────────

class _MetricCardDeltaPill extends StatelessWidget {
  const _MetricCardDeltaPill({required this.deltaPercent});

  final double deltaPercent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final ZCategoryDelta direction;
    if (deltaPercent > 0) {
      direction = ZCategoryDelta.better;
    } else if (deltaPercent < 0) {
      direction = ZCategoryDelta.worse;
    } else {
      direction = ZCategoryDelta.flat;
    }
    final Color bg;
    final Color fg;
    switch (direction) {
      case ZCategoryDelta.better:
        bg = colors.success.withValues(alpha: 0.14);
        fg = colors.success;
        break;
      case ZCategoryDelta.worse:
        bg = colors.warning.withValues(alpha: 0.14);
        fg = colors.warning;
        break;
      case ZCategoryDelta.flat:
      case ZCategoryDelta.none:
        bg = colors.surfaceRaised;
        fg = colors.textSecondary;
        break;
    }
    final sign = deltaPercent > 0 ? '+' : '';
    final label = '$sign${deltaPercent.toStringAsFixed(1)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
      ),
    );
  }
}

// ── _StatChip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textTertiary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── _AiAnalysisCard ───────────────────────────────────────────────────────────

class _AiAnalysisCard extends StatelessWidget {
  const _AiAnalysisCard({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZuralogCard(
        variant: ZCardVariant.feature,
        category: color,
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
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
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI Analysis',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shimmer placeholders ──────────────────────────────────────────────────────

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZLoadingSkeleton(
        width: double.infinity,
        height: 210,
        borderRadius: AppDimens.radiusCard,
      ),
    );
  }
}

class _StageSkeleton extends StatelessWidget {
  const _StageSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZLoadingSkeleton(
        width: double.infinity,
        height: 180,
        borderRadius: AppDimens.radiusCard,
      ),
    );
  }
}

class _MetricListSkeleton extends StatelessWidget {
  const _MetricListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Column(
        children: const [
          ZLoadingSkeleton(
            width: double.infinity,
            height: 220,
            borderRadius: AppDimens.radiusCard,
          ),
          SizedBox(height: AppDimens.spaceMd),
          ZLoadingSkeleton(
            width: double.infinity,
            height: 220,
            borderRadius: AppDimens.radiusCard,
          ),
        ],
      ),
    );
  }
}

// ── _MetricChartCard (legacy — non-Sleep categories) ─────────────────────────

/// A card showing a metric's name, current value, and fl_chart line chart.
class _MetricChartCard extends StatefulWidget {
  const _MetricChartCard({
    required this.series,
    required this.color,
    required this.displayUnit,
    required this.onTap,
  });

  final MetricSeries series;
  final Color color;
  final String displayUnit;
  final VoidCallback onTap;

  @override
  State<_MetricChartCard> createState() => _MetricChartCardState();
}

class _MetricChartCardState extends State<_MetricChartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_MetricChartCard old) {
    super.didUpdateWidget(old);
    // MED-02: replay animation when the data series changes (e.g. time range switch)
    if (old.series.metricId != widget.series.metricId ||
        old.series.dataPoints.length != widget.series.dataPoints.length) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final series = widget.series;
    final color = widget.color;

    final spots = [
      for (var i = 0; i < series.dataPoints.length; i++)
        FlSpot(i.toDouble(), series.dataPoints[i].value),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          series.displayName,
                          style: AppTextStyles.titleMedium,
                        ),
                        if (series.currentValue != null) ...[
                          const SizedBox(height: 2),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: series.currentValue!,
                                  style: AppTextStyles.displaySmall.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (widget.displayUnit.isNotEmpty)
                                  TextSpan(
                                    text: ' ${widget.displayUnit}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (series.deltaPercent != null)
                    _DeltaBadge(delta: series.deltaPercent!),
                  const SizedBox(width: AppDimens.spaceSm),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                    size: AppDimens.iconMd,
                  ),
                ],
              ),

              // Chart (only when data points available)
              if (spots.length >= 2) ...[
                const SizedBox(height: AppDimens.spaceMd),
                FadeTransition(
                  opacity: _opacity,
                  child: SizedBox(
                    height: 80,
                    child: _buildChart(context, spots, color),
                  ),
                ),
              ] else if (spots.length == 1) ...[
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'Only one data point available',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<FlSpot> spots, Color color) {
    final colors = AppColorsOf(context);
    final values = spots.map((s) => s.y).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) == 0 ? 1.0 : (maxY - minY) * 0.1;

    return LineChart(
      LineChartData(
        minY: minY - padding,
        maxY: maxY + padding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 3).clamp(0.1, 1e9),
          getDrawingHorizontalLine: (value) => FlLine(
            color: colors.border.withValues(alpha: 0.5),
            strokeWidth: 0.5,
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
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.surface,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(1)} ${widget.displayUnit}',
                      AppTextStyles.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }
}

// ── _DeltaBadge ───────────────────────────────────────────────────────────────

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta});
  final double delta;

  @override
  Widget build(BuildContext context) {
    final isUp = delta > 0;
    final isFlat = delta == 0;
    final color = isFlat
        ? AppColors.textTertiary
        : isUp
            ? AppColors.healthScoreGreen
            : AppColors.healthScoreRed;
    final icon = isFlat
        ? Icons.remove_rounded
        : isUp
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;
    final label =
        isFlat ? '0%' : '${isUp ? '+' : ''}${delta.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _MetricCardSkeleton ───────────────────────────────────────────────────────

class _MetricCardSkeleton extends StatelessWidget {
  const _MetricCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

// ── Format helpers ────────────────────────────────────────────────────────────

/// Formats a minute count as `7h 24m`. Returns `—` for 0, null, or negatives.
String _formatDuration(int? minutes) {
  if (minutes == null || minutes <= 0) return '—';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// Formats a time of day as `10:30 PM`.
String _formatTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $period';
}

/// Formats a minute delta as `+18m` / `-22m` / `-1h 10m`. Returns null
/// when the input is null.
// Coverage note: retained for future use when individual metric cards show
// minute-based deltas alongside their current value.
// ignore: unused_element
String? _formatDeltaMinutes(int? minutes) {
  if (minutes == null) return null;
  final abs = minutes.abs();
  final sign = minutes >= 0 ? '+' : '-';
  if (abs < 60) return '$sign${abs}m';
  final h = abs ~/ 60;
  final m = abs % 60;
  if (m == 0) return '$sign${h}h';
  return '$sign${h}h ${m}m';
}

/// Formats a `vs last week` delta pill label for the hero card.
String _formatDeltaVsWeek(int minutes) {
  final abs = minutes.abs();
  final sign = minutes >= 0 ? '+' : '-';
  final body = abs >= 60
      ? (abs % 60 == 0 ? '${abs ~/ 60}h' : '${abs ~/ 60}h ${abs % 60}m')
      : '${abs}m';
  return '$sign$body vs last week';
}

/// Converts an ISO date to a weekday letter (M/T/W/T/F/S/S).
String _weekdayLetter(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return '';
  const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return names[d.weekday - 1];
}

/// Generates a 7-day label list ending in today's weekday letter.
List<String> _generateWeekLabels() {
  const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final today = DateTime.now();
  final todayIdx = today.weekday - 1;
  final labels = <String>[];
  for (var i = 6; i >= 0; i--) {
    labels.add(names[(todayIdx - i) % 7 < 0
        ? (todayIdx - i) % 7 + 7
        : (todayIdx - i) % 7]);
  }
  return labels;
}

/// Formats a step count with thousands separators (e.g. `8,420`).
String _formatSteps(double steps) {
  if (!steps.isFinite || steps < 0) return '0';
  final rounded = steps.round();
  final s = rounded.toString();
  // Insert commas every three digits from the right.
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final fromRight = s.length - i;
    buf.write(s[i]);
    if (fromRight > 1 && fromRight % 3 == 1) buf.write(',');
  }
  return buf.toString();
}

/// Formats a steps-vs-week delta as `+1,200 vs last week` / `-340 vs last week`.
String _formatStepsDeltaVsWeek(int delta) {
  final sign = delta >= 0 ? '+' : '-';
  return '$sign${_formatSteps(delta.abs().toDouble())} vs last week';
}

/// Formats a heart-rate delta (in bpm) as `+4 bpm vs last week` or
/// `-4 bpm vs last week`. Zero renders without a sign.
String _formatHeartRateDeltaVsWeek(int delta) {
  if (delta == 0) return '0 bpm vs last week';
  final sign = delta > 0 ? '+' : '-';
  return '$sign${delta.abs()} bpm vs last week';
}

/// Formats a calorie delta (kcal) as `+120 kcal vs last week` or
/// `-80 kcal vs last week`. Zero renders without a sign.
String _formatCalorieDeltaVsWeek(int delta) {
  if (delta == 0) return '0 kcal vs last week';
  final sign = delta > 0 ? '+' : '-';
  return '$sign${_formatSteps(delta.abs().toDouble())} kcal vs last week';
}

/// Formats a raw Activity metric value for the Avg/Min/Max strip.
///
/// Large-count metrics (steps, distance in meters) are rendered compactly
/// (e.g. `8.4k`) while continuous metrics fall back to one decimal place.
String _formatActivityMetricValue(
  double? value, {
  required String metricId,
  required String unit,
}) {
  if (value == null || !value.isFinite) return '—';
  final id = metricId.toLowerCase();

  // Step counts — render as `8.4k` when ≥1000, else integer.
  if (id == 'steps') {
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
    }
    return value.round().toString();
  }

  // Distance stored in meters — render as km with one decimal.
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

/// Converts a weight in kilograms to the user's display unit (kg or lb).
double _kgToDisplay(double kg, UnitsSystem system) {
  if (system == UnitsSystem.imperial) return kg * 2.20462;
  return kg;
}

/// Formats a weight (in kilograms) for the user's display unit, e.g.
/// `178.4 lb` or `80.9 kg`. Returns `—` when the value is non-finite.
String _formatWeight(double kg, UnitsSystem system) {
  if (!kg.isFinite) return '—';
  final v = _kgToDisplay(kg, system);
  final unit = system == UnitsSystem.imperial ? 'lb' : 'kg';
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} $unit';
}

/// Formats a weight delta (kilograms) vs the 7-day average for the hero
/// pill. Example outputs: `-0.8 lb vs last week`, `+0.4 kg vs last week`.
String _formatWeightDeltaVsWeek(double deltaKg, UnitsSystem system) {
  if (!deltaKg.isFinite) return '';
  final displayDelta = _kgToDisplay(deltaKg, system);
  final abs = displayDelta.abs();
  final unit = system == UnitsSystem.imperial ? 'lb' : 'kg';
  final sign = displayDelta > 0 ? '+' : (displayDelta < 0 ? '-' : '');
  final magnitude = abs.toStringAsFixed(abs >= 100 ? 0 : 1);
  return '$sign$magnitude $unit vs last week';
}

/// Formats a temperature (Celsius) to the user's display unit. Returns
/// `—` for non-finite input.
String _formatTemperature(double celsius, UnitsSystem system) {
  if (!celsius.isFinite) return '—';
  if (system == UnitsSystem.imperial) {
    final f = celsius * 9 / 5 + 32;
    return '${f.toStringAsFixed(1)}°F';
  }
  return '${celsius.toStringAsFixed(1)}°C';
}

/// Formats a raw numeric metric value for the Avg/Min/Max strip.
String _formatMetricValue(
  double? value, {
  required String metricId,
  required String unit,
}) {
  if (value == null || !value.isFinite) return '—';
  final id = metricId.toLowerCase();
  // Duration-type metrics come in minutes — render as `7h 24m`.
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
  final rendered = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  if (unit.isEmpty) return rendered;
  return '$rendered $unit';
}
