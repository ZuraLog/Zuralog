/// Zuralog Design System — Daily Goals Card.
///
/// Shows today's progress towards the user's configured daily goals.
/// When no goals are configured, shows a prompt to set one up.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Display data for a single daily goal progress bar.
class DailyGoalDisplay {
  const DailyGoalDisplay({
    required this.label,
    required this.current,
    required this.target,
    required this.unit,
    required this.fraction,
  });

  /// Human-readable goal name (e.g. 'Water', 'Steps').
  final String label;

  /// Current value as display string (e.g. '4').
  final String current;

  /// Target value as display string (e.g. '8').
  final String target;

  /// Unit label (e.g. 'glasses', 'steps').
  final String unit;

  /// Progress 0.0–1.0.
  final double fraction;
}

/// Card showing daily goal progress bars.
///
/// [goals] — list of goals to display. When empty, shows a setup prompt.
/// [onSetupTap] — called when the setup prompt is tapped. The caller should
///   navigate to the goals settings screen.
class ZDailyGoalsCard extends StatelessWidget {
  const ZDailyGoalsCard({
    super.key,
    required this.goals,
    required this.onSetupTap,
  });

  final List<DailyGoalDisplay> goals;
  final VoidCallback onSetupTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: colors.border),
      ),
      child: goals.isEmpty
          ? _EmptyGoals(onTap: onSetupTap)
          : _GoalList(goals: goals),
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(
            Icons.flag_outlined,
            size: AppDimens.iconSm,
            color: colors.primary,
          ),
          const SizedBox(width: AppDimens.spaceXs),
          Text(
            'Set a daily goal',
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.chevron_right_rounded,
            size: AppDimens.iconSm,
            color: colors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _GoalList extends StatelessWidget {
  const _GoalList({required this.goals});

  final List<DailyGoalDisplay> goals;

  @override
  Widget build(BuildContext context) {
    // Show at most 4 goals without scrolling.
    final visible = goals.take(4).toList();
    return Column(
      children: [
        for (int i = 0; i < visible.length; i++) ...[
          _GoalRow(goal: visible[i]),
          if (i < visible.length - 1)
            const SizedBox(height: AppDimens.spaceSm),
        ],
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal});

  final DailyGoalDisplay goal;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              goal.label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
            Text(
              '${goal.current} / ${goal.target} ${goal.unit}',
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceXs),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: goal.fraction.clamp(0.0, 1.0),
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
