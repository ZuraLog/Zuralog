/// Zuralog Design System — Unified Button Component.
///
/// Replaces [PrimaryButton] and [SecondaryButton] with a single
/// variant-driven widget.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/shared/widgets/buttons/spring_button.dart';

/// Button visual style variants.
enum ZButtonVariant { primary, secondary, destructive, ghost }

/// Unified button component for Zuralog.
///
/// Wraps [ZuralogSpringButton] for tactile press feedback.
/// Colors derive entirely from [Theme] — no hardcoded values.
///
/// Usage:
/// ```dart
/// ZButton(label: 'Save', onPressed: _save)
/// ZButton(label: 'Delete', onPressed: _delete, variant: ZButtonVariant.destructive)
/// ZButton(label: 'Loading...', onPressed: null, isLoading: true)
/// ```
class ZButton extends StatelessWidget {
  const ZButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ZButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
  });

  /// The button label text.
  final String label;

  /// Tap callback. Pass null to disable the button.
  final VoidCallback? onPressed;

  /// Visual style variant. Defaults to [ZButtonVariant.primary].
  final ZButtonVariant variant;

  /// When true, shows a loading spinner and disables the button.
  final bool isLoading;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether the button expands to fill available width. Defaults to true.
  final bool isFullWidth;

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget buttonChild = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                _foregroundColor(colorScheme),
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    if (isFullWidth) {
      buttonChild = Center(child: buttonChild);
    }

    return ZuralogSpringButton(
      onTap: _isDisabled ? null : onPressed,
      disabled: _isDisabled,
      child: _buildButton(context, colorScheme, buttonChild),
    );
  }

  Widget _buildButton(
    BuildContext context,
    ColorScheme colorScheme,
    Widget child,
  ) {
    switch (variant) {
      case ZButtonVariant.primary:
        return ElevatedButton(
          onPressed: _isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: isFullWidth
                ? const Size(double.infinity, 56)
                : const Size(0, 56),
          ),
          child: child,
        );
      case ZButtonVariant.secondary:
        return OutlinedButton(
          onPressed: _isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: isFullWidth
                ? const Size(double.infinity, 56)
                : const Size(0, 56),
          ),
          child: child,
        );
      case ZButtonVariant.destructive:
        return ElevatedButton(
          onPressed: _isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            minimumSize: isFullWidth
                ? const Size(double.infinity, 56)
                : const Size(0, 56),
          ),
          child: child,
        );
      case ZButtonVariant.ghost:
        return TextButton(
          onPressed: _isDisabled ? null : onPressed,
          style: TextButton.styleFrom(
            minimumSize: isFullWidth
                ? const Size(double.infinity, 56)
                : const Size(0, 56),
          ),
          child: child,
        );
    }
  }

  Color _foregroundColor(ColorScheme colorScheme) {
    switch (variant) {
      case ZButtonVariant.primary:
        return colorScheme.onPrimary;
      case ZButtonVariant.secondary:
        return colorScheme.primary;
      case ZButtonVariant.destructive:
        return colorScheme.onError;
      case ZButtonVariant.ghost:
        return colorScheme.primary;
    }
  }
}
