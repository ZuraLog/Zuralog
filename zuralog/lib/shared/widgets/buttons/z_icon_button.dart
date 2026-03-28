/// Zuralog Design System — Icon Button Component.
///
/// A 40px icon button (circle or rounded square) with optional filled
/// background. No pattern — too small for the topographic texture.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A compact icon button for toolbars, headers, and inline actions.
///
/// Ensures a minimum 44x44px hit area for accessibility regardless of
/// the 40px visual size. The entire 44px area is tappable.
///
/// Example:
/// ```dart
/// ZIconButton(icon: Icons.close, onPressed: _dismiss)
/// ZIconButton(icon: Icons.settings, onPressed: _open, isCircle: false)
/// ZIconButton(icon: Icons.favorite, onPressed: _like, isSage: true)
/// ```
class ZIconButton extends StatelessWidget {
  const ZIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isCircle = true,
    this.filled = true,
    this.isSage = false,
    this.size = 40,
    this.iconSize = 20,
    this.semanticLabel,
  });

  /// The icon to display.
  final IconData icon;

  /// Tap callback.
  final VoidCallback? onPressed;

  /// Whether the button is a circle (true) or a rounded square (false).
  final bool isCircle;

  /// Whether the button has a filled surfaceRaised background.
  /// When false, the background is transparent.
  final bool filled;

  /// When true, the icon color is Sage instead of textPrimary.
  final bool isSage;

  /// Visual size of the button container. Defaults to 40px.
  final double size;

  /// Size of the icon. Defaults to 20px.
  final double iconSize;

  /// Accessible label for screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final iconColor = isSage ? colors.primary : colors.textPrimary;
    final bgColor = filled ? colors.surfaceRaised : Colors.transparent;
    final shape = isCircle
        ? BoxShape.circle
        : BoxShape.rectangle;
    final borderRadius = isCircle ? null : BorderRadius.circular(10);

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bgColor,
                shape: shape,
                borderRadius: borderRadius,
              ),
              child: Center(
                child: Icon(icon, size: iconSize, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
