library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/features/body/data/muscle_log_repository.dart';
import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/coach_message.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/body/providers/body_state_provider.dart';
import 'package:zuralog/features/body/providers/check_in_provider.dart';
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

String _isoDate(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

CoachMessage buildCoachMessage(BodyState state) {
  if (!state.hasAnySignal) {
    return const CoachMessage(
      text:
          'Hey! Connect Apple Health or your watch and I can start showing you how your body is actually doing each day. Sleep, steps, heart, the whole picture.',
      ctaLabel: 'Go to Settings',
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

  if (sore.length >= 4 && fresh.isEmpty) {
    return const CoachMessage(
      text: "Take it easy today. Your body is asking for recovery. A gentle "
          'walk or some mobility work is the right call.',
      ctaLabel: 'Plan recovery',
      ctaRoute: RouteNames.coachPath,
    );
  }

  if (upperSore && lowerFresh) {
    return const CoachMessage(
      text: 'Skip upper body today. Your shoulders are still asking for rest. '
          "Let's hit legs instead.",
      ctaLabel: 'View session',
      ctaRoute: RouteNames.coachPath,
    );
  }

  if (lowerSore && upperFresh) {
    return const CoachMessage(
      text: "Legs are worked. Perfect day for push work. I've lined up an "
          'upper-body session.',
      ctaLabel: 'View session',
      ctaRoute: RouteNames.coachPath,
    );
  }

  if (fresh.length >= 4 && sore.isEmpty) {
    return const CoachMessage(
      text: "You're primed. Strong day ahead. Want me to plan a full session?",
      ctaLabel: 'Plan session',
      ctaRoute: RouteNames.coachPath,
    );
  }

  return const CoachMessage(
    text: "Take it easy today. Let's move when you're ready.",
    ctaLabel: 'Open coach',
    ctaRoute: RouteNames.coachPath,
  );
}

final bodyNowCoachMessageProvider = FutureProvider<CoachMessage?>((ref) async {
  final today = _isoDate(DateTime.now());
  final yesterday = _isoDate(DateTime.now().subtract(const Duration(days: 1)));

  final repo = ref.watch(muscleLogRepositoryProvider);
  final seenDate = ref.watch(checkInProvider);

  if (seenDate != today) {
    final soreLogs = repo
        .getLogsForDate(yesterday)
        .where((l) => l.state == MuscleState.sore)
        .toList();

    if (soreLogs.isNotEmpty) {
      if (soreLogs.length == 1) {
        final group = soreLogs.first.muscleGroup;
        return CoachMessage(
          text:
              'Your ${group.label.toLowerCase()} were sore yesterday. How are they feeling this morning?',
          ctaLabel: 'How do you feel now?',
          ctaRoute: RouteNames.todayPath,
          isCheckIn: true,
          checkInMuscleGroup: group,
        );
      } else {
        return const CoachMessage(
          text:
              'A few things were sore yesterday. Worth a quick check before you plan your day.',
          ctaLabel: 'How do you feel now?',
          ctaRoute: RouteNames.todayPath,
          isCheckIn: true,
        );
      }
    }
  }

  final state = await ref.watch(bodyStateProvider.future);
  return buildCoachMessage(state);
});
