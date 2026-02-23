/// Zuralog Design System — Primary Button Component.
///
/// A full-width, pill-shaped button using the Sage Green brand color.
/// This is the main call-to-action component for the app.
library;

import 'package:flutter/material.dart';

/// Full-width, pill-shaped primary action button.
///
/// Uses [AppTheme]'s `elevatedButtonTheme` — no hardcoded colors.
/// Displays a [CircularProgressIndicator] when [isLoading] is true,
/// and disables tap interaction during loading to prevent double-submission.
///
/// Example usage:
/// ```dart
/// PrimaryButton(
///   label: 'Get Started',
///   onPressed: () => _handleStart(),
///   isLoading: _isLoading,
/// )
/// ```
class PrimaryButton extends StatelessWidget {
  /// The text label displayed on the button.
  final String label;

  /// The callback invoked when the button is tapped.
  ///
  /// Pass `null` to permanently disable the button (e.g., during validation).
  /// When [isLoading] is `true`, this callback is automatically disabled.
  final VoidCallback? onPressed;

  /// Whether to show a loading indicator instead of the label.
  ///
  /// When `true`, the button is visually disabled and shows a spinner.
  /// Defaults to `false`.
  final bool isLoading;

  /// Creates a [PrimaryButton].
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      // Disable tap when loading to prevent double-submission.
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                // Match foreground color from theme to stay on-brand.
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            )
          : Text(label),
    );
  }
}
