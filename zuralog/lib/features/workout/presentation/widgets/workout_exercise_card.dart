/// Zuralog — Workout Exercise Card.
///
/// One card per exercise in the active session. Renders in two modes:
///
/// **Collapsed** (default): shows muscle-group icon bubble, exercise name,
/// a completion badge (e.g. "2 / 3 sets"), and an expand_more chevron.
/// Tapping anywhere on the header expands the card.
///
/// **Expanded**: shows muscle-group icon bubble, exercise name, and a
/// 3-dot (more_vert) action menu in the header. Below the header:
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
import 'package:zuralog/features/workout/presentation/widgets/rest_timer_editor_sheet.dart';
import 'package:zuralog/features/workout/providers/exercise_providers.dart';
import 'package:zuralog/features/workout/providers/rest_timer_provider.dart';
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class WorkoutExerciseCard extends ConsumerStatefulWidget {
  const WorkoutExerciseCard({
    super.key,
    required this.exercise,
    this.isExpanded = true,
    this.onTap,
    this.onAllSetsCompleted,
  });

  final WorkoutExercise exercise;
  final bool isExpanded;
  final VoidCallback? onTap;
  final VoidCallback? onAllSetsCompleted;

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
    if (old.isExpanded && !widget.isExpanded) {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _showHowTo() async {
    HapticFeedback.selectionClick();
    final ex = widget.exercise;
    final catalogueEntry = ref.read(exerciseByIdProvider(ex.exerciseId));
    final muscle = MuscleGroup.fromString(ex.muscleGroup);
    final groupColor = muscleGroupColor(muscle);

    await ZBottomSheet.show<void>(
      context,
      title: ex.exerciseName,
      child: _HowToSheetBody(
        exerciseId: ex.exerciseId,
        exerciseName: ex.exerciseName,
        muscle: muscle,
        equipmentLabel: catalogueEntry?.equipment.label ?? 'Bodyweight',
        instructions: catalogueEntry?.instructions ?? '',
        groupColor: groupColor,
      ),
    );
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

    final completedCount = ex.sets.where((s) => s.isCompleted).length;
    final totalCount = ex.sets.length;
    final allDone = totalCount > 0 && completedCount == totalCount;

    // Exercise thumbnail — vector body diagram with the target muscle
    // highlighted. Tile = 44px, so show only the front view (clipped by
    // the widget) for legibility at this size.
    final exerciseThumbnail = Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: groupColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      ),
      child: MuscleHighlightDiagram(
        muscleGroup: muscle,
        highlightColor: groupColor,
        onlyFront: true,
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          InkWell(
            onTap: widget.isExpanded ? null : widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Row(
                children: [
                  exerciseThumbnail,
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
                  if (widget.isExpanded) ...[
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded),
                      color: colors.textSecondary,
                      tooltip: 'How to do this',
                      onPressed: _showHowTo,
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded),
                      color: colors.textSecondary,
                      onPressed: _showMoreMenu,
                    ),
                  ]
                  else ...[
                    const SizedBox(width: AppDimens.spaceSm),
                    if (allDone)
                      Icon(
                        Icons.check_circle_rounded,
                        size: AppDimens.iconMd,
                        color: colors.primary,
                      )
                    else
                      Text(
                        '$completedCount/$totalCount',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: completedCount > 0
                              ? colors.primary
                              : colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(width: AppDimens.spaceSm),
                    Icon(
                      Icons.expand_more_rounded,
                      size: AppDimens.iconMd,
                      color: colors.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // ── Animated body ────────────────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: widget.isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                0,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppDimens.spaceSm),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    minLines: 1,
                    maxLength: 500,
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
                      counterText: '',
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
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            await ZBottomSheet.show<void>(
                              context,
                              title: 'Rest Timer',
                              child: RestTimerEditorSheet(
                                exerciseId: ex.exerciseId,
                                initialSeconds: ex.restTimerWorkingSeconds,
                              ),
                            );
                          },
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
                    Dismissible(
                      key: ValueKey('dismissible-set-${ex.exerciseId}-$i'),
                      direction: DismissDirection.endToStart,
                      background: _DismissBackground(),
                      confirmDismiss: (_) async {
                        if (ex.sets.length <= 1) return false;
                        if (ex.sets[i].isCompleted) {
                          final confirmed = await ZAlertDialog.show(
                            context,
                            title: 'Remove completed set?',
                            body: 'This set has already been marked as done.',
                            confirmLabel: 'Remove',
                            cancelLabel: 'Cancel',
                            isDestructive: true,
                          );
                          if (!mounted) return false;
                          return confirmed == true;
                        }
                        return true;
                      },
                      onDismissed: (_) {
                        ref
                            .read(workoutSessionProvider.notifier)
                            .removeSet(ex.exerciseId, i);
                      },
                      child: _SetRow(
                        key: ValueKey('set-${ex.exerciseId}-$i'),
                        exerciseId: ex.exerciseId,
                        setIndex: i,
                        set: ex.sets[i],
                        restTimerEnabled: ex.restTimerEnabled,
                        restTimerDurationSeconds:
                            ex.sets[i].type == SetType.warmUp
                                ? ex.restTimerWarmUpSeconds
                                : ex.restTimerWorkingSeconds,
                        onSetNumberTap: () => _showSetTypeMenu(i),
                        // Only fire onCompleted when this is the sole remaining
                        // incomplete set — meaning checking it finishes the exercise.
                        onCompleted: (!ex.sets[i].isCompleted &&
                                ex.sets
                                        .where((s) => !s.isCompleted)
                                        .length ==
                                    1)
                            ? widget.onAllSetsCompleted
                            : null,
                      ),
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
                        style: AppTextStyles.labelLarge
                            .copyWith(color: colors.primary),
                      ),
                    ),
                  ),
                ],
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

/// Red background shown when swiping a set row to the left.
class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppDimens.spaceMd),
      color: colors.error,
      child: Icon(Icons.delete_outline_rounded, color: colors.surface),
    );
  }
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
    required this.restTimerEnabled,
    required this.restTimerDurationSeconds,
    required this.onSetNumberTap,
    this.onCompleted,
  });

  final String exerciseId;
  final int setIndex;
  final WorkoutSet set;
  final bool restTimerEnabled;
  final int restTimerDurationSeconds;
  final VoidCallback onSetNumberTap;
  final VoidCallback? onCompleted;

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
      text: widget.set.weightValue != null
          ? _formatWeight(widget.set.weightValue!)
          : '',
    );
    _repsCtrl = TextEditingController(
      text: widget.set.reps?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _SetRow old) {
    super.didUpdateWidget(old);
    // Compare numerically so typing "100" doesn't get overwritten with "100.0".
    // Only update the field when the stored value genuinely differs (e.g. unit toggle).
    final newW = widget.set.weightValue;
    if (double.tryParse(_weightCtrl.text) != newW) {
      _weightCtrl.text = newW != null ? _formatWeight(newW) : '';
    }
    final newR = widget.set.reps;
    if (int.tryParse(_repsCtrl.text) != newR) {
      _repsCtrl.text = newR?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  /// Formats a weight value: omits the decimal when it's a whole number.
  String _formatWeight(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  /// Hint text for the weight field — the previous session's value, if any.
  String? get _weightHint {
    final prev = widget.set.previousWeightValue;
    if (prev == null) return null;
    return _formatWeight(prev);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final notifier = ref.read(workoutSessionProvider.notifier);
    final setNumberStyle = AppTextStyles.labelLarge.copyWith(
      color: colors.textPrimary,
      fontWeight: FontWeight.w600,
    );

    final hintStyle = AppTextStyles.bodyMedium.copyWith(
      color: colors.textSecondary.withValues(alpha: 0.5),
    );

    final inactiveBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      borderSide: BorderSide(
        color: colors.textSecondary.withValues(alpha: 0.25),
      ),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      borderSide: BorderSide(color: colors.primary),
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
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: _weightHint ?? '-',
                hintStyle: hintStyle,
                border: inactiveBorder,
                enabledBorder: inactiveBorder,
                focusedBorder: focusedBorder,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceXs,
                  vertical: AppDimens.spaceXs,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceXs),
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
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.set.previousReps?.toString() ?? '-',
                hintStyle: hintStyle,
                border: inactiveBorder,
                enabledBorder: inactiveBorder,
                focusedBorder: focusedBorder,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceXs,
                  vertical: AppDimens.spaceXs,
                ),
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
                final completing = !widget.set.isCompleted;
                notifier.updateSet(
                  widget.exerciseId,
                  widget.setIndex,
                  isCompleted: completing,
                );
                if (completing) widget.onCompleted?.call();
                if (completing && widget.restTimerEnabled) {
                  ref
                      .read(restTimerProvider.notifier)
                      .start(widget.restTimerDurationSeconds);
                }
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

/// Bottom sheet body shown when the user taps the ⓘ button on an expanded
/// exercise card. Renders a large photo, muscle / equipment chips, and the
/// step-by-step instructions from the catalogue.
class _HowToSheetBody extends StatelessWidget {
  const _HowToSheetBody({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscle,
    required this.equipmentLabel,
    required this.instructions,
    required this.groupColor,
  });

  final String exerciseId;
  final String exerciseName;
  final MuscleGroup muscle;
  final String equipmentLabel;
  final String instructions;
  final Color groupColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final steps = _splitIntoSteps(instructions);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        0,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hero visual: large vector diagram (front + back) so the user
          // clearly sees which muscles the exercise targets.
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.shapeMd),
              child: Container(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      groupColor.withValues(alpha: 0.22),
                      groupColor.withValues(alpha: 0.06),
                    ],
                  ),
                ),
                child: MuscleHighlightDiagram(
                  muscleGroup: muscle,
                  highlightColor: groupColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // Muscle + equipment chips
          Wrap(
            spacing: AppDimens.spaceSm,
            runSpacing: AppDimens.spaceSm,
            children: [
              _MetaChip(
                icon: Icons.fitness_center_rounded,
                label: muscle.label,
                color: groupColor,
              ),
              _MetaChip(
                icon: Icons.build_rounded,
                label: equipmentLabel,
                color: colors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceLg),

          // Instructions heading + steps
          Text(
            'How to do it',
            style: AppTextStyles.labelMedium.copyWith(
              color: colors.textSecondary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          if (steps.isEmpty)
            Text(
              "We don't have step-by-step instructions for this exercise yet. "
              "The picture above shows the starting position.",
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
                height: 1.5,
              ),
            )
          else
            for (int i = 0; i < steps.length; i++) ...[
              _InstructionStep(number: i + 1, text: steps[i]),
              if (i < steps.length - 1)
                const SizedBox(height: AppDimens.spaceSm),
            ],
        ],
      ),
    );
  }

  /// Splits a paragraph of instructions into numbered steps. The catalogue
  /// stores these as one run-on sentence; we split on terminal punctuation
  /// and filter empty fragments so the list reads like a recipe.
  static List<String> _splitIntoSteps(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    final parts = trimmed
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? [trimmed] : parts;
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.shapePill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
