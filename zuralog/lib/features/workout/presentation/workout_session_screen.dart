/// Zuralog — Workout Session Screen.
///
/// The live workout UI. Starts (or resumes) a session on mount, renders
/// the live stats row, the list of exercise cards, and bottom actions.
/// Finish pushes the summary screen; Discard wipes the in-memory + draft
/// session. Exercise Catalogue is reached via the existing `/log/workout/
/// exercises` route and returns a list of [Exercise] which the notifier
/// appends as new `WorkoutExercise` entries.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/workout/domain/exercise.dart';
import 'package:zuralog/features/workout/presentation/widgets/workout_exercise_card.dart';
import 'package:zuralog/features/workout/presentation/widgets/workout_stats_row.dart';
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({super.key});

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState
    extends ConsumerState<WorkoutSessionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(workoutSessionProvider.notifier).startSession();
    });
  }

  Future<void> _openCatalogue() async {
    HapticFeedback.selectionClick();
    final result = await context.push<List<Exercise>>(
      RouteNames.workoutExercisesPath,
    );
    if (result != null && result.isNotEmpty && mounted) {
      ref.read(workoutSessionProvider.notifier).addExercises(result);
    }
  }

  Future<void> _confirmDiscard() async {
    HapticFeedback.selectionClick();
    final confirmed = await ZAlertDialog.show(
      context,
      title: 'Discard this workout?',
      body: "Your exercises and sets won't be saved.",
      confirmLabel: 'Discard',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      ref.read(workoutSessionProvider.notifier).discardSession();
      if (mounted && context.canPop()) context.pop();
    }
  }

  Future<void> _finishWorkout() async {
    HapticFeedback.selectionClick();
    final setsCompleted = ref.read(workoutSetsCompletedProvider);
    if (setsCompleted == 0) {
      final confirmed = await ZAlertDialog.show(
        context,
        title: 'No sets completed',
        body: 'Finish the workout anyway?',
        confirmLabel: 'Finish',
        cancelLabel: 'Cancel',
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    context.push(RouteNames.workoutSummaryPath);
  }

  Future<void> _showMoreMenu() async {
    HapticFeedback.selectionClick();
    await ZBottomSheet.show<void>(
      context,
      title: 'Workout',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('Discard Workout'),
            onTap: () {
              Navigator.of(context).pop();
              _confirmDiscard();
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_rounded),
            title: const Text('Workout Settings'),
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Workout settings — coming soon'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final session = ref.watch(workoutSessionProvider);
    final exercises = session?.exercises ?? const [];

    return ZuralogScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: _confirmDiscard,
        ),
        title: Icon(Icons.timer_outlined, color: colors.textPrimary),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _finishWorkout,
            child: Text(
              'Finish',
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkoutStatsRow(),
          const ZDivider(),
          Expanded(
            child: exercises.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: AppDimens.spaceLg),
                    itemCount: exercises.length,
                    itemBuilder: (_, i) => WorkoutExerciseCard(
                      key: ValueKey(
                        'exercise-${exercises[i].exerciseId}',
                      ),
                      exercise: exercises[i],
                    ),
                  ),
          ),
          _BottomActions(
            onAdd: _openCatalogue,
            onMore: _showMoreMenu,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center_rounded,
                size: 48, color: colors.textSecondary),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'Start your workout',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMedium
                  .copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              'Add your first exercise to begin tracking sets, weights, and reps.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.onAdd, required this.onMore});

  final VoidCallback onAdd;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.spaceSm + bottomPad,
      ),
      child: Row(
        children: [
          Expanded(
            child: ZButton(label: 'Add Exercises', onPressed: onAdd),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          ZIconButton(
            icon: Icons.more_horiz_rounded,
            onPressed: onMore,
            semanticLabel: 'More options',
          ),
        ],
      ),
    );
  }
}
