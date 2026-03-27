/// Zuralog Design System — Onboarding Card Component.
///
/// A full branded hero surface with the richest pattern treatment. Used for
/// onboarding prompts, feature introductions, and first-time user calls to
/// action. Surface (#1E1E20) background, shapeLg (20px) radius, and the
/// original pattern overlay at 0.10 opacity with screen blend.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// A branded hero card for onboarding and feature introduction moments.
///
/// Displays an optional icon in a Sage-tinted circle, a Sage-colored title,
/// secondary body text, and a primary call-to-action button — all layered
/// over the brand topographic pattern.
///
/// ```dart
/// ZOnboardingCard(
///   title: 'Welcome to Zuralog',
///   body: 'Track your health in one place.',
///   ctaLabel: 'Get Started',
///   onCtaTap: () => navigateToSetup(),
///   icon: Icons.favorite,
/// )
/// ```
class ZOnboardingCard extends StatelessWidget {
  /// Creates an onboarding card.
  const ZOnboardingCard({
    super.key,
    required this.title,
    required this.body,
    required this.ctaLabel,
    this.onCtaTap,
    this.icon,
  });

  /// Sage-colored headline displayed prominently.
  final String title;

  /// Secondary description text below the title.
  final String body;

  /// Label for the primary call-to-action button.
  final String ctaLabel;

  /// Called when the CTA button is tapped. Pass null to disable the button.
  final VoidCallback? onCtaTap;

  /// Optional icon shown at the top in a 48px Sage-tinted circle.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimens.shapeLg);

    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: borderRadius,
        ),
        child: Stack(
          children: [
            // ── Pattern overlay (richest treatment) ──────────────────────
            const Positioned.fill(
              child: ZPatternOverlay(
                variant: ZPatternVariant.original,
                opacity: 0.10,
                blendMode: BlendMode.screen,
              ),
            ),

            // ── Content ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMdPlus),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon circle
                  if (icon != null) ...[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        size: 24,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                  ],

                  // Title
                  Text(
                    title,
                    style: AppTextStyles.displaySmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),

                  // Body
                  Text(
                    body,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceMdPlus),

                  // CTA button
                  ZButton(
                    label: ctaLabel,
                    onPressed: onCtaTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
