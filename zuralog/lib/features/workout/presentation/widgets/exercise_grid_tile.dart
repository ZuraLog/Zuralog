library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/workout/domain/exercise.dart';
import 'package:zuralog/features/workout/providers/exercise_bookmarks_provider.dart';

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

class ExerciseGridTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final groupColor = muscleGroupColor(exercise.muscleGroup);
    final isBookmarked = ref.watch(isBookmarkedProvider(exercise.id));

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
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Tier 1: per-exercise image (if we ship one for this
                    // exercise id); Tier 2: per-muscle-group illustration;
                    // Tier 3: a richly-styled graphic fallback. Each tier
                    // falls through silently via errorBuilder so we never
                    // flash a broken-image glyph.
                    Image.asset(
                      'assets/images/exercises/${exercise.id}.webp',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/exercises/muscle_groups/${exercise.muscleGroup.slug}.webp',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _ExerciseTileFallback(
                          muscleGroup: exercise.muscleGroup,
                          equipment: exercise.equipment,
                          groupColor: groupColor,
                        ),
                      ),
                    ),
                    // Bookmark icon — top-left
                    Positioned(
                      top: AppDimens.spaceSm,
                      left: AppDimens.spaceSm,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(exerciseBookmarksProvider.notifier)
                              .toggle(exercise.id);
                        },
                        child: Icon(
                          isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 20,
                          color: isBookmarked
                              ? colors.primary
                              : colors.textSecondary.withValues(alpha: 0.6),
                        ),
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
                    const SizedBox(height: AppDimens.spaceXxs),
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

/// Richly-styled placeholder shown when neither a per-exercise image nor
/// a muscle-group illustration is available. Designed to feel intentional
/// rather than like a missing asset: diagonal gradient in the muscle-group
/// colour, a soft glow behind a prominent icon, and a small equipment badge.
class _ExerciseTileFallback extends StatelessWidget {
  const _ExerciseTileFallback({
    required this.muscleGroup,
    required this.equipment,
    required this.groupColor,
  });

  final MuscleGroup muscleGroup;
  final Equipment equipment;
  final Color groupColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            groupColor.withValues(alpha: 0.38),
            groupColor.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Soft glow halo behind the icon — adds depth so the fallback
          // reads as a designed surface rather than a flat chip.
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    groupColor.withValues(alpha: 0.35),
                    groupColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Icon hero — larger than before for more visual weight.
          Center(
            child: Icon(
              muscleGroupIcon(muscleGroup),
              size: 40,
              color: groupColor,
            ),
          ),
          // Equipment badge — bottom-right, adds useful info without clutter.
          Positioned(
            right: AppDimens.spaceSm,
            bottom: AppDimens.spaceSm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceSm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(AppDimens.shapePill),
              ),
              child: Text(
                equipment.label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
