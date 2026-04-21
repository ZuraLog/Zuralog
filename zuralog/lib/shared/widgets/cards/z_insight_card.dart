/// Zuralog Design System — AI Insight Card.
///
/// Editorial card for a single AI-generated insight in the Today feed.
/// Each card is category-aware: the left gradient strip, the emblem,
/// the icon, the category · type chip, the stats row, and the compact
/// 7-day sparkline all pick up the matching health-category color so
/// the feed reads as a rich, at-a-glance briefing.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/theme/category_colors.dart';
import 'package:zuralog/features/heart/domain/heart_models.dart';
import 'package:zuralog/features/heart/providers/heart_providers.dart';
import 'package:zuralog/features/nutrition/domain/nutrition_models.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/sleep/domain/sleep_models.dart';
import 'package:zuralog/features/sleep/providers/sleep_providers.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/buttons/spring_button.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

/// A tappable card displaying a single [InsightCard] in the Today feed.
class ZInsightCard extends ConsumerWidget {
  const ZInsightCard({
    super.key,
    required this.insight,
    required this.onTap,
  });

  final InsightCard insight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final categoryColor = categoryColorFromString(
      insight.category,
      fallback: colors.primary,
    );
    final isUnread = !insight.isRead;
    final categoryIcon = _categoryIcon(insight.category, insight.type);
    final snapshot = _snapshotForCategory(insight.category, ref);

