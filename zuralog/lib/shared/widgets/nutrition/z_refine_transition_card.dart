/// Zuralog Design System — Refine Transition Card.
///
/// A short transitional card shown between refine rounds in the meal
/// walkthrough. It signals that the AI is preparing one more follow-up
/// question based on the user's previous answer, so the walkthrough
/// feels like it stays on "the same card" and just changes contents.
///
/// Visual layout mirrors the question card in
/// [MealWalkthroughScreen]: a [ZuralogCard] with
/// [ZCardVariant.feature] tinted with [AppColors.categoryNutrition],
/// left-aligned title in [AppTextStyles.titleMedium], optional
/// secondary explainer line in [AppTextStyles.bodyMedium].
///
/// The small [ZCircularProgress] indeterminate spinner (20 px, amber
/// tint) reinforces that another question is on its way. Existing
/// pulsing-dot widgets (`ZPulsingDot`, `LoadingDot`, `ZLoadingIndicator`,
/// `CoachThinkingIndicator`) were not found in the codebase, so we reuse
/// the project's existing [ZCircularProgress] component per the
/// component-library-first rule.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';
import 'package:zuralog/shared/widgets/feedback/z_circular_progress.dart';

/// A between-round transition card for the refine walkthrough.
///
/// Shows a small amber spinner alongside the primary label
/// "Asking one more thing…" and a muted [subLabel] explainer beneath
/// it. The default [subLabel] reads
/// "Your last answer needs a little more detail."
///
/// Example:
/// ```dart
/// const ZRefineTransitionCard()
/// ```
///
/// With a custom sub-label:
/// ```dart
/// ZRefineTransitionCard(
///   subLabel: 'Checking how you cooked that...',
/// )
/// ```
class ZRefineTransitionCard extends StatelessWidget {
  /// Creates a [ZRefineTransitionCard].
  const ZRefineTransitionCard({super.key, this.subLabel});

  /// Secondary, muted line shown beneath the primary label. When null
  /// the default "Your last answer needs a little more detail." is used.
  final String? subLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final sub = subLabel ?? 'Your last answer needs a little more detail.';

    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: AppColors.categoryNutrition,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const ZCircularProgress(
                size: 20,
                strokeWidth: 2.5,
                color: AppColors.categoryNutrition,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Text(
                  'Asking one more thing\u2026',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            sub,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
