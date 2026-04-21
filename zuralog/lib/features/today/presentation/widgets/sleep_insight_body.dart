/// Sleep-variant body sections for the Insight Detail screen.
///
/// Composes the shared insight primitives (hero card, primary chart,
/// stats grid) plus a bespoke stage donut. Everything reads from
/// existing sleep providers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/sleep/domain/sleep_models.dart';
import 'package:zuralog/features/sleep/providers/sleep_providers.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_hero_card.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_primary_chart.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_stats_grid.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Returns the rich sleep-insight slivers. Call this from the detail screen
/// when `detail.category == 'sleep'`.
List<Widget> sleepInsightSlivers(BuildContext context, WidgetRef ref) {
  return const [
    SliverToBoxAdapter(child: _SleepHero()),
    SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),
    SliverToBoxAdapter(child: _StageBreakdown()),
    SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),
    SliverToBoxAdapter(child: _SleepTrendChart()),
    SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),
    SliverToBoxAdapter(child: _SleepStats()),
  ];
}

// ── Hero ─────────────────────────────────────────────────────────────────────

class _SleepHero extends ConsumerWidget {
  const _SleepHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(sleepDaySummaryProvider).valueOrNull ??
        SleepDaySummary.empty;
    final duration = summary.durationMinutes;
    final delta = summary.avgVs7DayMinutes;

    return InsightHeroCard(
      eyebrow: 'Last night',
      categoryIcon: Icons.bedtime_rounded,
      categoryColor: AppColors.categorySleep,
      value: duration != null ? _formatDuration(duration) : '—',
      deltaLabel: delta != null ? _formatDelta(delta) : null,
      deltaIsPositive: delta != null ? delta >= 0 : null,
      qualityLabel: summary.qualityLabel,
    );
  }

  String _formatDelta(int minutes) {
    final abs = minutes.abs();
    final sign = minutes >= 0 ? '+' : '-';
    final body = abs >= 60
        ? (abs % 60 == 0 ? '${abs ~/ 60}h' : '${abs ~/ 60}h ${abs % 60}m')
        : '${abs}m';
    return '$sign$body vs last week';
  }
}

// ── Trend chart ──────────────────────────────────────────────────────────────

class _SleepTrendChart extends ConsumerWidget {
  const _SleepTrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(sleepTrendProvider('7d')).valueOrNull ??
        const <SleepTrendDay>[];
    if (days.isEmpty) return const SizedBox.shrink();

    return InsightPrimaryChart(
      title: 'Last 7 nights',
      categoryColor: AppColors.categorySleep,
      points: [
        for (final d in days)
          InsightPrimaryChartPoint(
            label: _weekdayShort(d.date),
            value: (d.durationMinutes ?? 0).toDouble(),
            isToday: d.isToday,
          ),
      ],
      goalValue: 450, // 7h 30m
      goalLabel: 'Goal 7h 30m',
      formatTooltip: (v) => _formatDuration(v.round()),
      formatYAxis: (v) => '${(v / 60).round()}h',
    );
  }

  String _weekdayShort(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    if (d == null) return '';
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return names[d.weekday - 1];
  }
}

// ── Stats grid ───────────────────────────────────────────────────────────────

class _SleepStats extends ConsumerWidget {
  const _SleepStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(sleepDaySummaryProvider).valueOrNull ??
        SleepDaySummary.empty;
    final tiles = <InsightStatTile>[
      if (summary.bedtime != null)
        InsightStatTile(
          icon: Icons.nights_stay_outlined,
          label: 'Bedtime',
          value: _formatTime(summary.bedtime!),
        ),
      if (summary.wakeTime != null)
        InsightStatTile(
          icon: Icons.wb_twilight_rounded,
          label: 'Wake up',
          value: _formatTime(summary.wakeTime!),
        ),
      if (summary.sleepEfficiencyPct != null)
        InsightStatTile(
          icon: Icons.insights_rounded,
          label: 'Efficiency',
          value: '${summary.sleepEfficiencyPct!.round()}%',
        ),
      if (summary.interruptions != null)
        InsightStatTile(
          icon: Icons.surround_sound_rounded,
          label: 'Wake ups',
          value: summary.interruptions.toString(),
        ),
    ];
    return InsightStatsGrid(
      title: 'The details',
      categoryColor: AppColors.categorySleep,
      tiles: tiles,
    );
  }
}

// ── Stage donut (bespoke to Sleep) ───────────────────────────────────────────

class _StageBreakdown extends ConsumerWidget {
  const _StageBreakdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(sleepDaySummaryProvider).valueOrNull ??
        SleepDaySummary.empty;
    final stages = summary.stages;
    if (stages == null || !stages.hasAnyData) {
      return const SizedBox.shrink();
    }

    return ZSleepStageBreakdownCard(
      deepMinutes: stages.deepMinutes ?? 0,
      remMinutes: stages.remMinutes ?? 0,
      lightMinutes: stages.lightMinutes ?? 0,
      awakeMinutes: stages.awakeMinutes ?? 0,
      categoryColor: AppColors.categorySleep,
      title: 'Sleep stages',
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _formatDuration(int minutes) {
  if (minutes <= 0) return '—';
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
