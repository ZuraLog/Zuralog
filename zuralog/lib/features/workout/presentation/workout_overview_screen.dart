/// Zuralog — Workout Overview Screen.
///
/// Landing page when the user taps the Workout tile on the log grid sheet.
/// Shows the most recent completed workout, a weekly snapshot, an AI summary
/// placeholder, and links to start a new session or browse full history.
library;

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
import 'package:zuralog/features/data/domain/data_models.dart' show MetricDataPoint;
import 'package:zuralog/features/workout/domain/steps_summary.dart';
import 'package:zuralog/features/workout/presentation/widgets/steps_detail_sheet.dart';
import 'package:zuralog/features/workout/providers/steps_providers.dart';
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
              error: (_, _) => const SizedBox.shrink(),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(stepsHistoryProvider);
    final smartTargetEnabled = ref.watch(smartTargetEnabledProvider);

    return ZuralogCard(
      onTap: () => showStepsDetailSheet(context),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: summaryAsync.when(
          loading: () => const SizedBox(height: 100),
          error: (_, _) => const SizedBox(height: 100),
          data: (summary) => _StepsCardLoaded(
            summary: summary,
            smartTargetEnabled: smartTargetEnabled,
          ),
        ),
      ),
    );
  }
}

class _StepsCardLoaded extends StatelessWidget {
  const _StepsCardLoaded({
    required this.summary,
    required this.smartTargetEnabled,
  });

  final StepsSummary summary;
  final bool smartTargetEnabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final steps = summary.todayCount;
    final avg = summary.weekAverage;
    final delta = avg > 0 ? steps - avg.round() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(
            'STEPS',
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.chevron_right_rounded,
            size: AppDimens.iconSm,
            color: colors.textSecondary,
          ),
        ]),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          _fmt(steps),
          style: AppTextStyles.displaySmall.copyWith(
            color: AppColors.categoryActivity,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        if (delta != null) ...[
          const SizedBox(height: 4),
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
              '${delta >= 0 ? '+' : ''}${_fmt(delta.abs())} vs 7-day avg',
              style:
                  AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ]),
        ],
        if (smartTargetEnabled && summary.smartTarget > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Sweet spot: ${_fmt(summary.smartTarget)} steps',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.categoryActivity.withValues(alpha: 0.8),
            ),
          ),
        ],
        if (summary.dataPoints.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceMd),
          _MiniBarChart(dataPoints: summary.dataPoints),
        ],
      ],
    );
  }

  static String _fmt(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
    }
    return n.toString();
  }
}

class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart({required this.dataPoints});

  final List<MetricDataPoint> dataPoints;

  @override
  Widget build(BuildContext context) {
    final maxVal = dataPoints
        .map((p) => p.value)
        .fold(0.0, (a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);

    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < dataPoints.length; i++) ...[
            Expanded(
              child: _MiniBar(
                value: dataPoints[i].value,
                maxValue: maxVal,
                isToday: i == dataPoints.length - 1,
              ),
            ),
            if (i < dataPoints.length - 1) const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.value,
    required this.maxValue,
    required this.isToday,
  });

  final double value;
  final double maxValue;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final ratio = (value / maxValue).clamp(0.0, 1.0);
    return FractionallySizedBox(
      heightFactor: ratio < 0.06 ? 0.06 : ratio,
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: isToday
              ? AppColors.categoryActivity
              : AppColors.categoryActivity.withValues(alpha: 0.35),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
      ),
    );
  }
}
