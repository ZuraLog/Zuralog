/// Zuralog — Suggestion Card.
///
/// A card for a single [CorrelationSuggestion] that tells Pro users what to
/// start tracking in order to unlock new patterns. Features an animated brand
/// pattern overlay at 7% opacity to signal AI-suggested content.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/trends/domain/trends_models.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// Displays a single AI-generated suggestion for a metric the user could start
/// tracking to discover new health patterns.
class SuggestionCard extends StatelessWidget {
  const SuggestionCard({super.key, required this.suggestion});

  /// The suggestion data to display.
  final CorrelationSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.shapeMd),
      child: Stack(
        children: [
          // Layer 1 — Card body
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: BoxDecoration(
              color: colors.trendsSurface,
              borderRadius: BorderRadius.circular(AppDimens.shapeMd),
              border: Border.all(color: colors.trendsBorderDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  suggestion.description,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.trendsTextSecondary,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                ZButton(
                  label: suggestion.ctaLabel,
                  variant: ZButtonVariant.secondary,
                  size: ZButtonSize.small,
                  isFullWidth: false,
                  onPressed: () => context.push(suggestion.ctaRoute),
                ),
              ],
            ),
          ),
          // Layer 2 — Animated pattern overlay (AI-suggested content)
          Positioned.fill(
            child: IgnorePointer(
              child: ZPatternOverlay(
                variant: ZPatternVariant.original,
                opacity: 0.07,
                animate: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
