/// Zuralog — Workout History Screen.
///
/// Scrollable list of past completed workouts, most-recent-first. Each row
/// shows the date, duration, total volume (in the user's preferred units),
/// and exercise count. Tapping a row pushes the read-only
/// [WorkoutSummaryScreen] with the selected workout.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/workout/domain/completed_workout.dart';
import 'package:zuralog/features/workout/domain/workout_session.dart';
import 'package:zuralog/features/workout/presentation/widgets/workout_stats_row.dart'
    show formatWorkoutDuration;
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workoutHistoryProvider);
    final units = ref.watch(unitsSystemProvider);
    final unit = unitLabel(
      units == UnitsSystem.metric ? 'metric' : 'imperial',
    );

    return ZuralogScaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
        leading: const BackButton(),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => ZErrorState(
          message: "Couldn't load your workout history.",
          onRetry: () => ref.invalidate(workoutHistoryProvider),
        ),
        data: (workouts) {
          if (workouts.isEmpty) return const _EmptyHistory();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceMd,
            ),
            itemCount: workouts.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppDimens.spaceSm),
            itemBuilder: (_, i) => _HistoryRow(
              workout: workouts[i],
              unitLabel: unit,
              onTap: () {
                HapticFeedback.selectionClick();
                context.push(
                  RouteNames.workoutSummaryPath,
                  extra: workouts[i],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: colors.textSecondary,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'No workouts yet',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMedium
                  .copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              'Finished workouts will show up here so you can track your progress over time.',
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.workout,
    required this.unitLabel,
    required this.onTap,
  });

  final CompletedWorkout workout;
  final String unitLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final date = workout.completedAt.toLocal();
    final displayVolume = unitLabel == 'lbs'
        ? kgToLbs(workout.totalVolumeKg)
        : workout.totalVolumeKg;
    final exCount = workout.exercises.length;
    final subtitle =
        '${formatWorkoutDuration(Duration(seconds: workout.durationSeconds))} · '
        '${displayVolume.toStringAsFixed(1)} $unitLabel · '
        '$exCount ${exCount == 1 ? 'exercise' : 'exercises'}';

    return ZuralogCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Row(
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
                  size: 20,
                  color: AppColors.categoryActivity,
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(date),
                      style: AppTextStyles.titleMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceXxs),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
