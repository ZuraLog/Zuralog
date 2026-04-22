/// Zuralog — Workout Summary Screen.
///
/// Two modes:
/// - **Preview** (`isPreview: true`): shown right after finishing a workout.
///   The user can edit the date and duration, then tap "Save Workout" to
///   persist the record. Pressing X returns to the active session.
/// - **History view** (`isPreview: false`): read-only view of a past workout.
///   Pressing X or Done just pops.
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
import 'package:zuralog/features/workout/providers/rest_timer_provider.dart';
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  const WorkoutSummaryScreen({
    super.key,
    this.workout,
    this.isPreview = false,
  });

  final CompletedWorkout? workout;
  final bool isPreview;

  @override
  ConsumerState<WorkoutSummaryScreen> createState() =>
      _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends ConsumerState<WorkoutSummaryScreen> {
  /// User-edited date. Null means use the original workout date.
  DateTime? _dateOverride;

  /// User-edited duration in seconds. Null means use the original value.
  int? _durationOverride;

  bool _saving = false;

  DateTime get _effectiveDate =>
      _dateOverride ?? widget.workout?.completedAt.toLocal() ?? DateTime.now();

  int get _effectiveDuration =>
      _durationOverride ?? widget.workout?.durationSeconds ?? 0;

  Future<void> _editDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      final current = _effectiveDate;
      setState(() {
        _dateOverride = DateTime(
          picked.year,
          picked.month,
          picked.day,
          current.hour,
          current.minute,
          current.second,
        );
      });
    }
  }

  Future<void> _editDuration() async {
    final currentSecs = _effectiveDuration;
    final hCtrl =
        TextEditingController(text: '${currentSecs ~/ 3600}');
    final mCtrl = TextEditingController(
        text: ((currentSecs % 3600) ~/ 60).toString().padLeft(2, '0'));

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Duration'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: hCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'h',
                  isDense: true,
                ),
                autofocus: true,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('h'),
            ),
            Expanded(
              child: TextField(
                controller: mCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'min',
                  isDense: true,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('m'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final total = (int.tryParse(hCtrl.text) ?? 0) * 3600 +
                  (int.tryParse(mCtrl.text) ?? 0) * 60;
              Navigator.of(ctx).pop(total);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    hCtrl.dispose();
    mCtrl.dispose();

    if (result != null && mounted) {
      setState(() => _durationOverride = result < 0 ? 0 : result);
    }
  }

  Future<void> _saveWorkout() async {
    final w = widget.workout;
    if (w == null || _saving) return;
    setState(() => _saving = true);

    final toSave = CompletedWorkout(
      id: w.id,
      completedAt: _effectiveDate.toUtc(),
      durationSeconds: _effectiveDuration,
      exercises: w.exercises,
      totalVolumeKg: w.totalVolumeKg,
      totalSetsCompleted: w.totalSetsCompleted,
    );

    final history = ref.read(workoutHistoryRepositoryProvider);
    await ref
        .read(workoutSessionProvider.notifier)
        .saveAndDiscardSession(history, toSave);
    ref.invalidate(workoutHistoryProvider);
    ref.read(restTimerProvider.notifier).skip();

    if (!mounted) return;
    // Pop summary, then pop the session screen.
    context.pop();
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final w = widget.workout;

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
        title: Text(widget.isPreview ? 'Workout Summary' : 'Workout'),
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
                _SummaryHeader(
                  completedAt: _effectiveDate,
                  isEditable: widget.isPreview,
                  onTap: widget.isPreview ? _editDate : null,
                ),
                const SizedBox(height: AppDimens.spaceLg),
                _TotalsRow(
                  durationSeconds: _effectiveDuration,
                  totalVolumeKg: w.totalVolumeKg,
                  totalSets: w.totalSetsCompleted,
                  unitLabel: unit,
                  isDurationEditable: widget.isPreview,
                  onDurationTap: widget.isPreview ? _editDuration : null,
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
          _ActionBar(
            isPreview: widget.isPreview,
            isSaving: _saving,
            onAction: widget.isPreview
                ? _saveWorkout
                : () {
                    HapticFeedback.selectionClick();
                    if (context.canPop()) context.pop();
                  },
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.completedAt,
    required this.isEditable,
    this.onTap,
  });

  final DateTime completedAt;
  final bool isEditable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final dateRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatDate(completedAt),
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
        ),
        if (isEditable) ...[
          const SizedBox(width: 4),
          Icon(Icons.edit_rounded, size: 14, color: colors.textSecondary),
        ],
      ],
    );

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
        isEditable
            ? GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap?.call();
                },
                child: dateRow,
              )
            : dateRow,
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
    required this.isDurationEditable,
    this.onDurationTap,
  });

  final int durationSeconds;
  final double totalVolumeKg;
  final int totalSets;
  final String unitLabel;
  final bool isDurationEditable;
  final VoidCallback? onDurationTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final displayVolume =
        unitLabel == 'lbs' ? kgToLbs(totalVolumeKg) : totalVolumeKg;
    final durationWidget = _TotalCell(
      label: 'Duration',
      value: formatWorkoutDuration(Duration(seconds: durationSeconds)),
      valueColor: AppColors.categoryActivity,
      trailingIcon:
          isDurationEditable ? Icons.edit_rounded : null,
    );

    return Row(
      children: [
        Expanded(
          child: isDurationEditable
              ? GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onDurationTap?.call();
                  },
                  child: durationWidget,
                )
              : durationWidget,
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
    this.trailingIcon,
  });

  final String label;
  final String value;
  final Color valueColor;
  final IconData? trailingIcon;

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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMedium.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 4),
              Icon(trailingIcon, size: 14, color: colors.textSecondary),
            ],
          ],
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
              child: Text('Weight ($unitLabel)', style: headerStyle),
            ),
            Expanded(flex: 2, child: Text('Reps', style: headerStyle)),
            SizedBox(width: 24, child: Text('', style: headerStyle)),
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
                    child: Text('${s.setNumber}', style: cellStyle)),
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

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isPreview,
    required this.isSaving,
    required this.onAction,
  });

  final bool isPreview;
  final bool isSaving;
  final VoidCallback onAction;

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
      child: ZButton(
        label: isPreview ? 'Save Workout' : 'Done',
        onPressed: isSaving ? null : onAction,
      ),
    );
  }
}
