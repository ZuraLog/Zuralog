/// Zuralog Design System — Daily Goals Card.
///
/// Shows today's progress towards the user's configured daily goals.
/// When no goals are configured, shows a prompt to set one up.
///
/// Each row is category-aware: the unit string (steps, glasses, ml, L,
/// oz, min, hrs, hours, kcal, g) drives the icon, color, and the way
/// the current/target values are rounded for display. When the backend
/// returns generic labels, the inferred category still gives each row
/// visual identity.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

/// Display data for a single daily goal progress bar.
class DailyGoalDisplay {
  const DailyGoalDisplay({
    required this.label,
    required this.current,
    required this.target,
    required this.unit,
    required this.fraction,
  });

  /// Human-readable goal name (e.g. 'Water', 'Steps'). May be generic
  /// ('Goal') — the card infers the category from [unit] when it is.
  final String label;

  /// Current value as display string (e.g. '4').
  final String current;

  /// Target value as display string (e.g. '8').
  final String target;

  /// Unit label (e.g. 'glasses', 'steps'). Drives icon + color inference.
  final String unit;

  /// Progress 0.0–1.0.
  final double fraction;
}

/// Card showing daily goal progress bars.
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
    return ZuralogCard(
      variant: ZCardVariant.data,
      child: goals.isEmpty
          ? _EmptyGoals(onTap: onSetupTap)
          : _GoalList(goals: goals, onSetupTap: onSetupTap),
    );
  }
}

// ── Category inference ──────────────────────────────────────────────────────

/// Visual identity derived from a goal's unit string (primary) or its
/// target value magnitude (secondary fallback when the unit is missing
/// or generic).
class _GoalCategory {
  const _GoalCategory({
    required this.icon,
    required this.color,
    required this.fallbackLabel,
    required this.roundInteger,
  });

  final IconData icon;
  final Color color;
  final String fallbackLabel;
  final bool roundInteger;

  static const _steps = _GoalCategory(
    icon: Icons.directions_walk_rounded,
    color: AppColors.categoryActivity,
    fallbackLabel: 'Steps',
    roundInteger: true,
  );
  static const _water = _GoalCategory(
    icon: Icons.water_drop_rounded,
    color: AppColors.categoryBody,
    fallbackLabel: 'Water',
    roundInteger: false,
  );
  static const _sleep = _GoalCategory(
    icon: Icons.bedtime_rounded,
    color: AppColors.categorySleep,
    fallbackLabel: 'Sleep',
    roundInteger: true,
  );
  static const _calories = _GoalCategory(
    icon: Icons.local_fire_department_rounded,
    color: AppColors.categoryNutrition,
    fallbackLabel: 'Calories',
    roundInteger: true,
  );
  static const _protein = _GoalCategory(
    icon: Icons.set_meal_rounded,
    color: AppColors.categoryNutrition,
    fallbackLabel: 'Protein',
    roundInteger: true,
  );
  static const _mindfulness = _GoalCategory(
    icon: Icons.self_improvement_rounded,
    color: AppColors.categorySleep,
    fallbackLabel: 'Mindfulness',
    roundInteger: true,
  );
  static const _flag = _GoalCategory(
    icon: Icons.flag_rounded,
    color: AppColors.primary,
    fallbackLabel: 'Goal',
    roundInteger: false,
  );

  /// Primary inference — from the unit string when the backend provides one.
  static _GoalCategory? fromUnit(String unit) {
    final u = unit.toLowerCase().trim();
    if (u == 'steps' || u == 'step') return _steps;
    if (u == 'glasses' || u == 'glass' || u == 'ml' || u == 'l' || u == 'oz' ||
        u == 'cups' || u == 'cup') {
      return _water;
    }
    if (u == 'min' || u == 'mins' || u == 'minutes' || u == 'hrs' ||
        u == 'hours' || u == 'h') {
      return _sleep;
    }
    if (u == 'kcal' || u == 'cal' || u == 'calories') return _calories;
    if (u == 'g' || u == 'grams' || u == 'gram') return _protein;
    return null;
  }

  /// Secondary inference — from the target value's magnitude when the unit
  /// string is absent, generic, or unrecognised. Uses realistic target
  /// ranges for each category so the card still reads correctly when the
  /// backend returns `unit: ""` or `unit: "count"`.
  static _GoalCategory fromTargetValue(double target, int positionHint) {
    if (target >= 5000) return _steps; // 5,000+ → step count
    if (target <= 12) return _water; // 1–12 → glasses of water
    if (target >= 300 && target <= 800) return _sleep; // 300–800 → sleep minutes
    if (target >= 1200 && target <= 4000) return _calories; // 1200–4000 → kcal
    if (target >= 50 && target <= 300) return _protein; // 50–300 g
    // Last-ditch fallback — cycle through mindfulness / flag so we never show
    // four identical flag icons in a row.
    return positionHint.isEven ? _mindfulness : _flag;
  }

