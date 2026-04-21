/// 2x2 stats grid for the Goal Detail page.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/goal_metrics.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/presentation/widgets/goal_visuals.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';

class GoalStatsGrid extends StatelessWidget {
  const GoalStatsGrid({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final visuals = goalVisuals(goal);
    final v = velocityPerDay(goal);
    final projected = projectedEndDate(goal);
    final daysLeft = daysRemaining(goal);
    final streak = logStreak(goal);
    final today = DateTime.now();

    final tiles = <_StatTileData>[
      _StatTileData(
        icon: Icons.bolt_rounded,
        value: '${v >= 0 ? '+' : '−'}${v.abs().toStringAsFixed(2)}',
        unit: '${goal.unit} / day',
        label: 'VELOCITY',
        delta: null,
        deltaTone: _Tone.neutral,
      ),
      _StatTileData(
        icon: Icons.flag_rounded,
        value: projected != null ? _shortDate(projected) : '—',
        unit: projected != null ? _projectedAheadLate(projected, daysLeft, today) : 'no velocity',
        label: 'PROJECTED END',
        delta: null,
        deltaTone: _Tone.neutral,
      ),
      _StatTileData(
        icon: Icons.calendar_today_rounded,
        value: daysLeft != null ? '$daysLeft' : '—',
        unit: daysLeft != null ? '${daysLeft == 1 ? "day" : "days"} remaining' : 'no deadline',
        label: 'TIME LEFT',
        delta: daysLeft != null ? _timeLeftSeverity(daysLeft) : null,
        deltaTone: daysLeft != null ? _timeLeftTone(daysLeft) : _Tone.neutral,
      ),
      _StatTileData(
        icon: Icons.local_fire_department_rounded,
        value: '$streak',
        unit: '${streak == 1 ? "day" : "days"} in a row',
        label: 'LOG STREAK',
        delta: null,
        deltaTone: _Tone.neutral,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppDimens.spaceSm,
      crossAxisSpacing: AppDimens.spaceSm,
      childAspectRatio: 1.4,
      children: [
        for (final t in tiles) _StatTile(data: t, accent: visuals.color),
      ],
    );
  }

  static String _shortDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  static String _projectedAheadLate(DateTime projected, int? deadlineDaysLeft, DateTime today) {
    if (deadlineDaysLeft == null) return 'projected';
    final today0 = DateTime(today.year, today.month, today.day);
    final projDays = projected.difference(today0).inDays;
    final diff = deadlineDaysLeft - projDays;
    if (diff > 0) return '$diff days early';
    if (diff < 0) return '${diff.abs()} days late';
    return 'on pace';
  }

  static String _timeLeftSeverity(int days) {
    if (days < 0) return 'past due';
    if (days <= 3) return 'tight';
    if (days <= 14) return 'moderate';
    return 'comfortable';
  }

  static _Tone _timeLeftTone(int days) {
    if (days < 0) return _Tone.warn;
    if (days <= 3) return _Tone.warn;
    if (days <= 14) return _Tone.neutral;
    return _Tone.good;
  }
}

enum _Tone { good, neutral, warn }

class _StatTileData {
  const _StatTileData({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    required this.delta,
    required this.deltaTone,
  });
  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final String? delta;
  final _Tone deltaTone;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data, required this.accent});
  final _StatTileData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    Color deltaColor() {
      switch (data.deltaTone) {
        case _Tone.good:
          return AppColors.success;
        case _Tone.warn:
          return AppColors.warning;
        case _Tone.neutral:
          return colors.textSecondary;
      }
    }

    return ZFeatureCard(
      borderRadius: AppDimens.shapeMd,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, size: 16, color: accent),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            data.value,
            style: AppTextStyles.displaySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            data.unit,
            style: AppTextStyles.labelSmall.copyWith(color: colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            data.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (data.delta != null) ...[
            const SizedBox(height: 4),
            Text(
              data.delta!,
              style: AppTextStyles.labelSmall.copyWith(
                color: deltaColor(),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
