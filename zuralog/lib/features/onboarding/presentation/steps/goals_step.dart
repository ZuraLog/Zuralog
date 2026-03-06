/// Zuralog — Onboarding Step 2: Health Goals.
///
/// Multi-select grid of 8 predefined health goals. The user can select one
/// or more goals (or none — selection is optional). Selected goals are
/// visually highlighted with their dedicated health category color.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/buttons/spring_button.dart';

// ── Goal Model ─────────────────────────────────────────────────────────────────

/// A predefined health goal item shown in the goals grid.
class _Goal {
  const _Goal({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
  });

  final String id;
  final String label;
  final String emoji;

  /// Health category color for the selected state.
  final Color color;
}

/// The 8 predefined health goals, each mapped to a health category color.
const List<_Goal> _goals = [
  _Goal(
    id: 'lose_weight',
    label: 'Lose weight',
    emoji: '⚖️',
    color: AppColors.categoryBody,
  ),
  _Goal(
    id: 'build_muscle',
    label: 'Build muscle',
    emoji: '💪',
    color: AppColors.categoryActivity,
  ),
  _Goal(
    id: 'sleep_better',
    label: 'Sleep better',
    emoji: '😴',
    color: AppColors.categorySleep,
  ),
  _Goal(
    id: 'improve_fitness',
    label: 'Improve fitness',
    emoji: '🏃',
    color: AppColors.categoryActivity,
  ),
  _Goal(
    id: 'reduce_stress',
    label: 'Reduce stress',
    emoji: '🧘',
    color: AppColors.categoryWellness,
  ),
  _Goal(
    id: 'track_nutrition',
    label: 'Track nutrition',
    emoji: '🥗',
    color: AppColors.categoryNutrition,
  ),
  _Goal(
    id: 'heart_health',
    label: 'Heart health',
    emoji: '❤️',
    color: AppColors.categoryHeart,
  ),
  _Goal(
    id: 'general_wellness',
    label: 'General wellness',
    emoji: '✨',
    color: AppColors.primary,
  ),
];

// ── Step Widget ────────────────────────────────────────────────────────────────

/// Step 2 — multi-select health goals grid.
///
/// Calls [onGoalsChanged] whenever the selection changes. The selection is
/// optional — the user may proceed with an empty list.
class GoalsStep extends StatelessWidget {
  /// Creates a [GoalsStep].
  const GoalsStep({
    super.key,
    required this.selectedGoals,
    required this.onGoalsChanged,
  });

  /// Currently selected goal IDs.
  final List<String> selectedGoals;

  /// Callback invoked when the goal selection changes.
  final ValueChanged<List<String>> onGoalsChanged;

  void _toggleGoal(String id) {
    final updated = List<String>.from(selectedGoals);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    onGoalsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Heading ────────────────────────────────────────────────────
          Text(
            'What are your\nhealth goals?',
            style: AppTextStyles.h1.copyWith(
              color: colorScheme.onSurface,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Select all that apply. You can change these later.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Goals grid ────────────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppDimens.spaceMd,
              crossAxisSpacing: AppDimens.spaceMd,
              childAspectRatio: 1.6,
            ),
            itemCount: _goals.length,
            itemBuilder: (context, index) {
              final goal = _goals[index];
              final isSelected = selectedGoals.contains(goal.id);
              return _GoalTile(
                goal: goal,
                isSelected: isSelected,
                onTap: () => _toggleGoal(goal.id),
              );
            },
          ),

          const SizedBox(height: AppDimens.spaceMd),
          if (selectedGoals.isEmpty)
            Text(
              'You can skip this — tap Next to continue.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          const SizedBox(height: AppDimens.spaceLg),
        ],
      ),
    );
  }
}

// ── Goal Tile ─────────────────────────────────────────────────────────────────

/// A single selectable goal tile in the grid.
class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.isSelected,
    required this.onTap,
  });

  final _Goal goal;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = isSelected ? goal.color : AppColors.borderDark;

    return ZuralogSpringButton(
      onTap: onTap,
      scaleTarget: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected
              ? goal.color.withValues(alpha: 0.10)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          border: Border.all(
            color: accentColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(goal.emoji, style: AppTextStyles.body.copyWith(fontSize: 24)),
            Text(
              goal.label,
              style: AppTextStyles.caption.copyWith(
                color: isSelected ? goal.color : colorScheme.onSurface,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
