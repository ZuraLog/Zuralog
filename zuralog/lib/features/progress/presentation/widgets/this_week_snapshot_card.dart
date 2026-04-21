/// "This Week" snapshot card — 3-stat summary row + AI coaching line.
///
/// Bible-compliant: ZFeatureCard surface (Original.PNG @ 7%, animated drift),
/// per-stat mini visualization (ring or sparkline), Sage insight pill.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';
import 'package:zuralog/shared/widgets/charts/z_mini_ring.dart';
import 'package:zuralog/shared/widgets/charts/z_mini_sparkline.dart';
import 'package:zuralog/shared/widgets/indicators/z_category_icon_tile.dart';

class ThisWeekSnapshotCard extends StatelessWidget {
  const ThisWeekSnapshotCard({
    super.key,
    required this.wow,
    required this.streakCount,
    required this.goalsOnTrack,
    required this.totalGoals,
  });

  final WoWSummary wow;
  final int streakCount;
  final int goalsOnTrack;
  final int totalGoals;

  String _coachingLine() {
    if (wow.metrics.isEmpty) {
      if (streakCount > 0) return 'On a $streakCount-day streak — stay consistent!';
      return 'Open the app daily to start building your streak.';
    }
    WoWMetric? best;
    double bestDelta = 0;
    for (final m in wow.metrics) {
      final d = m.deltaPercent ?? 0;
      if (d > bestDelta) {
        bestDelta = d;
        best = m;
      }
    }
    if (best != null && bestDelta >= 5) {
      return '${best.label} is up ${bestDelta.round()}% this week. Keep it going!';
    }
    final declining = wow.metrics.where((m) => (m.deltaPercent ?? 0) < -10).length;
    if (declining >= 2) {
      return 'A lighter week — rest and recovery are part of the journey.';
    }
    return 'Steady week. Every consistent day moves the needle.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final coachingLine = _coachingLine();
    final goalsFraction = totalGoals > 0 ? goalsOnTrack / totalGoals : 0.0;
    // Streak "ring" treats the streak as fractional progress toward a
    // 30-day milestone — caps at 1.0. Purely a visual cue, not a real goal.
    final streakFraction = (streakCount / 30).clamp(0.0, 1.0);
    final firstMetric = wow.metrics.isNotEmpty ? wow.metrics.first : null;

    return ZFeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label — uppercase Label Small per bible.
          Row(
            children: [
              Text(
                'THIS WEEK',
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.progressTextMuted,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (wow.weekLabel.isNotEmpty)
                Text(
                  wow.weekLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.progressTextMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // Three stats with per-stat visuals.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatColumn(
                  vis: ZMiniRing(value: goalsFraction, color: AppColors.success),
                  value: '$goalsOnTrack/${totalGoals == 0 ? '—' : totalGoals}',
                  label: 'Goals on track',
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: _StatColumn(
                  vis: ZMiniRing(value: streakFraction, color: AppColors.streakWarm),
                  value: '${streakCount}d',
                  label: 'Day streak',
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: _StatColumn(
                  vis: firstMetric != null
                      ? SizedBox(
                          width: 60,
                          child: ZMiniSparkline(
                            values: _sparkValues(firstMetric),
                            todayIndex: -1,
                            color: AppColors.categorySleep,
                            height: 28,
                          ),
                        )
                      : const SizedBox(width: 60, height: 36),
                  value: firstMetric != null
                      ? _formatValue(firstMetric.currentValue)
                      : '—',
                  label: firstMetric?.label ?? 'Sync data',
                  delta: firstMetric?.deltaPercent,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceMd),
          Container(height: 1, color: AppColors.dividerDefault),
          const SizedBox(height: AppDimens.spaceMd),

          // Insight pill row.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ZCategoryIconTile(
                color: AppColors.primary, // Sage
                icon: Icons.lightbulb_rounded,
                size: 28,
                iconSize: 14,
                iconColor: AppColors.textOnSage,
                borderRadius: AppDimens.shapeXs, // 8
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Text(
                  coachingLine,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.progressTextPrimary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Returns the most recent 7 sample points for a sparkline. Uses the
  /// per-metric history if `WoWMetric` exposes it; otherwise renders a
  /// minimal two-point line from prior → current value.
  static List<double> _sparkValues(WoWMetric m) {
    // If the data model later exposes a `history` field, swap this for
    // `m.history`. For now, derive a 2-point trend from the delta.
    final delta = m.deltaPercent ?? 0;
    final prior = m.currentValue / (1 + delta / 100);
    return [prior, m.currentValue];
  }

  static String _formatValue(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.vis,
    required this.value,
    required this.label,
    this.delta,
  });

  final Widget vis;
  final String value;
  final String label;
  final double? delta;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 36, child: vis),
        const SizedBox(height: AppDimens.spaceSm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: AppTextStyles.titleMedium.copyWith(
                color: colors.progressTextPrimary,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
            if (delta != null) ...[
              const SizedBox(width: 4),
              Text(
                '${delta! >= 0 ? '↑' : '↓'}${delta!.abs().round()}%',
                style: AppTextStyles.labelSmall.copyWith(
                  color: delta! >= 0 ? AppColors.success : colors.progressTextMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.progressTextMuted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
