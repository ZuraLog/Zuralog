/// Welcoming zero-data state for the Your-Body-Now hero.
///
/// Shows a compact dual-body silhouette (same figure as the data state, just
/// neutral) plus a short invitation. The coach strip below the hero already
/// renders a Connect CTA, so there is no standalone button here — that would
/// duplicate the call-to-action and bloat the card.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/muscle_highlight_diagram.dart';

// Height of each silhouette in the zero state. Kept intentionally small —
// the figure is a hint of what's coming, not the hero itself when there's
// no data.
const double _figureHeight = 140;

class BodyNowZeroState extends StatelessWidget {
  const BodyNowZeroState({super.key, this.onConnect});

  /// Optional tap handler — kept for API compatibility with existing callers.
  /// The zero-state itself is non-interactive; the connect flow lives in
  /// the coach strip attached to the hero.
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    // Same blended mid-grey the data-state figure uses — keeps the two
    // presentations visually consistent.
    final base = colors.textSecondary.withValues(alpha: 0.35);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: SizedBox(
            height: _figureHeight,
            child: Row(children: [
              Expanded(
                child: MuscleHighlightDiagram.zones(
                  zones: const {},
                  baseColor: base,
                  onlyFront: true,
                  strokeless: true,
                ),
              ),
              Expanded(
                child: MuscleHighlightDiagram.zones(
                  zones: const {},
                  baseColor: base,
                  onlyBack: true,
                  strokeless: true,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Text(
          "Let's meet your body.",
          textAlign: TextAlign.center,
          style: AppTextStyles.displaySmall.copyWith(
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Text(
          'Connect a wearable or log your first workout and I can start '
          'reading how you recover.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ]),
    );
  }
}
