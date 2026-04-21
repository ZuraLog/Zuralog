library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/workout/domain/exercise.dart';

Color muscleGroupColor(MuscleGroup group) {
  switch (group) {
    case MuscleGroup.chest:
    case MuscleGroup.back:
    case MuscleGroup.shoulders:
    case MuscleGroup.biceps:
    case MuscleGroup.triceps:
    case MuscleGroup.forearms:
    case MuscleGroup.quads:
    case MuscleGroup.hamstrings:
    case MuscleGroup.glutes:
    case MuscleGroup.calves:
    case MuscleGroup.fullBody:
      return AppColors.categoryActivity;
    case MuscleGroup.abs:
      return AppColors.categoryBody;
    case MuscleGroup.cardio:
      return AppColors.categoryHeart;
    case MuscleGroup.other:
      return AppColors.categoryWellness;
  }
}

IconData muscleGroupIcon(MuscleGroup group) {
  switch (group) {
    case MuscleGroup.cardio:
      return Icons.directions_run_rounded;
    case MuscleGroup.abs:
      return Icons.horizontal_rule_rounded;
    case MuscleGroup.fullBody:
      return Icons.accessibility_new_rounded;
    default:
      return Icons.fitness_center_rounded;
  }
}

class ExerciseGridTile extends StatelessWidget {
  const ExerciseGridTile({
    super.key,
    required this.exercise,
    required this.isSelected,
    required this.onTap,
  });

  final Exercise exercise;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final groupColor = muscleGroupColor(exercise.muscleGroup);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${exercise.name}, ${exercise.muscleGroup.label}',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeMd),
            border: Border.all(
              color: isSelected ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: groupColor.withValues(alpha: 0.18)),
                    Center(
                      child: Icon(
                        muscleGroupIcon(exercise.muscleGroup),
                        size: 32,
                        color: groupColor,
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: AppDimens.spaceSm,
                        right: AppDimens.spaceSm,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: colors.textOnSage,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimens.spaceSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exercise.muscleGroup.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: colors.textSecondary,
                      ),
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
