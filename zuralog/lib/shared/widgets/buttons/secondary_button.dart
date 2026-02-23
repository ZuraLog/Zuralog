/// Zuralog Design System — Secondary Button Component.
///
/// A full-width, pill-shaped button with a translucent background.
/// Used for secondary actions that sit alongside a [PrimaryButton].
library;

import 'package:flutter/material.dart';

/// Full-width, pill-shaped secondary action button.
///
/// Uses [AppTheme]'s `textButtonTheme` — adapts automatically to light and
/// dark mode via the translucent grey background defined in the theme.
///
/// Optionally displays a leading [IconData] for icon-labeled actions.
///
/// Example usage:
/// ```dart
/// SecondaryButton(
///   label: 'Continue with Apple',
///   icon: Icons.apple,
///   onPressed: () => _handleAppleAuth(),
/// )
/// ```
class SecondaryButton extends StatelessWidget {
  /// The text label displayed on the button.
  final String label;

  /// The callback invoked when the button is tapped.
  ///
  /// Pass `null` to permanently disable the button.
  final VoidCallback? onPressed;

  /// Optional leading icon displayed before the label.
  final IconData? icon;

  /// Creates a [SecondaryButton].
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: icon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(label),
              ],
            )
          : Text(label),
    );
  }
}
