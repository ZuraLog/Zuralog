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
/// ZIconButton(icon: Icons.close, onPressed: _dismiss, semanticLabel: 'Close')
/// ZIconButton(icon: Icons.settings, onPressed: _open, isCircle: false, semanticLabel: 'Settings')
/// ZIconButton(icon: Icons.favorite, onPressed: _like, isSage: true, semanticLabel: 'Like')
/// ```
class ZIconButton extends StatefulWidget {
  const ZIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.isCircle = true,
    this.filled = true,
    this.isSage = false,
    this.size = 40,
    this.iconSize = 20,
  });

  /// The icon to display.
  final IconData icon;

  /// Tap callback. Pass null to disable the button.
  final VoidCallback? onPressed;

  /// Accessible label for screen readers. Required.
  final String semanticLabel;

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

  @override
  State<ZIconButton> createState() => _ZIconButtonState();
}

class _ZIconButtonState extends State<ZIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final iconColor = widget.isSage ? colors.primary : colors.textPrimary;
    final bgColor = widget.filled ? colors.surfaceRaised : Colors.transparent;
    final shape = widget.isCircle ? BoxShape.circle : BoxShape.rectangle;
    final borderRadius = widget.isCircle ? null : BorderRadius.circular(10);

    final isDisabled = widget.onPressed == null;

    return Semantics(
      label: widget.semanticLabel,
      button: true,
      enabled: !isDisabled,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: AppMotion.durationFast,
        child: Opacity(
          opacity: isDisabled ? AppDimens.disabledOpacity : 1.0,
          child: GestureDetector(
            onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
            onTapUp: isDisabled
                ? null
                : (_) {
                    setState(() => _isPressed = false);
                    HapticFeedback.lightImpact();
                    widget.onPressed?.call();
                  },
            onTapCancel: isDisabled ? null : () => setState(() => _isPressed = false),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: shape,
                    borderRadius: borderRadius,
                  ),
                  child: Center(
                    child: Icon(widget.icon, size: widget.iconSize, color: iconColor),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
