/// v1 template engine for the hero coach strip.
///
/// A real LLM-backed version is a follow-up. For v1 we pick the best-fitting
/// template from a small set based on the body state. Keep the message
/// human, in plain language, <= 2 sentences.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/coach_message.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/body/providers/body_state_provider.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

const _upperBody = {
  MuscleGroup.chest,
  MuscleGroup.back,
  MuscleGroup.shoulders,
  MuscleGroup.biceps,
  MuscleGroup.triceps,
};
const _lowerBody = {
  MuscleGroup.quads,
  MuscleGroup.hamstrings,
  MuscleGroup.glutes,
  MuscleGroup.calves,
};

CoachMessage buildCoachMessage(BodyState state) {
  if (!state.hasAnySignal) {
    return const CoachMessage(
      text: "Let's meet your body. Connect a wearable or log a workout and "
          "I'll start reading where you are today.",
      ctaLabel: 'Connect',
      ctaRoute: RouteNames.settingsIntegrationsPath,
    );
  }

  final sore = state.muscles.entries
      .where((e) => e.value == MuscleState.sore)
      .map((e) => e.key)
      .toSet();
  final fresh = state.muscles.entries
      .where((e) => e.value == MuscleState.fresh)
      .map((e) => e.key)
      .toSet();

  final upperSore = sore.any(_upperBody.contains);
  final lowerSore = sore.any(_lowerBody.contains);
  final upperFresh = fresh.any(_upperBody.contains);
  final lowerFresh = fresh.any(_lowerBody.contains);

  // Rest-day template — most of the body is sore.
  if (sore.length >= 4 && fresh.isEmpty) {
    return const CoachMessage(
      text: "Take it easy today — your body's asking for recovery. A gentle "
          'walk or some mobility work is the right call.',
      ctaLabel: 'Plan recovery',
      ctaRoute: RouteNames.coachPath,
    );
  }

  // Lower-body focus — upper sore, legs fresh.
  if (upperSore && lowerFresh) {
    return const CoachMessage(
      text: 'Skip upper body today — your shoulders are still asking for rest. '
          "Let's hit legs. I've queued a 30-min session for you.",
      ctaLabel: 'View session',
      ctaRoute: RouteNames.coachPath,
    );
  }

  // Upper-body focus — legs sore, arms fresh.
  if (lowerSore && upperFresh) {
    return const CoachMessage(
      text: "Legs are worked — perfect day for push work. I've lined up an "
          'upper-body session.',
      ctaLabel: 'View session',
      ctaRoute: RouteNames.coachPath,
    );
  }

  // Everything fresh — go hard.
  if (fresh.length >= 4 && sore.isEmpty) {
    return const CoachMessage(
      text: "You're primed — strong day ahead. Want me to plan a full session?",
      ctaLabel: 'Plan session',
      ctaRoute: RouteNames.coachPath,
    );
  }

  // Fallback — quiet, non-committal.
  return const CoachMessage(
    text: "Take it easy today. Let's move when you're ready.",
    ctaLabel: 'Open coach',
    ctaRoute: RouteNames.coachPath,
  );
}

final bodyNowCoachMessageProvider = FutureProvider<CoachMessage>((ref) async {
  final state = await ref.watch(bodyStateProvider.future);
  return buildCoachMessage(state);
});
