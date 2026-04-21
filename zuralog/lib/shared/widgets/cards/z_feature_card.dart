/// Zuralog Design System — Feature Card.
///
/// A reusable Surface-colored card that lays the brand topographic
/// pattern (animated drift) on top at the bible-spec'd 7% opacity.
/// Use this for any "feature card" — AI insights, achievements,
/// celebrations, category-bearing surfaces.
///
/// Per `docs/design.md`: surfaces are distinguished by brightness
/// alone — no borders, no shadows. Pattern provides texture.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

class ZFeatureCard extends StatelessWidget {
  const ZFeatureCard({
    super.key,
    required this.child,
    this.variant = ZPatternVariant.original,
    this.opacity = 0.07,
    this.padding = const EdgeInsets.all(AppDimens.spaceMd),
    this.borderRadius = AppDimens.shapeLg,
  });

  final Widget child;

  /// Pattern variant. Defaults to [ZPatternVariant.original]. Pass a
  /// category variant (e.g. [ZPatternVariant.green]) for category-bearing
  /// cards like goal trajectory cards.
  final ZPatternVariant variant;

  /// Pattern opacity. Defaults to 0.07 — the bible's feature-card spec.
  final double opacity;

  /// Inner padding. Defaults to MD (16px).
  final EdgeInsetsGeometry padding;

  /// Corner radius. Defaults to LG (20px).
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          // Surface fill — brightness alone, no border, no shadow.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: radius,
              ),
            ),
          ),
          // Animated pattern overlay.
          Positioned.fill(
            child: ZPatternOverlay(
              variant: variant,
              opacity: opacity,
              animate: true,
            ),
          ),
          // Content.
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
