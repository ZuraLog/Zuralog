/// Bottom sheet that asks the user how a muscle feels — Fresh / Worked /
/// Sore — and writes the choice into [muscleStateOverridesProvider].
///
/// Surfaced when the user taps a muscle region on the body in
/// [BodyDetailSheet].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/body/domain/body_state.dart';
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
    // Route through the root navigator so the sheet renders ABOVE the
    // floating bottom-nav pill. Without this, the sheet sits inside the
    // Today tab's navigator and the nav pill clips its lower edge.
    useRootNavigator: true,
    builder: (_) => _MuscleStatePickerSheet(group: group),
  );
}

class _MuscleStatePickerSheet extends ConsumerWidget {
  const _MuscleStatePickerSheet({required this.group});

  final MuscleGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    // Resolve the muscle's current state from the merged bodyStateProvider
    // so the user sees "currently sore" etc. instead of just blank.
    final stateAsync = ref.watch(bodyStateProvider);
    final current = stateAsync.maybeWhen<MuscleState>(
      data: (BodyState s) => s.stateOf(group),
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
            group.label,
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
            onPressed: () {
              ref
                  .read(muscleStateOverridesProvider.notifier)
                  .clearMuscle(group);
              Navigator.of(context).pop();
            },
            child: Text(
              'Clear override',
              style: AppTextStyles.labelLarge.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pick(BuildContext context, WidgetRef ref, MuscleState value) {
    ref.read(muscleStateOverridesProvider.notifier).setMuscle(group, value);
    Navigator.of(context).pop();
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
