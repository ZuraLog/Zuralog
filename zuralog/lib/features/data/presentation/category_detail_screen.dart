/// Category Detail Screen — pushed from Health Dashboard.
///
/// Drill-down into a specific health category (Activity, Sleep, Heart, etc.).
///
/// Sleep uses a richer "magazine" body: hero duration, 7-night bar chart
/// with 8h goal line, stage donut for last night, a 2×2 stats grid
/// (bedtime / wake / efficiency / wakeups), and per-metric cards with
/// chart types matched to each sub-metric.
///
/// Every other category still renders the original flat line-chart list
/// until their own redesign pass lands.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/unit_converter.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
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
            child: cat == HealthCategory.sleep
                ? _SleepDetailBody(
                    color: color,
                    detailAsync: detailAsync,
                    unitsSystem: unitsSystem,
                  )
                : _buildLegacyBody(context, colors, cat, color, unitsSystem,
                    detailAsync),
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
