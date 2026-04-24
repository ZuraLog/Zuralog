/// Generates and renders the hero's plain-language body headline.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

const _legMuscles = {
  MuscleGroup.quads,
  MuscleGroup.hamstrings,
  MuscleGroup.glutes,
  MuscleGroup.calves,
};
const _shoulderMuscles = {MuscleGroup.shoulders};
const _armMuscles = {
  MuscleGroup.biceps,
  MuscleGroup.triceps,
  MuscleGroup.forearms,
};
const _coreMuscles = {MuscleGroup.abs};
const _chestBackMuscles = {MuscleGroup.chest, MuscleGroup.back};

const _groupOrder = [
  ('Legs', _legMuscles),
  ('Shoulders', _shoulderMuscles),
  ('Arms', _armMuscles),
  ('Core', _coreMuscles),
  ('Chest & back', _chestBackMuscles),
];

String headlineFor(BodyState state) {
  if (!state.hasAnySignal) return "Let's meet your body.";

  String? freshGroup;
  String? soreGroup;

  for (final (name, muscles) in _groupOrder) {
    final states = muscles.map(state.stateOf).toSet();
    if (freshGroup == null &&
        states.contains(MuscleState.fresh) &&
        !states.contains(MuscleState.sore)) {
      freshGroup = name;
    }
    if (soreGroup == null && states.contains(MuscleState.sore)) {
      soreGroup = name;
    }
  }

  if (freshGroup != null && soreGroup != null) {
    return '$freshGroup fresh. $soreGroup tight.';
  }
  if (freshGroup != null) return "You're primed.";
  if (soreGroup != null) return 'Take it easy.';
  return "You're steady today.";
}

class BodyNowHeadline extends StatelessWidget {
  const BodyNowHeadline({super.key, required this.state});
  final BodyState state;

  @override
  Widget build(BuildContext context) {
    if (!state.hasAnySignal) return const SizedBox.shrink();
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        headlineFor(state),
        textAlign: TextAlign.center,
        style: AppTextStyles.displaySmall.copyWith(
          color: colors.textPrimary,
          height: 1.22,
          letterSpacing: -0.35,
        ),
      ),
    );
  }
}
