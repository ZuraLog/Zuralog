/// Full-height detail view behind the Your-Body-Today hero.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/body/data/muscle_log_repository.dart';
import 'package:zuralog/features/body/data/muscle_log_sync_service.dart';
import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/body/presentation/muscle_log_today_strip.dart';
import 'package:zuralog/features/body/presentation/muscle_state_picker_sheet.dart';
import 'package:zuralog/features/body/presentation/tappable_body_side.dart';
import 'package:zuralog/features/body/providers/body_state_provider.dart';
import 'package:zuralog/features/body/providers/muscle_state_overrides_provider.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

String _todayIso() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class BodyDetailSheet extends ConsumerStatefulWidget {
  const BodyDetailSheet({super.key});

  @override
  ConsumerState<BodyDetailSheet> createState() => _BodyDetailSheetState();
}

class _BodyDetailSheetState extends ConsumerState<BodyDetailSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(muscleLogSyncServiceProvider).syncPending();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                MuscleLogTodayStrip(
                  logs: todayLogs,
                  onLogTap: (log) => showMuscleStatePicker(context, log.muscleGroup),
                ),
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

