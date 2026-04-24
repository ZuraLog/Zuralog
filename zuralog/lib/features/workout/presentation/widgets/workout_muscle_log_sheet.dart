/// Post-workout prompt asking the user how the muscles they trained feel today.
///
/// Shown automatically after a workout is saved when the session included
/// exercises targeting specific muscle groups. Users can tap any muscle to
/// open the [MuscleStatePicker], or dismiss with "Done" to skip.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/body/presentation/muscle_state_picker_sheet.dart';
import 'package:zuralog/features/body/providers/muscle_state_overrides_provider.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;
import 'package:zuralog/features/workout/presentation/widgets/exercise_grid_tile.dart'
    show muscleGroupColor, muscleGroupIcon;

/// Shows the post-workout muscle log sheet as a modal overlay.
///
/// Pass the distinct muscle groups from the completed workout. Groups like
/// [MuscleGroup.other], [MuscleGroup.cardio], and [MuscleGroup.fullBody] should
/// be filtered out before calling this.
Future<void> showWorkoutMuscleLogSheet(
  BuildContext context,
  List<MuscleGroup> muscles,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => _WorkoutMuscleLogSheet(muscles: muscles),
  );
}

class _WorkoutMuscleLogSheet extends ConsumerWidget {
  const _WorkoutMuscleLogSheet({required this.muscles});

  final List<MuscleGroup> muscles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final overrides = ref.watch(muscleStateOverridesProvider);
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceOverlay,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusCard),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.spaceMd + bottomPad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.categoryActivity.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: AppColors.categoryActivity,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nice work!',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'How do your muscles feel?',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // Muscle rows
          for (final group in muscles) ...[
            _MuscleRow(
              group: group,
              loggedState: overrides[group],
              onTap: () => showMuscleStatePicker(context, group),
            ),
            const SizedBox(height: AppDimens.spaceSm),
          ],

          const SizedBox(height: AppDimens.spaceXs),

          // Done button
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.categoryActivity,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              ),
            ),
            child: Text(
              'Done',
              style: AppTextStyles.labelLarge
                  .copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleRow extends StatelessWidget {
  const _MuscleRow({
    required this.group,
    required this.loggedState,
    required this.onTap,
  });

  final MuscleGroup group;
  final MuscleState? loggedState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final groupColor = muscleGroupColor(group);
    final stateColor = loggedState == null
        ? null
        : switch (loggedState!) {
            MuscleState.fresh => AppColors.categoryActivity,
            MuscleState.worked => AppColors.categoryNutrition,
            MuscleState.sore => AppColors.categoryHeart,
            MuscleState.neutral => null,
          };
    final stateLabel = loggedState == null
        ? 'Tap to log'
        : switch (loggedState!) {
            MuscleState.fresh => 'Feeling fresh',
            MuscleState.worked => 'Worked out',
            MuscleState.sore => "It's sore",
            MuscleState.neutral => 'Tap to log',
          };

    return Material(
      color: loggedState != null && stateColor != null
          ? stateColor.withValues(alpha: 0.08)
          : colors.surface,
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Row(
            children: [
              // Muscle icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: groupColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                alignment: Alignment.center,
                child: Icon(
                  muscleGroupIcon(group),
                  color: groupColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),

              // Label
              Expanded(
                child: Text(
                  group.label,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // State badge or prompt
              if (stateColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: stateColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                stateLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: loggedState != null
                      ? (stateColor ?? colors.textSecondary)
                      : colors.textSecondary,
                ),
              ),
              const SizedBox(width: AppDimens.spaceXs),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
