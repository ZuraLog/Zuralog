/// Bottom sheet that asks the user how a muscle feels — Fresh / Worked /
/// Sore — and writes the choice into [muscleStateOverridesProvider] and
/// [MuscleLogRepository].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/body/data/muscle_log_repository.dart';
import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/muscle_log.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/body/providers/body_state_provider.dart';
import 'package:zuralog/features/body/providers/muscle_state_overrides_provider.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

Future<void> showMuscleStatePicker(
  BuildContext context,
  MuscleGroup group,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => _MuscleStatePickerSheet(group: group),
  );
}

String _todayIso() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String _timeOfDayToString(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _MuscleStatePickerSheet extends ConsumerStatefulWidget {
  const _MuscleStatePickerSheet({required this.group});

  final MuscleGroup group;

  @override
  ConsumerState<_MuscleStatePickerSheet> createState() =>
      _MuscleStatePickerSheetState();
}

class _MuscleStatePickerSheetState
    extends ConsumerState<_MuscleStatePickerSheet> {
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    final today = _todayIso();
    final repo = ref.read(muscleLogRepositoryProvider);
    final existing = repo.getLogForMuscle(today, widget.group);
    if (existing != null) {
      final parts = existing.loggedAtTime.split(':');
      _selectedTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } else {
      _selectedTime = TimeOfDay.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final stateAsync = ref.watch(bodyStateProvider);
    final current = stateAsync.maybeWhen<MuscleState>(
      data: (BodyState s) => s.stateOf(widget.group),
      orElse: () => MuscleState.neutral,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceOverlay,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusCard),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.spaceMd + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            widget.group.label,
            style: AppTextStyles.displaySmall.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'How do they feel today?',
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          _timeRow(context, colors),
          const SizedBox(height: AppDimens.spaceLg),
          _StateRow(
            label: 'Feeling fresh',
            description: 'Primed and ready to train',
            color: AppColors.categoryActivity,
            isCurrent: current == MuscleState.fresh,
            onTap: () => _pick(context, ref, MuscleState.fresh),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _StateRow(
            label: 'Worked out',
            description: 'Loaded recently, mildly fatigued',
            color: AppColors.categoryNutrition,
            isCurrent: current == MuscleState.worked,
            onTap: () => _pick(context, ref, MuscleState.worked),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _StateRow(
            label: "It's sore",
            description: 'Needs rest before training again',
            color: AppColors.categoryHeart,
            isCurrent: current == MuscleState.sore,
            onTap: () => _pick(context, ref, MuscleState.sore),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          TextButton(
            onPressed: () => _clear(context, ref),
            child: Text(
              'Clear',
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeRow(BuildContext context, AppColorsOf colors) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _selectedTime,
        );
        if (picked != null) setState(() => _selectedTime = picked);
      },
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        child: Row(children: [
          Icon(Icons.access_time_rounded, size: 18, color: colors.textSecondary),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              'When did this happen?',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: colors.textSecondary),
            ),
          ),
          Text(
            _selectedTime.format(context),
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: colors.textSecondary),
        ]),
      ),
    );
  }

  Future<void> _pick(
      BuildContext context, WidgetRef ref, MuscleState value) async {
    ref
        .read(muscleStateOverridesProvider.notifier)
        .setMuscle(widget.group, value);
    final log = MuscleLog(
      muscleGroup: widget.group,
      state: value,
      logDate: _todayIso(),
      loggedAtTime: _timeOfDayToString(_selectedTime),
    );
    await ref.read(muscleLogRepositoryProvider).saveLog(log);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    ref
        .read(muscleStateOverridesProvider.notifier)
        .clearMuscle(widget.group);
    await ref
        .read(muscleLogRepositoryProvider)
        .removeLog(_todayIso(), widget.group);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({
    required this.label,
    required this.description,
    required this.color,
    required this.isCurrent,
    required this.onTap,
  });

  final String label;
  final String description;
  final Color color;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Material(
      color: isCurrent ? color.withValues(alpha: 0.12) : colors.surface,
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Row(children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              Icon(Icons.check_rounded, color: color, size: 22),
          ]),
        ),
      ),
    );
  }
}
