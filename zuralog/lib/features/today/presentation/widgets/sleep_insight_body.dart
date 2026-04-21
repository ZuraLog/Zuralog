/// Sleep-variant body sections for the Insight Detail screen.
///
/// Composes the shared insight primitives (hero card, primary chart,
/// stats grid) plus a bespoke stage donut. Everything reads from
/// existing sleep providers.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
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
    SliverToBoxAdapter(child: _StageBreakdownCard()),
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

class _StageBreakdownCard extends ConsumerWidget {
  const _StageBreakdownCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final summary = ref.watch(sleepDaySummaryProvider).valueOrNull ??
        SleepDaySummary.empty;
    final stages = summary.stages;
    if (stages == null || !stages.hasAnyData) {
      return const SizedBox.shrink();
    }

    final total = stages.totalMinutes;
    final segments = <_StageSegment>[
      _StageSegment('Deep', stages.deepMinutes ?? 0, const Color(0xFF2F4A3A)),
      _StageSegment('REM', stages.remMinutes ?? 0, const Color(0xFF6D9A7A)),
      _StageSegment('Light', stages.lightMinutes ?? 0, const Color(0xFFCFE1B9)),
      _StageSegment('Awake', stages.awakeMinutes ?? 0, const Color(0xFFE07A5F)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZFadeSlideIn(
        delay: const Duration(milliseconds: 120),
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
                'Sleep stages',
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: _StageRingPainter(
                        segments: segments,
                        trackColor: colors.border.withValues(alpha: 0.3),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatDuration(total),
                              style: AppTextStyles.titleMedium.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'total',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceLg),
                  Expanded(
                    child: Column(
                      children: [
                        for (final s in segments)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: s.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    s.label,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  total > 0
                                      ? '${((s.minutes / total) * 100).round()}%'
                                      : '—',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    _formatDuration(s.minutes),
                                    textAlign: TextAlign.right,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: colors.textTertiary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageSegment {
  const _StageSegment(this.label, this.minutes, this.color);
  final String label;
  final int minutes;
  final Color color;
}

class _StageRingPainter extends CustomPainter {
  _StageRingPainter({required this.segments, required this.trackColor});
  final List<_StageSegment> segments;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2 - 6;
    const stroke = 12.0;
    final track = Paint()
      ..color = trackColor
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, track);
    final total = segments.fold<int>(0, (a, s) => a + s.minutes);
    if (total <= 0) return;
    const gap = 0.04;
    double start = -math.pi / 2;
    for (final s in segments) {
      if (s.minutes <= 0) continue;
      final sweep = (s.minutes / total) * (math.pi * 2);
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start + gap / 2,
        sweep - gap,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _StageRingPainter old) =>
      old.segments != segments || old.trackColor != trackColor;
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
