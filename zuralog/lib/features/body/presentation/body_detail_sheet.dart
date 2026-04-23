/// v1 placeholder for the body detail sheet.
///
/// The full detail sheet (history + tap-to-log soreness + per-muscle
/// breakdown) is a separate spec. For now we show the body at a larger
/// size so tapping the hero still feels responsive.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/body/providers/body_state_provider.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;
import 'package:zuralog/shared/widgets/muscle_highlight_diagram.dart';

class BodyDetailSheet extends ConsumerWidget {
  const BodyDetailSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final async = ref.watch(bodyStateProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
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
                'Your body',
                style: AppTextStyles.displaySmall.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              SizedBox(
                height: 420,
                child: Row(children: [
                  Expanded(
                    child: MuscleHighlightDiagram.zones(
                      zones: _zones(state.muscles),
                      onlyFront: true,
                      strokeless: true,
                    ),
                  ),
                  Expanded(
                    child: MuscleHighlightDiagram.zones(
                      zones: _zones(state.muscles),
                      onlyBack: true,
                      strokeless: true,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Text(
                'Tap-to-log soreness, history, and per-muscle detail are '
                'coming in the next update.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
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