    return ZuralogSpringButton(
      onTap: onTap,
      child: ZuralogCard(
        variant: ZCardVariant.feature,
        category: categoryColor,
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Stack(
          children: [
            if (isUnread)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.8, -0.8),
                        radius: 1.1,
                        colors: [
                          categoryColor.withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    margin: const EdgeInsets.only(right: AppDimens.spaceMd),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          categoryColor.withValues(alpha: 0.0),
                          categoryColor.withValues(
                            alpha: isUnread ? 1.0 : 0.5,
                          ),
                          categoryColor.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  _CategoryEmblem(icon: categoryIcon, color: categoryColor),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                insight.title,
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isUnread) ...[
                              const SizedBox(width: AppDimens.spaceSm),
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: categoryColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: categoryColor.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppDimens.spaceXs),
                        Text(
                          insight.summary,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: colors.textSecondary,
                            height: 1.45,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (snapshot.stats.isNotEmpty) ...[
                          const SizedBox(height: AppDimens.spaceSm),
                          _StatsDivider(color: categoryColor),
                          const SizedBox(height: AppDimens.spaceSm),
                          _StatsRow(
                            stats: snapshot.stats,
                            color: categoryColor,
                          ),
                        ],
                        if (snapshot.trend.length >= 3) ...[
                          const SizedBox(height: AppDimens.spaceSm),
                          _MiniSparkline(
                            values: snapshot.trend,
                            todayIndex: snapshot.todayIndex,
                            color: categoryColor,
                            trendLabel: snapshot.trendLabel,
                          ),
                        ],
                        const SizedBox(height: AppDimens.spaceSm),
                        Row(
                          children: [
                            _CategoryTypeChip(
                              category: insight.category,
                              type: insight.type,
                              color: categoryColor,
                            ),
                            const Spacer(),
                            if (insight.createdAt != null)
                              Text(
                                _relativeTime(insight.createdAt!),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: colors.textTertiary,
                                ),
                              ),
                            const SizedBox(width: AppDimens.spaceXs),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: AppDimens.iconSm,
                              color: isUnread
                                  ? categoryColor
                                  : colors.textTertiary,
                            ),
                          ],
                        ),
                      ],
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

  /// Resolves stats + 7-day trend data for the card, sourced from the
  /// matching domain provider.
  _CategorySnapshot _snapshotForCategory(String category, WidgetRef ref) {
    switch (category.toLowerCase()) {
      case 'sleep':
        final s = ref.watch(sleepDaySummaryProvider).valueOrNull ??
            SleepDaySummary.empty;
        final days = ref.watch(sleepTrendProvider('7d')).valueOrNull ??
            const <SleepTrendDay>[];
        if (!s.hasData && days.isEmpty) return _CategorySnapshot.empty;
        return _CategorySnapshot(
          stats: [
            if (s.durationMinutes != null)
              _Stat('Duration', _formatDuration(s.durationMinutes!)),
            if (s.sleepEfficiencyPct != null)
              _Stat('Efficiency', '${s.sleepEfficiencyPct!.round()}%'),
            if (s.avgVs7DayMinutes != null)
              _Stat('vs avg', _formatDelta(s.avgVs7DayMinutes!, 'm')),
          ],
          trend: [
            for (final d in days) (d.durationMinutes ?? 0).toDouble(),
          ],
          todayIndex: days.indexWhere((d) => d.isToday),
          trendLabel: '7-night duration',
        );
      case 'heart':
        final h = ref.watch(heartDaySummaryProvider).valueOrNull ??
            HeartDaySummary.empty;
        final days = ref.watch(heartTrendProvider('7d')).valueOrNull ??
            const <HeartTrendDay>[];
        if (!h.hasData && days.isEmpty) return _CategorySnapshot.empty;
        return _CategorySnapshot(
          stats: [
            if (h.restingHr != null)
              _Stat('Resting', '${h.restingHr!.round()} bpm'),
            if (h.hrvMs != null) _Stat('HRV', '${h.hrvMs!.round()} ms'),
            if (h.restingHrVs7Day != null)
              _Stat(
                'vs avg',
                _formatDelta(h.restingHrVs7Day!.round(), 'bpm'),
              ),
          ],
          trend: [
            for (final d in days) (d.restingHr ?? 0).toDouble(),
          ],
          todayIndex: days.indexWhere((d) => d.isToday),
          trendLabel: '7-day RHR',
        );
      case 'nutrition':
        final n = ref.watch(nutritionDaySummaryProvider).valueOrNull ??
            NutritionDaySummary.empty;
        final days = ref.watch(nutritionTrendProvider('7d')).valueOrNull ??
            const <NutritionTrendDay>[];
        final hasDay = n.totalCalories > 0 ||
            n.totalProteinG > 0 ||
            n.totalCarbsG > 0;
        if (!hasDay && days.isEmpty) return _CategorySnapshot.empty;
        return _CategorySnapshot(
          stats: [
            _Stat('Calories', '${n.totalCalories} kcal'),
            _Stat('Protein', '${n.totalProteinG.round()}g'),
            _Stat('Carbs', '${n.totalCarbsG.round()}g'),
          ],
          trend: [for (final d in days) (d.calories ?? 0).toDouble()],
          todayIndex: days.indexWhere((d) => d.isToday),
          trendLabel: '7-day calories',
        );
      case 'streak':
      case 'engagement':
        final feed = ref.watch(todayFeedProvider).valueOrNull;
        final streak = feed?.streak;
        if (streak == null) return _CategorySnapshot.empty;
        return _CategorySnapshot(
          stats: [
            _Stat('Current', '${streak.currentStreak} days'),
            if (streak.longestStreak != null)
              _Stat('Longest', '${streak.longestStreak} days'),
            _Stat('Status', streak.isFrozen ? 'Frozen' : 'Active'),
          ],
          trend: const [],
          todayIndex: -1,
          trendLabel: '',
        );
      default:
        return _CategorySnapshot.empty;
    }
  }
}

// ── Snapshot payload ─────────────────────────────────────────────────────────

class _CategorySnapshot {
  const _CategorySnapshot({
    required this.stats,
    required this.trend,
    required this.todayIndex,
    required this.trendLabel,
  });

  final List<_Stat> stats;
  final List<double> trend;
  final int todayIndex;
  final String trendLabel;

  static const _CategorySnapshot empty = _CategorySnapshot(
    stats: [],
    trend: [],
    todayIndex: -1,
    trendLabel: '',
  );
}

// ── Category emblem ──────────────────────────────────────────────────────────

class _CategoryEmblem extends StatelessWidget {
  const _CategoryEmblem({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
        border: Border.all(
          color: color.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

// ── Category · type chip ─────────────────────────────────────────────────────

class _CategoryTypeChip extends StatelessWidget {
  const _CategoryTypeChip({
    required this.category,
    required this.type,
    required this.color,
  });

  final String category;
  final InsightType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = '${_categoryLabel(category)} · ${_typeLabel(type)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ── Stats row ────────────────────────────────────────────────────────────────

class _Stat {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.color});
  final List<_Stat> stats;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats[i].value,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  stats[i].label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.textTertiary,
                    fontSize: 10,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (i < stats.length - 1)
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: color.withValues(alpha: 0.18),
            ),
        ],
      ],
    );
  }
}

