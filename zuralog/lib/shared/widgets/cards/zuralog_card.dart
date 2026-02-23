/// Zuralog Design System — Card Component.
///
/// A theme-aware card that implements the view-design.md Section 1.3 spec:
/// - Light mode: white surface, soft diffusion shadow.
/// - Dark mode: dark surface (#1C1C1E), 1px border (#38383A), no shadow.
/// - 24px corner radius in both modes.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_dimens.dart';

/// Theme-aware card component for the Zuralog design system.
///
/// Renders differently in light and dark mode:
/// - **Light**: White background with a subtle diffusion shadow
///   (`0px 4px 20px rgba(0,0,0,0.05)`) and no border.
/// - **Dark**: Dark surface (`#1C1C1E`) with a 1px separator border
///   (`#38383A`) and no shadow (prevents glow artifacts on OLED).
///
/// Corner radius is fixed at 24px per the design specification.
///
/// Example usage:
/// ```dart
/// ZuralogCard(
///   padding: EdgeInsets.all(AppDimens.spaceMd),
///   onTap: () => _handleTap(),
///   child: Text('Card content'),
/// )
/// ```
class ZuralogCard extends StatelessWidget {
  /// The content widget rendered inside the card.
  final Widget child;

  /// Inner padding around [child].
  ///
  /// Defaults to [AppDimens.spaceMd] (16px) on all sides.
  final EdgeInsetsGeometry? padding;

  /// Optional tap callback.
  ///
  /// When provided, the card gains [InkWell] tap behavior with
  /// a clipped ripple matching the card's corner radius.
  /// Pass `null` for a non-interactive card.
  final VoidCallback? onTap;

  /// Creates a [ZuralogCard].
  const ZuralogCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderRadius = BorderRadius.circular(AppDimens.radiusCard);

    final container = Container(
      padding: padding ?? const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: borderRadius,
        // Light mode: soft shadow; dark mode: 1px border.
        border: isDark
            ? Border.all(color: theme.colorScheme.outline, width: 1)
            : null,
        boxShadow: isDark ? null : AppDimens.cardShadowLight,
      ),
      child: child,
    );

    if (onTap != null) {
      // Clip the InkWell ripple to the card's rounded corners.
      return ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: container,
          ),
        ),
      );
    }

    return container;
  }
}
