/// Zuralog Design System — Premium Gate Bottom Sheet.
///
/// A branded bottom sheet that explains a premium feature and offers a
/// one-tap path to the paywall. Follows the same show() pattern as
/// [ZBottomSheet] for consistency.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/subscription/domain/subscription_providers.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// A bottom sheet that gates premium features behind a subscription prompt.
///
/// Displays a hero area with the brand pattern, a headline, body copy, and
/// a primary CTA that opens the RevenueCat paywall. A secondary "Not now"
/// button dismisses the sheet.
///
/// Use the static [show] method to present it:
///
/// ```dart
/// ZPremiumGateSheet.show(
///   context,
///   headline: 'Unlock Trends',
///   body: 'See how your health data changes over time.',
///   icon: Icons.trending_up_rounded,
/// );
/// ```
class ZPremiumGateSheet extends ConsumerWidget {
  /// Creates a [ZPremiumGateSheet].
  const ZPremiumGateSheet({
    super.key,
    required this.headline,
    required this.body,
    this.icon,
  });

  /// The main headline shown below the hero area.
  final String headline;

  /// Explanatory body text that tells the user what they get.
  final String body;

  /// An optional icon displayed in the hero area above the headline.
  final IconData? icon;

  /// Presents the premium gate sheet as a modal bottom sheet.
  ///
  /// Returns the value passed to [Navigator.pop] when the sheet closes,
  /// or `null` if dismissed by tapping the scrim.
  static Future<T?> show<T>(
    BuildContext context, {
    required String headline,
    required String body,
    IconData? icon,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.40),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ZPremiumGateSheet(
        headline: headline,
        body: body,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceOverlay,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimens.shapeXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle.
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.40),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Hero area with pattern overlay.
          ClipRRect(
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: Stack(
                children: [
                  // Pattern — Original at 7 % opacity, animated.
                  Positioned.fill(
                    child: ZPatternOverlay(
                      variant: ZPatternVariant.original,
                      opacity: 0.07,
                      animate: true,
                    ),
                  ),

                  // Optional icon centered in the hero.
                  if (icon != null)
                    Center(
                      child: Icon(
                        icon,
                        size: 48,
                        color: colors.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Content area.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceLg,
            ),
            child: Column(
              children: [
                // Headline.
                Text(
                  headline,
                  style: AppTextStyles.displaySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppDimens.spaceSm),

                // Body.
                Text(
                  body,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppDimens.spaceLg),

                // Primary CTA — opens the paywall.
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref
                          .read(subscriptionProvider.notifier)
                          .presentPaywall();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: AppColors.textOnSage,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimens.shapePill),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Upgrade to Pro'),
                  ),
                ),

                const SizedBox(height: AppDimens.spaceSm),

                // Secondary dismiss button.
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Not now',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: AppDimens.spaceMd),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
