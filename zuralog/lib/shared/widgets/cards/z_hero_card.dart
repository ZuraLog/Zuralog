/// Zuralog Design System — Hero Card.
///
/// The richest pattern treatment for a card surface: Original.PNG at
/// 10% opacity with animated drift. Used for the single most important
/// card on a screen (e.g. the streak hero on Progress, the health-score
/// card on Today). Per `docs/design.md`, "only one hero card per screen."
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

class ZHeroCard extends StatelessWidget {
  const ZHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.spaceMdPlus),
    this.borderRadius = AppDimens.shapeLg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: radius,
              ),
            ),
          ),
          const Positioned.fill(
            child: ZPatternOverlay(
              variant: ZPatternVariant.original,
              opacity: 0.10,
              animate: true,
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
