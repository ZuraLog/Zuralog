/// Full-height detail view behind the Your-Body-Today hero.
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
import 'package:zuralog/features/body/presentation/muscle_state_picker_sheet.dart';
import 'package:zuralog/features/body/presentation/tappable_body_side.dart';
import 'package:zuralog/features/body/providers/body_state_provider.dart';
import 'package:zuralog/features/body/providers/muscle_state_overrides_provider.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

String _todayIso() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class BodyDetailSheet extends ConsumerWidget {
  const BodyDetailSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final async = ref.watch(bodyStateProvider);
    final overrides = ref.watch(muscleStateOverridesProvider);
    final repo = ref.watch(muscleLogRepositoryProvider);
    final todayLogs = repo.getLogsForDate(_todayIso());

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceOverlay,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusCard),
          ),
        ),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Could not load body state',
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          data: (state) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            children: [
              _dragHandle(colors),
              const SizedBox(height: AppDimens.spaceMd),
              _title(context, overrides, ref, repo),
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                'Tap a muscle to log how it feels.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              _dualTappableBodies(context, state),
              if (todayLogs.isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceMd),
                _loggedTodayStrip(context, todayLogs),
              ],
              const SizedBox(height: AppDimens.spaceLg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dragHandle(AppColorsOf colors) => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: colors.textSecondary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _title(
    BuildContext context,
    Map<MuscleGroup, MuscleState> overrides,
    WidgetRef ref,
    MuscleLogRepository repo,
  ) {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Your body',
            style: AppTextStyles.displaySmall.copyWith(
              color: colors.textPrimary,
            ),
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
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _dualTappableBodies(BuildContext context, BodyState state) {
    final zones = _zones(state.muscles);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TappableBodySide(
              isBack: false,
              zones: zones,
              label: 'Front',
              onMuscleTap: (group) => showMuscleStatePicker(context, group),
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: TappableBodySide(
              isBack: true,
              zones: zones,
              label: 'Back',
              onMuscleTap: (group) => showMuscleStatePicker(context, group),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loggedTodayStrip(BuildContext context, List<MuscleLog> logs) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LOGGED TODAY',
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textSecondary,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        ...logs.map(
          (log) => _LogRow(
            log: log,
            onTap: () => showMuscleStatePicker(context, log.muscleGroup),
          ),
        ),
      ],
    );
  }

  Map<MuscleGroup, Color> _zones(Map<MuscleGroup, MuscleState> muscles) {
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

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log, required this.onTap});

  final MuscleLog log;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final dotColor = switch (log.state) {
      MuscleState.fresh => AppColors.categoryActivity,
      MuscleState.worked => AppColors.categoryNutrition,
      MuscleState.sore => AppColors.categoryHeart,
      MuscleState.neutral => colors.textSecondary,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimens.spaceXs,
          horizontal: AppDimens.spaceXs,
        ),
        child: Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              log.muscleGroup.label,
              style:
                  AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
            ),
          ),
          Text(
            log.state.label,
            style: AppTextStyles.bodySmall.copyWith(color: dotColor),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Text(
            log.loggedAtTime,
            style:
                AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(width: AppDimens.spaceXs),
          Icon(Icons.chevron_right_rounded,
              size: 16, color: colors.textSecondary),
        ]),
      ),
    );
  }
}
