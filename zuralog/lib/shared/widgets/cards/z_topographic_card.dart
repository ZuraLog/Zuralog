/// Zuralog Design System — Topographic Card Component.
///
/// A card that applies the brand topographic contour-line pattern using
/// [ZPatternOverlay]. Surface background, no accent strip, no border.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// A card widget with a brand topographic pattern as a surface overlay.
///
/// Uses [ZPatternOverlay] with [BlendMode.screen] at 0.07 opacity for a
/// subtle texture on the dark Surface background.
///
/// Example usage:
/// ```dart
/// ZTopographicCard(
///   child: Text('Trends hero content'),
/// )
/// ```
@Deprecated('Use ZuralogCard(variant: ZCardVariant.feature) instead.')
class ZTopographicCard extends StatelessWidget {
  /// The content widget rendered inside the card.
  final Widget child;

  /// The color of the accent — kept for constructor compatibility but no
  /// longer rendered as a strip.
  final Color? accentColor;

  /// Inner padding around [child].
  ///
  /// Defaults to [AppDimens.spaceMdPlus] (20px) on all sides.
  final EdgeInsetsGeometry? padding;

  /// Creates a [ZTopographicCard].
  const ZTopographicCard({
    super.key,
    required this.child,
    this.accentColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding =
        padding ?? const EdgeInsets.all(AppDimens.spaceMdPlus);
    final borderRadius = BorderRadius.circular(AppDimens.shapeLg);

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: borderRadius,
        ),
        child: Stack(
          children: [
            // Pattern overlay
            Positioned.fill(
              child: ZPatternOverlay(
                variant: ZPatternVariant.original,
                opacity: 0.07,
                blendMode: BlendMode.screen,
              ),
            ),
            // Content
            Padding(padding: effectivePadding, child: child),
          ],
        ),
      ),
    );
  }
}