class _StatsDivider extends StatelessWidget {
  const _StatsDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

// ── Mini sparkline ───────────────────────────────────────────────────────────

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({
    required this.values,
    required this.todayIndex,
    required this.color,
    required this.trendLabel,
  });

  final List<double> values;
  final int todayIndex;
  final Color color;
  final String trendLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: CustomPaint(
            painter: _SparklinePainter(
              values: values,
              todayIndex: todayIndex,
              color: color,
            ),
            size: Size.infinite,
          ),
        ),
        if (trendLabel.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            trendLabel,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textTertiary,
              fontSize: 10,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.todayIndex,
    required this.color,
  });

  final List<double> values;
  final int todayIndex;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final nonZero = values.where((v) => v > 0).toList();
    if (nonZero.isEmpty) return;

    final minV = nonZero.reduce(math.min);
    final maxV = nonZero.reduce(math.max);
    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : maxV - minV;

    final points = <Offset>[];
    final step = size.width / (values.length - 1);
    const topPad = 4.0;
    const bottomPad = 4.0;
    final drawHeight = size.height - topPad - bottomPad;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final normalized = v <= 0 ? 0.0 : (v - minV) / range;
      // Flip Y so higher values sit higher on the canvas.
      final y = topPad + drawHeight * (1 - normalized);
      points.add(Offset(step * i, y));
    }

    // Fill under the line — gentle gradient.
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.28),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    // Line on top.
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Today dot — glowing.
    if (todayIndex >= 0 && todayIndex < points.length) {
      final p = points[todayIndex];
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(p, 6, glowPaint);
      canvas.drawCircle(p, 3.5, Paint()..color = color);
      canvas.drawCircle(
        p,
        3.5,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values ||
      old.todayIndex != todayIndex ||
      old.color != color;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

IconData _categoryIcon(String category, InsightType type) {
  switch (category.toLowerCase()) {
    case 'sleep':
      return Icons.bedtime_rounded;
    case 'heart':
      return Icons.favorite_rounded;
    case 'activity':
      return Icons.directions_walk_rounded;
    case 'nutrition':
      return Icons.local_fire_department_rounded;
    case 'body':
      return Icons.water_drop_rounded;
    case 'vitals':
      return Icons.monitor_heart_rounded;
    case 'wellness':
      return Icons.self_improvement_rounded;
    case 'mobility':
      return Icons.accessibility_new_rounded;
    case 'cycle':
      return Icons.loop_rounded;
    case 'environment':
      return Icons.wb_sunny_rounded;
    case 'streak':
    case 'engagement':
      return Icons.local_fire_department_rounded;
  }
  return _typeIcon(type);
}

IconData _typeIcon(InsightType type) {
  return switch (type) {
    InsightType.anomaly => Icons.warning_amber_rounded,
    InsightType.correlation => Icons.compare_arrows_rounded,
    InsightType.trend => Icons.trending_up_rounded,
    InsightType.recommendation => Icons.lightbulb_outline_rounded,
    InsightType.achievement => Icons.emoji_events_rounded,
    InsightType.unknown => Icons.insights_rounded,
  };
}

String _categoryLabel(String category) {
  if (category.isEmpty) return 'Health';
  final c = category.toLowerCase();
  switch (c) {
    case 'engagement':
      return 'Streak';
    case 'general':
      return 'Health';
  }
  return c[0].toUpperCase() + c.substring(1);
}

String _typeLabel(InsightType type) {
  return switch (type) {
    InsightType.anomaly => 'Anomaly',
    InsightType.correlation => 'Correlation',
    InsightType.trend => 'Trend',
    InsightType.recommendation => 'Tip',
    InsightType.achievement => 'Achievement',
    InsightType.unknown => 'Insight',
  };
}

String _formatDuration(int minutes) {
  if (minutes <= 0) return '—';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

String _formatDelta(int v, String unit) {
  final sign = v > 0 ? '+' : (v < 0 ? '-' : '');
  return '$sign${v.abs()}$unit';
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays}d ago';
}
