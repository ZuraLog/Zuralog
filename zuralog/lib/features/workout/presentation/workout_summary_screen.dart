/// Zuralog — Workout Summary Screen.
///
/// Displays a finished workout: header, totals (duration / volume / sets),
/// per-exercise set tables, and a Done button that pops back to the caller.
/// Renders an error state when the [workout] extra is missing (e.g. a deep
/// link lands here without navigating through the finish flow).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/workout/domain/completed_workout.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;
import 'package:zuralog/features/workout/domain/workout_session.dart';
import 'package:zuralog/features/workout/presentation/widgets/exercise_grid_tile.dart'
    show muscleGroupColor, muscleGroupIcon;
import 'package:zuralog/features/workout/presentation/widgets/workout_stats_row.dart'
    show formatWorkoutDuration;
import 'package:zuralog/shared/widgets/widgets.dart';

class WorkoutSummaryScreen extends ConsumerWidget {
  const WorkoutSummaryScreen({super.key, this.workout});

  final CompletedWorkout? workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final w = workout;

    if (w == null) {
      return ZuralogScaffold(
        appBar: AppBar(
          title: const Text('Workout Summary'),
          leading: const BackButton(),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Text(
              'This workout summary is not available.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: colors.textSecondary),
            ),
          ),
        ),
      );
    }

    final units = ref.watch(unitsSystemProvider);
    final unit = unitLabel(
      units == UnitsSystem.metric ? 'metric' : 'imperial',
    );

    return ZuralogScaffold(
      appBar: AppBar(
        title: const Text('Workout Summary'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            HapticFeedback.selectionClick();
            if (context.canPop()) context.pop();
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceLg,
              ),
              children: [
                _SummaryHeader(completedAt: w.completedAt.toLocal()),
                const SizedBox(height: AppDimens.spaceLg),
                _TotalsRow(
                  durationSeconds: w.durationSeconds,
                  totalVolumeKg: w.totalVolumeKg,
                  totalSets: w.totalSetsCompleted,
                  unitLabel: unit,
                ),
                const SizedBox(height: AppDimens.spaceLg),
                const ZDivider(),
                const SizedBox(height: AppDimens.spaceMd),
                for (final ex in w.exercises) ...[
                  _ExerciseBlock(exercise: ex, unitLabel: unit),
                  const SizedBox(height: AppDimens.spaceMd),
                ],
              ],
            ),
          ),
          _DoneBar(onDone: () {
            HapticFeedback.selectionClick();
            if (context.canPop()) context.pop();
          }),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.completedAt});

  final DateTime completedAt;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 56,
          color: AppColors.categoryActivity,
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          'Workout Complete',
          textAlign: TextAlign.center,
          style: AppTextStyles.titleLarge
              .copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDimens.spaceXxs),
        Text(
          _formatDate(completedAt),
          textAlign: TextAlign.center,
          style:
              AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = d.hour == 0
        ? 12
        : (d.hour > 12 ? d.hour - 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final minute = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, ${d.year} · $h:$minute $ampm';
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.durationSeconds,
    required this.totalVolumeKg,
    required this.totalSets,
    required this.unitLabel,
  });

  final int durationSeconds;
  final double totalVolumeKg;
  final int totalSets;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final displayVolume = unitLabel == 'lbs'
        ? kgToLbs(totalVolumeKg)
        : totalVolumeKg;
    return Row(
      children: [
        Expanded(
          child: _TotalCell(
            label: 'Duration',
            value: formatWorkoutDuration(
              Duration(seconds: durationSeconds),
            ),
            valueColor: AppColors.categoryActivity,
          ),
        ),
        Expanded(
          child: _TotalCell(
            label: 'Volume',
            value: '${displayVolume.toStringAsFixed(1)} $unitLabel',
            valueColor: colors.textPrimary,
          ),
        ),
        Expanded(
          child: _TotalCell(
            label: 'Sets',
            value: '$totalSets',
            valueColor: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TotalCell extends StatelessWidget {
  const _TotalCell({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall
              .copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppDimens.spaceXxs),
        Text(
          value,
          textAlign: TextAlign.center,
          style: AppTextStyles.titleMedium.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({required this.exercise, required this.unitLabel});

  final CompletedExercise exercise;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final group = MuscleGroup.fromString(exercise.muscleGroup);
    final groupColor = muscleGroupColor(group);
    final setLabelUnit = exercise.unitOverride == 'imperial'
        ? 'lbs'
        : (exercise.unitOverride == 'metric' ? 'kg' : unitLabel);

    return ZuralogCard(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
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
                  size: 20,
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.exerciseName,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      group.label,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          _SetsTable(
            sets: exercise.sets.where((s) => s.isCompleted).toList(),
            unitLabel: setLabelUnit,
          ),
        ],
      ),
    );
  }
}

class _SetsTable extends StatelessWidget {
  const _SetsTable({required this.sets, required this.unitLabel});

  final List<WorkoutSet> sets;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final headerStyle =
        AppTextStyles.labelSmall.copyWith(color: colors.textSecondary);
    final cellStyle =
        AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary);
    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 2, child: Text('Set', style: headerStyle)),
            Expanded(
              flex: 3,
              child: Text(
                'Weight ($unitLabel)',
                style: headerStyle,
              ),
            ),
            Expanded(flex: 2, child: Text('Reps', style: headerStyle)),
            SizedBox(
              width: 24,
              child: Text('', style: headerStyle),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceXs),
        for (final s in sets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceXxs),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('${s.setNumber}', style: cellStyle),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    s.weightValue == null
                        ? '—'
                        : s.weightValue!.toStringAsFixed(1),
                    style: cellStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    s.reps == null ? '—' : '${s.reps}',
                    style: cellStyle,
                  ),
                ),
                SizedBox(
                  width: 24,
                  child: Icon(
                    s.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: s.isCompleted
                        ? AppColors.categoryActivity
                        : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DoneBar extends StatelessWidget {
  const _DoneBar({required this.onDone});

  final VoidCallback onDone;

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
      child: ZButton(label: 'Done', onPressed: onDone),
    );
  }
}
