/// Zuralog — Workout Exercise Card.
///
/// One card per exercise in the active session. Contains:
/// - Header: muscle-group icon bubble, exercise name, 3-dot action menu.
/// - Notes field (auto-saved).
/// - Rest Timer row (switch + duration summary). The duration label taps
///   to a "coming soon" toast — Plan 3 builds the popup.
/// - Set table: Set # | Previous | Weight (tappable unit header) | Reps | Check.
/// - Add-Set text button.
///
/// All mutations delegate to [workoutSessionProvider].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;
import 'package:zuralog/features/workout/domain/workout_session.dart';
import 'package:zuralog/features/workout/presentation/widgets/exercise_grid_tile.dart'
    show muscleGroupColor, muscleGroupIcon;
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class WorkoutExerciseCard extends ConsumerStatefulWidget {
  const WorkoutExerciseCard({super.key, required this.exercise});

  final WorkoutExercise exercise;

  @override
  ConsumerState<WorkoutExerciseCard> createState() =>
      _WorkoutExerciseCardState();
}

class _WorkoutExerciseCardState extends ConsumerState<WorkoutExerciseCard> {
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.exercise.notes);
  }

  @override
  void didUpdateWidget(covariant WorkoutExerciseCard old) {
    super.didUpdateWidget(old);
    // Overwrite only when a notifier-driven change differs from local edits.
    if (old.exercise.notes != widget.exercise.notes &&
        _notesCtrl.text != widget.exercise.notes) {
      _notesCtrl.text = widget.exercise.notes;
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _showMoreMenu() async {
    HapticFeedback.selectionClick();
    await ZBottomSheet.show<void>(
      context,
      title: widget.exercise.exerciseName,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetTile(
            icon: Icons.delete_outline_rounded,
            label: 'Remove Exercise',
            isDestructive: true,
            onTap: () {
              Navigator.of(context).pop();
              ref
                  .read(workoutSessionProvider.notifier)
                  .removeExercise(widget.exercise.exerciseId);
            },
          ),
          _SheetTile(
            icon: Icons.swap_horiz_rounded,
            label: 'Replace Exercise',
            onTap: () {
              Navigator.of(context).pop();
              _comingSoon('Replace exercise');
            },
          ),
          _SheetTile(
            icon: Icons.history_rounded,
            label: 'View History',
            onTap: () {
              Navigator.of(context).pop();
              _comingSoon('Exercise history');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showSetTypeMenu(int setIndex) async {
    HapticFeedback.selectionClick();
    final selected = await ZBottomSheet.show<SetType>(
      context,
      title: 'Set type',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final type in SetType.values)
            _SheetTile(
              icon: _iconForSetType(type),
              label: type.label,
              onTap: () => Navigator.of(context).pop(type),
            ),
        ],
      ),
    );
    if (selected != null) {
      ref
          .read(workoutSessionProvider.notifier)
          .updateSet(widget.exercise.exerciseId, setIndex, type: selected);
    }
  }

  IconData _iconForSetType(SetType type) {
    switch (type) {
      case SetType.warmUp:
        return Icons.whatshot_rounded;
      case SetType.working:
        return Icons.fitness_center_rounded;
      case SetType.dropSet:
        return Icons.trending_down_rounded;
      case SetType.failure:
        return Icons.flag_rounded;
      case SetType.amrap:
        return Icons.all_inclusive_rounded;
    }
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final ex = widget.exercise;
    final muscle = MuscleGroup.fromString(ex.muscleGroup);
    final groupColor = muscleGroupColor(muscle);
    final globalUnits = ref.watch(unitsSystemProvider);
    final unitSystem = effectiveUnitSystem(
      ex,
      globalUnits == UnitsSystem.metric ? 'metric' : 'imperial',
    );
    final unit = unitLabel(unitSystem);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: groupColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                ),
                child: Icon(
                  muscleGroupIcon(muscle),
                  size: 20,
                  color: groupColor,
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Text(
                  ex.exerciseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                color: colors.textSecondary,
                onPressed: _showMoreMenu,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            minLines: 1,
            onChanged: (value) => ref
                .read(workoutSessionProvider.notifier)
                .updateExerciseNotes(ex.exerciseId, value),
            style: AppTextStyles.bodyMedium
                .copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Notes...',
              hintStyle: AppTextStyles.bodyMedium
                  .copyWith(color: colors.textSecondary),
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            children: [
              Icon(Icons.timer_outlined,
                  size: AppDimens.iconMd, color: colors.textSecondary),
              const SizedBox(width: AppDimens.spaceSm),
              Text('Rest Timer',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: colors.textPrimary)),
              const Spacer(),
              if (ex.restTimerEnabled)
                GestureDetector(
                  onTap: () => _comingSoon('Rest timer settings'),
                  child: Text(
                    _formatRestSeconds(ex.restTimerWorkingSeconds),
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: colors.textSecondary),
                  ),
                ),
              const SizedBox(width: AppDimens.spaceSm),
              ZToggle(
                value: ex.restTimerEnabled,
                onChanged: (value) => ref
                    .read(workoutSessionProvider.notifier)
                    .updateRestTimer(ex.exerciseId, value),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          _SetTableHeader(
            unit: unit,
            onUnitTap: () => ref
                .read(workoutSessionProvider.notifier)
                .toggleUnit(ex.exerciseId),
          ),
          for (var i = 0; i < ex.sets.length; i++)
            _SetRow(
              key: ValueKey('set-${ex.exerciseId}-$i'),
              exerciseId: ex.exerciseId,
              setIndex: i,
              set: ex.sets[i],
              onSetNumberTap: () => _showSetTypeMenu(i),
            ),
          const SizedBox(height: AppDimens.spaceSm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                ref
                    .read(workoutSessionProvider.notifier)
                    .addSet(ex.exerciseId);
              },
              icon: Icon(Icons.add_rounded, color: colors.primary),
              label: Text(
                'Add Set',
                style: AppTextStyles.labelLarge.copyWith(color: colors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRestSeconds(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (s == 0) return '${m}m';
  return '${m}m ${s}s';
}

class _SetTableHeader extends StatelessWidget {
  const _SetTableHeader({required this.unit, required this.onUnitTap});

  final String unit;
  final VoidCallback onUnitTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final headerStyle = AppTextStyles.labelSmall.copyWith(
      color: colors.textSecondary,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceXs),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('Set', style: headerStyle)),
          Expanded(flex: 3, child: Text('Previous', style: headerStyle)),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onUnitTap();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(unit.toUpperCase(), style: headerStyle),
                  const SizedBox(width: 2),
                  Icon(Icons.swap_vert_rounded,
                      size: 14, color: colors.textSecondary),
                ],
              ),
            ),
          ),
          Expanded(flex: 2, child: Text('Reps', style: headerStyle)),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _SetRow extends ConsumerStatefulWidget {
  const _SetRow({
    super.key,
    required this.exerciseId,
    required this.setIndex,
    required this.set,
    required this.onSetNumberTap,
  });

  final String exerciseId;
  final int setIndex;
  final WorkoutSet set;
  final VoidCallback onSetNumberTap;

  @override
  ConsumerState<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<_SetRow> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _repsCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
      text: widget.set.weightValue?.toString() ?? '',
    );
    _repsCtrl = TextEditingController(
      text: widget.set.reps?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _SetRow old) {
    super.didUpdateWidget(old);
    final w = widget.set.weightValue?.toString() ?? '';
    if (_weightCtrl.text != w) _weightCtrl.text = w;
    final r = widget.set.reps?.toString() ?? '';
    if (_repsCtrl.text != r) _repsCtrl.text = r;
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final notifier = ref.read(workoutSessionProvider.notifier);
    final setNumberStyle = AppTextStyles.labelLarge.copyWith(
      color: colors.textPrimary,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceXs),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: GestureDetector(
              onTap: widget.onSetNumberTap,
              child: Text(_setCellLabel(widget.set), style: setNumberStyle),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              widget.set.previousRecord ?? '—',
              style: AppTextStyles.bodySmall
                  .copyWith(color: colors.textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) {
                final parsed = double.tryParse(value);
                notifier.updateSet(
                  widget.exerciseId,
                  widget.setIndex,
                  weightValue: parsed,
                );
              },
              decoration: const InputDecoration(
                isDense: true,
                hintText: '-',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _repsCtrl,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final parsed = int.tryParse(value);
                notifier.updateSet(
                  widget.exerciseId,
                  widget.setIndex,
                  reps: parsed,
                );
              },
              decoration: const InputDecoration(
                isDense: true,
                hintText: '-',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: Icon(
                widget.set.isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
                color: widget.set.isCompleted
                    ? colors.primary
                    : colors.textSecondary,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                notifier.updateSet(
                  widget.exerciseId,
                  widget.setIndex,
                  isCompleted: !widget.set.isCompleted,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _setCellLabel(WorkoutSet s) {
  switch (s.type) {
    case SetType.warmUp:
      return 'W';
    case SetType.working:
      return s.setNumber.toString();
    case SetType.dropSet:
      return 'D';
    case SetType.failure:
      return 'F';
    case SetType.amrap:
      return 'A';
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final color = isDestructive ? colors.error : colors.textPrimary;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: AppTextStyles.bodyLarge.copyWith(color: color),
      ),
    );
  }
}
