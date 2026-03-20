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
          : _GoalList(goals: goals, onSetupTap: onSetupTap),
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
    return Semantics(
      button: true,
      label: 'Set a daily goal',
      child: GestureDetector(
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
      ),
    );
  }
}

class _GoalList extends StatelessWidget {
  const _GoalList({required this.goals, required this.onSetupTap});

  final List<DailyGoalDisplay> goals;
  final VoidCallback onSetupTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    // Show at most 4 goals without scrolling.
    final visible = goals.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row ─────────────────────────────────────────────────────
        Row(
          children: [
            Icon(
              Icons.flag_rounded,
              size: AppDimens.iconSm,
              color: colors.primary,
            ),
            const SizedBox(width: AppDimens.spaceXs),
            Text(
              "Today's Goals",
              style: AppTextStyles.labelMedium.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Semantics(
              button: true,
              label: 'Manage goals',
              child: GestureDetector(
                onTap: onSetupTap,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'Manage',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceMd),
        // ── Goal rows ───────────────────────────────────────────────────────
        for (int i = 0; i < visible.length; i++) ...[
          _GoalRow(goal: visible[i]),
          if (i < visible.length - 1)
            const SizedBox(height: AppDimens.spaceMd),
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
    final pct = (goal.fraction * 100).round();
    final isComplete = goal.fraction >= 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Goal label
            Expanded(
              child: Text(
                goal.label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            // Percentage badge — green when complete, muted otherwise
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isComplete
                    ? colors.primary.withValues(alpha: 0.18)
                    : colors.border,
                borderRadius: BorderRadius.circular(AppDimens.radiusChip),
              ),
              child: Text(
                isComplete ? 'Done' : '$pct%',
                style: AppTextStyles.labelSmall.copyWith(
                  color: isComplete ? colors.primary : colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceXs),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
          child: LinearProgressIndicator(
            value: goal.fraction.clamp(0.0, 1.0),
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(
              isComplete ? colors.primary : colors.primary.withValues(alpha: 0.75),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        // Current / target values
        Text(
          '${goal.current} of ${goal.target} ${goal.unit}',
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }
}
