/// Sleep-variant body sections for the Insight Detail screen.
///
/// When the insight's `category == 'sleep'`, the detail screen renders
/// these sections between the header and the Discuss-with-Coach pill.
/// Everything reads from existing sleep providers — no backend changes
/// required.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/sleep/domain/sleep_models.dart';
import 'package:zuralog/features/sleep/providers/sleep_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Public entry ──────────────────────────────────────────────────────────────

/// Returns the rich sleep-insight slivers. Call this from the detail screen
/// when `detail.category == 'sleep'`.
List<Widget> sleepInsightSlivers(BuildContext context, WidgetRef ref) {
  return const [
    SliverToBoxAdapter(child: _HeroMetricCard()),
    SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),
    SliverToBoxAdapter(child: _StageBreakdownCard()),
    SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),
    SliverToBoxAdapter(child: _SevenDayDurationChart()),
    SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),
    SliverToBoxAdapter(child: _KeyStatsGrid()),
  ];
}

// ── 1. Hero metric card ───────────────────────────────────────────────────────

class _HeroMetricCard extends ConsumerWidget {
  const _HeroMetricCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final summaryAsync = ref.watch(sleepDaySummaryProvider);
    final summary = summaryAsync.valueOrNull ?? SleepDaySummary.empty;

    final duration = summary.durationMinutes;
    final delta = summary.avgVs7DayMinutes;
    final quality = summary.qualityLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZFadeSlideIn(
        delay: const Duration(milliseconds: 60),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.cardBackground,
                      AppColors.categorySleep.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.categorySleep.withValues(alpha: 0.18),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceLg,
                  AppDimens.spaceLg,
                  AppDimens.spaceLg,
                  AppDimens.spaceLg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bedtime_rounded,
                          size: 18,
                          color: AppColors.categorySleep,
                        ),
                        const SizedBox(width: AppDimens.spaceXs),
                        Text(
                          'Last night',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    Text(
                      duration != null ? _formatDuration(duration) : '—',
                      style: GoogleFonts.lora(
                        textStyle: AppTextStyles.displayLarge.copyWith(
                          color: colors.textPrimary,
                          fontSize: 44,
                          height: 1.05,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    Row(
                      children: [
                        if (delta != null) _DeltaBadge(minutes: delta),
                        if (delta != null && quality != null)
                          const SizedBox(width: AppDimens.spaceSm),
                        if (quality != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              quality,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
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

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.minutes});
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final isUp = minutes >= 0;
    final color = isUp ? AppColors.success : AppColors.warning;
    final label = isUp
        ? '+${_formatDelta(minutes)} vs last week'
        : '${_formatDelta(minutes)} vs last week';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDelta(int minutes) {
    final abs = minutes.abs();
    if (abs >= 60) {
      final h = abs ~/ 60;
      final m = abs % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    return '${abs}m';
  }
}

// ── 2. Stage breakdown ring ───────────────────────────────────────────────────

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
      _StageSegment(
        label: 'Deep',
        minutes: stages.deepMinutes ?? 0,
        color: const Color(0xFF2F4A3A),
      ),
      _StageSegment(
        label: 'REM',
        minutes: stages.remMinutes ?? 0,
        color: const Color(0xFF6D9A7A),
      ),
      _StageSegment(
        label: 'Light',
        minutes: stages.lightMinutes ?? 0,
        color: const Color(0xFFCFE1B9),
      ),
      _StageSegment(
        label: 'Awake',
        minutes: stages.awakeMinutes ?? 0,
        color: const Color(0xFFE07A5F),
      ),
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
  const _StageSegment({
    required this.label,
    required this.minutes,
    required this.color,
  });
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

// ── 3. 7-day duration bar chart ───────────────────────────────────────────────

class _SevenDayDurationChart extends ConsumerWidget {
  const _SevenDayDurationChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final trendAsync = ref.watch(sleepTrendProvider('7d'));
    final days = trendAsync.valueOrNull ?? const <SleepTrendDay>[];

    if (days.isEmpty) return const SizedBox.shrink();

    final maxMinutes = days
        .map((d) => (d.durationMinutes ?? 0).toDouble())
        .fold<double>(0, math.max);
    final maxY = math.max(maxMinutes, 480) * 1.15;
    const targetMinutes = 450.0; // 7h 30m

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Last 7 nights',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppColors.categorySleep.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Goal 7h 30m',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceMd),
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 120,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: colors.border.withValues(alpha: 0.25),
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
                            final i = value.toInt();
                            if (i < 0 || i >= days.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _weekdayShort(days[i].date),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: days[i].isToday
                                      ? colors.textPrimary
                                      : colors.textTertiary,
                                  fontWeight: days[i].isToday
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: targetMinutes,
                          color:
                              AppColors.categorySleep.withValues(alpha: 0.45),
                          strokeWidth: 1.5,
                          dashArray: [4, 4],
                        ),
                      ],
                    ),
                    barGroups: [
                      for (var i = 0; i < days.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: (days[i].durationMinutes ?? 0).toDouble(),
                              color: days[i].isToday
                                  ? AppColors.categorySleep
                                  : AppColors.categorySleep.withValues(
                                      alpha: 0.38,
                                    ),
                              width: 18,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxY,
                                color: AppColors.categorySleep
                                    .withValues(alpha: 0.06),
                              ),
                            ),
                          ],
                        ),
                    ],
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => colors.surface,
                        getTooltipItem: (group, _, rod, rodIdx) {
                          return BarTooltipItem(
                            _formatDuration(rod.toY.round()),
                            AppTextStyles.bodySmall.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _weekdayShort(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    if (d == null) return '';
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return names[d.weekday - 1];
  }
}

// ── 4. Key stats grid ─────────────────────────────────────────────────────────

class _KeyStatsGrid extends ConsumerWidget {
  const _KeyStatsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(sleepDaySummaryProvider).valueOrNull ??
        SleepDaySummary.empty;

    final tiles = <_StatTile>[
      if (summary.bedtime != null)
        _StatTile(
          icon: Icons.nights_stay_outlined,
          label: 'Bedtime',
          value: _formatTime(summary.bedtime!),
        ),
      if (summary.wakeTime != null)
        _StatTile(
          icon: Icons.wb_twilight_rounded,
          label: 'Wake up',
          value: _formatTime(summary.wakeTime!),
        ),
      if (summary.sleepEfficiencyPct != null)
        _StatTile(
          icon: Icons.insights_rounded,
          label: 'Efficiency',
          value: '${summary.sleepEfficiencyPct!.round()}%',
        ),
      if (summary.interruptions != null)
        _StatTile(
          icon: Icons.surround_sound_rounded,
          label: 'Wake ups',
          value: summary.interruptions.toString(),
        ),
    ];

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: ZFadeSlideIn(
        delay: const Duration(milliseconds: 240),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'The details',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColorsOf(context).textPrimary,
                ),
              ),
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppDimens.spaceSm,
              mainAxisSpacing: AppDimens.spaceSm,
              childAspectRatio: 2.3,
              children: [for (final t in tiles) _StatTileView(tile: t)],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
}

class _StatTileView extends StatelessWidget {
  const _StatTileView({required this.tile});
  final _StatTile tile;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.categorySleep.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppDimens.shapeSm),
            ),
            child: Icon(
              tile.icon,
              size: 16,
              color: AppColors.categorySleep,
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tile.label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tile.value,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
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

// ── Helpers ───────────────────────────────────────────────────────────────────

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