  /// Resolve a category from the available goal data. Tries unit first,
  /// then target-value magnitude, then a position-based variety fallback.
  static _GoalCategory resolve({
    required String unit,
    required String targetRaw,
    required int position,
  }) {
    final fromUnitMatch = fromUnit(unit);
    if (fromUnitMatch != null) return fromUnitMatch;
    final parsedTarget =
        double.tryParse(targetRaw.replaceAll(',', ''));
    if (parsedTarget != null) {
      return fromTargetValue(parsedTarget, position);
    }
    return _flag;
  }
}

/// True when the caller-provided label is a placeholder rather than a
/// meaningful goal name.
bool _isGenericLabel(String label) {
  final l = label.trim().toLowerCase();
  return l.isEmpty || l == 'goal' || l == 'goals';
}

/// Rounds a numeric display string to an integer when the category is
/// integer-shaped (steps, kcal, min, grams). Keeps fractional display
/// otherwise. Preserves thousand separators when they are already present.
String _normalizeDisplay(String raw, bool roundInteger) {
  if (!roundInteger) return raw;
  // If it already has no decimal, keep it.
  if (!raw.contains('.')) return raw;
  final parsed = double.tryParse(raw.replaceAll(',', ''));
  if (parsed == null) return raw;
  final rounded = parsed.round();
  if (rounded >= 1000) {
    final s = rounded.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
  return rounded.toString();
}

// ── Private helpers ─────────────────────────────────────────────────────────

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
          _GoalRow(goal: visible[i], position: i),
          if (i < visible.length - 1)
            const SizedBox(height: AppDimens.spaceMd),
        ],
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal, required this.position});

  final DailyGoalDisplay goal;
  final int position;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final category = _GoalCategory.resolve(
      unit: goal.unit,
      targetRaw: goal.target,
      position: position,
    );
    final clamped = goal.fraction.clamp(0.0, 1.0);
    final pct = (clamped * 100).round();
    final isComplete = goal.fraction >= 1.0;
    final isNotStarted = goal.fraction <= 0.0;
    final displayLabel = _isGenericLabel(goal.label)
        ? category.fallbackLabel
        : goal.label;
    final current = _normalizeDisplay(goal.current, category.roundInteger);
    final target = _normalizeDisplay(goal.target, category.roundInteger);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Category icon chip ────────────────────────────────────────────
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: category.color.withValues(
              alpha: isNotStarted ? 0.08 : 0.14,
            ),
            borderRadius: BorderRadius.circular(AppDimens.shapeSm),
          ),
          child: Icon(
            category.icon,
            size: 18,
            color: isNotStarted
                ? category.color.withValues(alpha: 0.55)
                : category.color,
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        // ── Text column + progress bar ────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      displayLabel,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  _StatusPill(
                    percentage: pct,
                    isComplete: isComplete,
                    isNotStarted: isNotStarted,
                    accent: category.color,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _ProgressBar(
                fraction: clamped,
                accent: category.color,
              ),
              const SizedBox(height: 4),
              Text(
                isNotStarted
                    ? 'Not started · $target ${goal.unit}'
                    : '$current of $target ${goal.unit}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction, required this.accent});
  final double fraction;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fillWidth = constraints.maxWidth * fraction;
        return Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              height: 10,
              width: fillWidth,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    accent.withValues(alpha: 0.75),
                    accent,
                  ],
                ),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.percentage,
    required this.isComplete,
    required this.isNotStarted,
    required this.accent,
  });

  final int percentage;
  final bool isComplete;
  final bool isNotStarted;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    if (isComplete) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 12, color: accent),
            const SizedBox(width: 3),
            Text(
              'Done',
              style: AppTextStyles.labelSmall.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    // Almost-there nudge (95–99%): switch to warning amber with a tiny
    // flame icon to signal momentum.
    final almostThere = percentage >= 95 && !isComplete;
    final pillColor =
        almostThere ? AppColors.warning : colors.border;
    final textColor = isNotStarted
        ? colors.textTertiary
        : almostThere
            ? AppColors.warning
            : colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: almostThere ? pillColor.withValues(alpha: 0.18) : pillColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (almostThere) ...[
            Icon(
              Icons.local_fire_department_rounded,
              size: 12,
              color: textColor,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            '$percentage%',
            style: AppTextStyles.labelSmall.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
