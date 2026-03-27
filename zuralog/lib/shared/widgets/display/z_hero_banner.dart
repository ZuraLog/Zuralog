/// Zuralog Design System — Hero Banner Component.
///
/// A full-width image banner with optional pattern overlay and gradient scrim.
/// Used at the top of screens as a branded header or photo hero section.
///
/// Layer order (bottom to top):
///   1. Image (or surface color fallback)
///   2. Pattern overlay (10% opacity, original variant)
///   3. Gradient scrim (transparent → 60% black)
///   4. Child content (text, buttons, etc.)
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// A full-width image banner that layers an image, topographic pattern overlay,
/// gradient scrim, and overlaid content.
///
/// When no [imageProvider] is given the banner acts as a branded header —
/// showing the surface color plus pattern overlay only.
///
/// ## Usage
///
/// ```dart
/// ZHeroBanner(
///   imageProvider: AssetImage('assets/images/hero.jpg'),
///   child: Text('Welcome back'),
/// )
/// ```
class ZHeroBanner extends StatelessWidget {
  const ZHeroBanner({
    super.key,
    this.imageProvider,
    this.height = 220.0,
    this.child,
    this.showPattern = true,
    this.showGradientScrim = true,
    this.borderRadius,
    this.patternVariant = ZPatternVariant.original,
    this.patternOpacity = 0.10,
  });

  /// The image to display as the banner background.
  /// When null, the surface color is used as a fallback.
  final ImageProvider? imageProvider;

  /// Banner height. Defaults to 220 logical pixels.
  final double height;

  /// Content overlaid on the banner, positioned at the bottom with padding.
  final Widget? child;

  /// Whether to show the topographic pattern overlay. Defaults to true.
  final bool showPattern;

  /// Whether to show the gradient scrim that makes overlaid text readable.
  /// Defaults to true.
  final bool showGradientScrim;

  /// Custom border radius. Falls back to [AppDimens.shapeMd] (16px).
  final BorderRadius? borderRadius;

  /// Which pattern variant to use for the overlay.
  final ZPatternVariant patternVariant;

  /// Opacity of the pattern overlay (0.0–1.0). Defaults to 0.10.
  final double patternOpacity;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final effectiveRadius = borderRadius ??
        BorderRadius.circular(AppDimens.shapeMd);

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Image or surface color fallback.
            if (imageProvider != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: imageProvider!,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              ColoredBox(color: colors.surface),

            // Layer 2: Pattern overlay.
            if (showPattern)
              ZPatternOverlay(
                variant: patternVariant,
                opacity: patternOpacity,
              ),

            // Layer 3: Gradient scrim.
            if (showGradientScrim)
              ExcludeSemantics(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.60),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Layer 4: Child content.
            if (child != null)
              Positioned(
                left: AppDimens.spaceMd,
                right: AppDimens.spaceMd,
                bottom: AppDimens.spaceMd,
                child: child!,
              ),
          ],
        ),
      ),
    );
  }
}
