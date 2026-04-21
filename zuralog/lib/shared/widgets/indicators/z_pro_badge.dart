/// Zuralog Design System — Pro Badge Component.
///
/// Pill-shaped badge that signals premium-only content. Uses Sage Green
/// at 15 % opacity with the brand topographic pattern layered on top.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// A small pill badge labelled "PRO" that indicates premium content.
///
/// Optionally shows a lock icon to the left of the label when [showLock]
/// is true — useful when the badge is placed on a locked overlay.
///
/// Example:
/// ```dart
/// const ZProBadge()
/// const ZProBadge(showLock: true)
/// ```
class ZProBadge extends StatelessWidget {
  /// Creates a [ZProBadge].
  const ZProBadge({super.key, this.showLock = false});

  /// Whether to display a small lock icon (14 px) before the label.
  final bool showLock;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Semantics(
      label: 'Pro feature',
      container: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.shapePill),
        child: Stack(
          children: [
            // Background fill — Sage Green at 15 % opacity.
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: showLock ? 8 : 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.shapePill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showLock) ...[
                    Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    'PRO',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Decorative pattern overlay — Sage at 15 % opacity, animated.
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: ZPatternOverlay(
                    variant: ZPatternVariant.sage,
                    opacity: 0.15,
                    animate: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
