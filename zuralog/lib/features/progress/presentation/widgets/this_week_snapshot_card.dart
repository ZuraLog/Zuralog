/// "This Week" snapshot card — 3-stat summary row + AI coaching line.
///
/// Derives all data from real [WoWSummary], [streakCount], and goal counts.
/// Nothing is hardcoded — the coaching line is computed from live deltas.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';

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

  String _buildCoachingLine() {
    if (wow.metrics.isEmpty) {
      if (streakCount > 0) return 'On a $streakCount-day streak — stay consistent!';
      return 'Open the app daily to start building your streak.';
    }

    // Find the metric with the largest positive delta
    WoWMetric? bestMetric;
    double bestDelta = 0;
    for (final m in wow.metrics) {
      final d = m.deltaPercent ?? 0;
      if (d > bestDelta) {
        bestDelta = d;
        bestMetric = m;
      }
    }

    if (bestMetric != null && bestDelta >= 5) {
      return '${bestMetric.label} is up ${bestDelta.round()}% this week. Keep it going!';
    }

    // Check if multiple metrics declined significantly
    final decliningCount =
        wow.metrics.where((m) => (m.deltaPercent ?? 0) < -10).length;
    if (decliningCount >= 2) {
      return 'A lighter week — rest and recovery are part of the journey.';
    }

    return 'Steady week. Every consistent day moves the needle.';
  }

  @override
  Widget build(BuildContext context) {
    final coachingLine = _buildCoachingLine();

    // Build the 3 stats
    final stats = <_SnapshotStat>[
      _SnapshotStat(
        label: 'Goals on track',
        value: '$goalsOnTrack',
        sub: totalGoals > 0 ? 'of $totalGoals' : '—',
        color: AppColors.categoryActivity,
      ),
      _SnapshotStat(
        label: 'Day streak',
        value: '$streakCount',
        sub: 'days',
        color: AppColors.progressStreakWarm,
      ),
      if (wow.metrics.isNotEmpty)
        _SnapshotStat(
          label: wow.metrics.first.label,
          value: _formatValue(wow.metrics.first.currentValue),
          sub: wow.metrics.first.unit,
          color: AppColors.categorySleep,
          delta: wow.metrics.first.deltaPercent,
        )
      else
        _SnapshotStat(
          label: 'Keep going',
          value: '—',
          sub: 'sync data',
          color: AppColors.progressTextMuted,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.progressSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: AppColors.progressBorderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'This Week',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.progressTextPrimary,
                ),
              ),
              const Spacer(),
              if (wow.weekLabel.isNotEmpty)
                Text(
                  wow.weekLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.progressTextMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: AppDimens.spaceSm),
                Expanded(child: _StatColumn(stat: stats[i])),
              ],
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Container(height: 1, color: AppColors.progressBorderDefault),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 13, color: Color(0xFFFF9F0A)),
              const SizedBox(width: AppDimens.spaceXs),
              Expanded(
                child: Text(
                  coachingLine,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.progressTextMuted,
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

  static String _formatValue(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

// ── Private helpers ────────────────────────────────────────────────────────────

class _SnapshotStat {
  const _SnapshotStat({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    this.delta,
  });

  final String label;
  final String value;
  final String sub;
  final Color color;
  final double? delta;
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.stat});
  final _SnapshotStat stat;

  @override
  Widget build(BuildContext context) {
    final deltaStr = stat.delta != null
        ? '${stat.delta! >= 0 ? '+' : ''}${stat.delta!.round()}%'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stat.value,
          style: AppTextStyles.displaySmall.copyWith(
            color: stat.color,
            height: 1.1,
          ),
        ),
        if (deltaStr != null) ...[
          const SizedBox(height: 2),
          Text(
            deltaStr,
            style: AppTextStyles.labelSmall.copyWith(
              color: stat.delta! >= 0
                  ? AppColors.categoryActivity
                  : AppColors.accentDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        Text(
          stat.sub,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.progressTextMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          stat.label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.progressTextSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
