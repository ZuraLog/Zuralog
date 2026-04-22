library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/workout/preferences/workout_preferences.dart';
import 'package:zuralog/features/workout/providers/workout_session_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

enum _RestScope { thisExercise, allExercises, setDefault }

class RestTimerEditorSheet extends ConsumerStatefulWidget {
  const RestTimerEditorSheet({
    super.key,
    required this.exerciseId,
    required this.initialSeconds,
  });

  final String exerciseId;
  final int initialSeconds;

  @override
  ConsumerState<RestTimerEditorSheet> createState() =>
      _RestTimerEditorSheetState();
}

class _RestTimerEditorSheetState extends ConsumerState<RestTimerEditorSheet> {
  static const int _min = 15;
  static const int _max = 600;
  static const int _step = 15;

  late int _seconds;
  _RestScope _scope = _RestScope.thisExercise;

  @override
  void initState() {
    super.initState();
    // Round initial value to the nearest step.
    _seconds = (((widget.initialSeconds / _step).round() * _step)
            .clamp(_min, _max))
        .toInt();
  }

  String _fmt(int s) {
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final rem = s % 60;
    return rem == 0 ? '${m}m' : '${m}m ${rem}s';
  }

  void _apply() {
    HapticFeedback.selectionClick();
    final notifier = ref.read(workoutSessionProvider.notifier);
    switch (_scope) {
      case _RestScope.thisExercise:
        notifier.updateExerciseRestDuration(
          widget.exerciseId,
          workingSeconds: _seconds,
        );
      case _RestScope.allExercises:
        notifier.updateAllExercisesRestDuration(workingSeconds: _seconds);
      case _RestScope.setDefault:
        notifier.updateAllExercisesRestDuration(workingSeconds: _seconds);
        ref.read(workoutPreferencesProvider).setDefaultRestSeconds(_seconds);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppDimens.spaceSm),
        // ── Duration stepper ──────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.remove_rounded, color: colors.textPrimary),
              onPressed: _seconds > _min
                  ? () => setState(
                      () => _seconds = (_seconds - _step).clamp(_min, _max))
                  : null,
            ),
            const SizedBox(width: AppDimens.spaceMd),
            SizedBox(
              width: 80,
              child: Text(
                _fmt(_seconds),
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            IconButton(
              icon: Icon(Icons.add_rounded, color: colors.textPrimary),
              onPressed: _seconds < _max
                  ? () => setState(
                      () => _seconds = (_seconds + _step).clamp(_min, _max))
                  : null,
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceSm),
        const ZDivider(),
        // ── Scope radio options ───────────────────────────────────────────
        for (final scope in _RestScope.values)
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _scope = scope);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceXs,
              ),
              child: Row(
                children: [
                  Radio<_RestScope>(
                    value: scope,
                    groupValue: _scope,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      if (v != null) setState(() => _scope = v);
                    },
                    activeColor: colors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: AppDimens.spaceXs),
                  Expanded(
                    child: Text(
                      switch (scope) {
                        _RestScope.thisExercise => 'This exercise only',
                        _RestScope.allExercises => 'All exercises in workout',
                        _RestScope.setDefault =>
                          'Set as default for future workouts',
                      },
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppDimens.spaceMd),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: ZButton(label: 'Apply', onPressed: _apply),
        ),
        const SizedBox(height: AppDimens.spaceSm),
      ],
    );
  }
}
