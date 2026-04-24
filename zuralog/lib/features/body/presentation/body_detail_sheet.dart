/// Full-height detail view behind the Your-Body-Now hero.
///
/// v1 scope:
/// - Dual body, taller than the hero version, with clear FRONT / BACK
///   captions so the user can tell them apart at a glance.
/// - Legend explaining Fresh / Worked / Sore.
/// - Tap any muscle region on the body → a picker sheet asks how it
///   feels ("Feeling fresh / Worked out / It's sore"). The override
///   lands in [muscleStateOverridesProvider] and the body re-renders
///   immediately.
/// - "Clear all" chip once any manual override is active.
///
/// Per-muscle history and persisted storage are follow-ups — see
/// `docs/superpowers/specs/2026-04-23-your-body-now-hero-design.md`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/body/presentation/muscle_state_picker_sheet.dart';
import 'package:zuralog/features/body/presentation/tappable_body_side.dart';
import 'package:zuralog/features/body/providers/body_state_provider.dart';
import 'package:zuralog/features/body/providers/muscle_state_overrides_provider.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

class BodyDetailSheet extends ConsumerWidget {
  const BodyDetailSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final async = ref.watch(bodyStateProvider);
    final overrides = ref.watch(muscleStateOverridesProvider);

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
              _title(context, overrides, ref),
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                'Tap a muscle to log how it feels.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              _dualTappableBodies(context, state),
              const SizedBox(height: AppDimens.spaceMd),
              _legend(colors),
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
            onPressed: () => ref
                .read(muscleStateOverridesProvider.notifier)
                .clearAll(),
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

  Widget _legend(AppColorsOf colors) {
    Widget dot(Color c) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        );
    Widget item(Color c, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot(c),
            const SizedBox(width: 6),
            Text(
              text,
              style: AppTextStyles.labelMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        item(AppColors.categoryActivity, 'Fresh'),
        item(AppColors.categoryNutrition, 'Worked'),
        item(AppColors.categoryHeart, 'Sore'),
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
