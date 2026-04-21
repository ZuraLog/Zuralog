/// Heart-variant body for the Insight Detail screen.
/// Reads from existing heart providers; no backend changes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/heart/domain/heart_models.dart';
import 'package:zuralog/features/heart/providers/heart_providers.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_hero_card.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_primary_chart.dart';
import 'package:zuralog/features/today/presentation/widgets/insight_stats_grid.dart';

List<Widget> heartInsightSlivers(BuildContext context, WidgetRef ref) {
  return const [
    SliverToBoxAdapter(child: _HeartHero()),
    SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),
    SliverToBoxAdapter(child: _HeartTrendChart()),
    SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),
    SliverToBoxAdapter(child: _HeartStats()),
  ];
}

class _HeartHero extends ConsumerWidget {
  const _HeartHero();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(heartDaySummaryProvider).valueOrNull ??
        HeartDaySummary.empty;
    final rhr = summary.restingHr;
    final delta = summary.restingHrVs7Day;
    // Lower RHR is better → flip the "positive" flag.
    return InsightHeroCard(
      eyebrow: 'Resting heart rate',
      categoryIcon: Icons.favorite_rounded,
      categoryColor: AppColors.categoryHeart,
      value: rhr != null ? '${rhr.round()} bpm' : '—',
      deltaLabel: delta != null
          ? '${delta >= 0 ? '+' : '-'}${delta.abs().toStringAsFixed(0)} bpm vs last week'
          : null,
      deltaIsPositive: delta != null ? delta <= 0 : null,
      qualityLabel: null,
    );
  }
}

class _HeartTrendChart extends ConsumerWidget {
  const _HeartTrendChart();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(heartTrendProvider('7d')).valueOrNull ??
        const <HeartTrendDay>[];
    if (days.isEmpty) return const SizedBox.shrink();
    return InsightPrimaryChart(
      title: 'Resting heart rate — 7 days',
      categoryColor: AppColors.categoryHeart,
      points: [
        for (final d in days)
          InsightPrimaryChartPoint(
            label: _weekdayShort(d.date),
            value: (d.restingHr ?? 0).toDouble(),
            isToday: d.isToday,
          ),
      ],
      formatTooltip: (v) => '${v.toStringAsFixed(0)} bpm',
    );
  }

  String _weekdayShort(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    if (d == null) return '';
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return names[d.weekday - 1];
  }
}

class _HeartStats extends ConsumerWidget {
  const _HeartStats();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(heartDaySummaryProvider).valueOrNull ??
        HeartDaySummary.empty;
    final tiles = <InsightStatTile>[
      if (summary.restingHr != null)
        InsightStatTile(
          icon: Icons.favorite_rounded,
          label: 'Resting HR',
          value: '${summary.restingHr!.round()} bpm',
        ),
      if (summary.hrvMs != null)
        InsightStatTile(
          icon: Icons.graphic_eq_rounded,
          label: 'HRV',
          value: '${summary.hrvMs!.round()} ms',
        ),
      if (summary.respiratoryRate != null)
        InsightStatTile(
          icon: Icons.air_rounded,
          label: 'Resp rate',
          value: '${summary.respiratoryRate!.toStringAsFixed(1)}/min',
        ),
      if (summary.vo2Max != null)
        InsightStatTile(
          icon: Icons.directions_run_rounded,
          label: 'VO₂ max',
          value: summary.vo2Max!.toStringAsFixed(0),
        ),
    ];
    return InsightStatsGrid(
      title: 'The details',
      categoryColor: AppColors.categoryHeart,
      tiles: tiles,
    );
  }
}
