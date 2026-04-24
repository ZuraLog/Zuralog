/// Zuralog — Workout Overview Screen.
///
/// Landing page when the user taps the Workout tile on the log grid sheet.
/// Shows the most recent completed workout, a weekly snapshot, an AI summary
/// placeholder, and links to start a new session or browse full history.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/body/data/muscle_log_repository.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/body/presentation/muscle_log_today_strip.dart';
import 'package:zuralog/features/body/presentation/muscle_state_picker_sheet.dart';
import 'package:zuralog/features/body/presentation/tappable_body_side.dart';
import 'package:zuralog/features/body/providers/body_state_provider.dart';
import 'package:zuralog/features/body/providers/muscle_state_overrides_provider.dart';
import 'package:zuralog/features/body/providers/pillar_metrics_providers.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/workout/domain/completed_workout.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;
import 'package:zuralog/features/workout/domain/workout_session.dart';
import 'package:zuralog/features/workout/presentation/widgets/workout_stats_row.dart'
    show formatWorkoutDuration;
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

String _todayIso() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class WorkoutOverviewScreen extends ConsumerWidget {
  const WorkoutOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final historyAsync = ref.watch(workoutHistoryProvider);
    final units = ref.watch(unitsSystemProvider);
    final unit = unitLabel(
      units == UnitsSystem.metric ? 'metric' : 'imperial',
    );

    return Scaffold(
      backgroundColor: colors.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Fitness'),
            pinned: true,
            backgroundColor: colors.surface,
            surfaceTintColor: Colors.transparent,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            sliver: SliverToBoxAdapter(
              child: ZStaggeredList(
                children: [
                  _HeroSection(async: historyAsync, unitLabel: unit),
                  const SizedBox(height: AppDimens.spaceMd),
                  const _StartWorkoutButton(),
                  const SizedBox(height: AppDimens.spaceMd),
                  const _AiSummaryCard(),
                  const SizedBox(height: AppDimens.spaceMd),
                  _WeeklySnapshot(async: historyAsync, unitLabel: unit),
                  const SizedBox(height: AppDimens.spaceMd),
                  const _FitnessBodySection(),
                  const SizedBox(height: AppDimens.spaceMd),
                  const _StepsCard(),
                  const SizedBox(height: AppDimens.spaceSm),
                  const _ViewHistoryRow(),
                  const SizedBox(height: AppDimens.spaceLg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero ───────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.async, required this.unitLabel});

  final AsyncValue<List<CompletedWorkout>> async;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const _HeroSkeleton(),
      error: (_, _) => const _HeroEmpty(
        message: "Couldn't load workouts.",
      ),
      data: (workouts) {
        if (workouts.isEmpty) {
          return const _HeroEmpty(
            message: 'No workouts yet — start your first one!',
          );
        }
        return _HeroCard(workout: workouts.first, unitLabel: unitLabel);
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.workout, required this.unitLabel});

  final CompletedWorkout workout;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final date = workout.completedAt.toLocal();
    final displayVolume = unitLabel == 'lbs'
        ? kgToLbs(workout.totalVolumeKg)
        : workout.totalVolumeKg;

    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: AppColors.categoryActivity,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Last Workout',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.categoryActivity),
                ),
                const Spacer(),
                Text(
                  _shortDate(date),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: 'Duration',
                    value: formatWorkoutDuration(
                      Duration(seconds: workout.durationSeconds),
                    ),
                    valueColor: AppColors.categoryActivity,
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    label: 'Volume',
                    value: '${displayVolume.toStringAsFixed(1)} $unitLabel',
                    valueColor: colors.textPrimary,
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    label: 'Sets',
                    value: '${workout.totalSetsCompleted}',
                    valueColor: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _shortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

class _HeroEmpty extends StatelessWidget {
  const _HeroEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: AppColors.categoryActivity,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          children: [
            const Icon(
              Icons.fitness_center_rounded,
              size: 48,
              color: AppColors.categoryActivity,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: AppColors.categoryActivity,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 14,
              width: 120,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.shapeXs),
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(AppDimens.shapeXs),
                      ),
                    ),
                  ),
                  if (i < 2) const SizedBox(width: AppDimens.spaceSm),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Start Workout ──────────────────────────────────────────────────────────

class _StartWorkoutButton extends StatelessWidget {
  const _StartWorkoutButton();

  @override
  Widget build(BuildContext context) {
    return ZButton(
      label: 'Start Workout',
      onPressed: () {
        HapticFeedback.selectionClick();
        context.push(RouteNames.workoutSessionPath);
      },
    );
  }
}

// ── AI Summary placeholder ─────────────────────────────────────────────────

class _AiSummaryCard extends StatelessWidget {
  const _AiSummaryCard();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: AppColors.categoryActivity,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: AppDimens.iconSm,
                  color: AppColors.categoryActivity,
                ),
                const SizedBox(width: AppDimens.spaceXs),
                Text(
                  'AI Summary',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.categoryActivity),
                ),
                const Spacer(),
                const ZProBadge(showLock: true),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'AI workout insights — coming soon.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: colors.textSecondary, height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Weekly snapshot ─────────────────────────────────────────────────────────

class _WeeklySnapshot extends StatelessWidget {
  const _WeeklySnapshot({required this.async, required this.unitLabel});

  final AsyncValue<List<CompletedWorkout>> async;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final workouts = async.valueOrNull ?? const <CompletedWorkout>[];
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    var count = 0;
    var totalKg = 0.0;
    for (final w in workouts) {
      if (w.completedAt.toLocal().isAfter(cutoff)) {
        count++;
        totalKg += w.totalVolumeKg;
      }
    }
    final displayVolume = unitLabel == 'lbs' ? kgToLbs(totalKg) : totalKg;

    return ZuralogCard(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Week',
              style: AppTextStyles.labelLarge
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: 'Fitness',
                    value: '$count',
                    valueColor: AppColors.categoryActivity,
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    label: 'Volume',
                    value: '${displayVolume.toStringAsFixed(1)} $unitLabel',
                    valueColor: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared stat cell ───────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  const _StatCell({
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
          style: AppTextStyles.labelSmall.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppDimens.spaceXxs),
        Text(
          value,
          textAlign: TextAlign.center,
          style: AppTextStyles.titleMedium
              .copyWith(color: valueColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ── View all history ───────────────────────────────────────────────────────

class _ViewHistoryRow extends StatelessWidget {
  const _ViewHistoryRow();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push(RouteNames.workoutHistoryPath);
      },
      borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceXs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'View All History',
              style: AppTextStyles.labelMedium
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(width: AppDimens.spaceXs),
            Icon(
              Icons.arrow_forward_rounded,
              size: AppDimens.iconSm,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Body map ───────────────────────────────────────────────────────────────────

class _FitnessBodySection extends ConsumerWidget {
  const _FitnessBodySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final bodyAsync = ref.watch(bodyStateProvider);
    final overrides = ref.watch(muscleStateOverridesProvider);
    final repo = ref.watch(muscleLogRepositoryProvider);
    final todayLogs = repo.getLogsForDate(_todayIso());

    return ZuralogCard(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR BODY',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: colors.textSecondary,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap a muscle to log how it feels.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (overrides.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    ref.read(muscleStateOverridesProvider.notifier).clearAll();
                    await repo.clearLogsForDate(_todayIso());
                  },
                  child: Text(
                    'Clear all',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.primary),
                  ),
                ),
            ]),
            const SizedBox(height: AppDimens.spaceMd),
            bodyAsync.when(
              loading: () => const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (state) {
                final zones = _bodyZones(state.muscles);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TappableBodySide(
                          isBack: false,
                          zones: zones,
                          label: 'Front',
                          onMuscleTap: (g) => showMuscleStatePicker(context, g),
                        ),
                      ),
                      const SizedBox(width: AppDimens.spaceSm),
                      Expanded(
                        child: TappableBodySide(
                          isBack: true,
                          zones: zones,
                          label: 'Back',
                          onMuscleTap: (g) => showMuscleStatePicker(context, g),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (todayLogs.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spaceMd),
              MuscleLogTodayStrip(
                logs: todayLogs,
                onLogTap: (log) =>
                    showMuscleStatePicker(context, log.muscleGroup),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Map<MuscleGroup, Color> _bodyZones(
      Map<MuscleGroup, MuscleState> muscles) {
    final map = <MuscleGroup, Color>{};
    muscles.forEach((g, s) {
      final c = switch (s) {
        MuscleState.fresh => AppColors.categoryActivity,
        MuscleState.worked => AppColors.categoryNutrition,
        MuscleState.sore => AppColors.categoryHeart,
        MuscleState.neutral => null,
      };
      if (c != null) map[g] = c;
    });
    return map;
  }
}

// ── Steps card ─────────────────────────────────────────────────────────────────

class _StepsCard extends ConsumerWidget {
  const _StepsCard();

  static const _kGoal = 10000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final metricsAsync = ref.watch(pillarMetricsProvider);

    return metricsAsync.when(
      loading: () => const ZuralogCard(child: SizedBox(height: 120)),
      error: (_, __) => const SizedBox.shrink(),
      data: (metrics) {
        final steps = metrics.stepsToday ?? 0;
        final prev = metrics.stepsPrev;
        final delta = prev != null ? steps - prev : null;
        final progress = (steps / _kGoal).clamp(0.0, 1.0);
        final remaining = (_kGoal - steps).clamp(0, _kGoal);

        return ZuralogCard(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    'STEPS TODAY',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textSecondary,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Goal ${_fmtSteps(_kGoal)}',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: colors.textSecondary),
                  ),
                ]),
                const SizedBox(height: AppDimens.spaceMd),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metrics.stepsToday != null
                                ? _fmtSteps(steps)
                                : '—',
                            style: AppTextStyles.displaySmall.copyWith(
                              color: AppColors.categoryActivity,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          if (delta != null) ...[
                            const SizedBox(height: 6),
                            Row(children: [
                              Icon(
                                delta >= 0
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                size: 13,
                                color: delta >= 0
                                    ? AppColors.categoryActivity
                                    : AppColors.categoryHeart,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${delta >= 0 ? '+' : ''}${_fmtSteps(delta.abs())} vs yesterday',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: colors.textSecondary),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 68,
                      height: 68,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(68, 68),
                            painter: _RingPainter(
                              progress: progress,
                              color: AppColors.categoryActivity,
                            ),
                          ),
                          Text(
                            '${(progress * 100).round()}%',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.categoryActivity,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceMd),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor:
                        AppColors.categoryActivity.withValues(alpha: 0.15),
                    color: AppColors.categoryActivity,
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  steps >= _kGoal
                      ? 'Daily goal reached!'
                      : '${_fmtSteps(remaining)} more to reach your daily goal',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _fmtSteps(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
    }
    return n.toString();
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 10) / 2;
    final paint = Paint()
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    paint.color = color.withValues(alpha: 0.15);
    canvas.drawCircle(center, radius, paint);

    if (progress > 0) {
      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
