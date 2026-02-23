/// Zuralog Design System — Secondary Button Component.
///
/// A full-width, pill-shaped button with a translucent background.
/// Used for secondary actions that sit alongside a [PrimaryButton].
///
/// This widget explicitly applies the full-width filled style rather than
/// relying on the global [TextButton] theme, which is intentionally
/// left as a compact link style to avoid breaking inline [Row] layouts.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Full-width, pill-shaped secondary action button.
///
/// Explicitly styled with a translucent grey background and full-width
/// minimum size. Adapts automatically to light and dark mode via
/// [Theme.of(context).colorScheme.surfaceContainerHighest].
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor:
            isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        backgroundColor:
            isDark ? AppColors.secondaryButtonDark : AppColors.secondaryButtonLight,
        minimumSize: const Size(double.infinity, AppDimens.touchTargetMin),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusButton),
        ),
        textStyle: AppTextStyles.h3,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceLg,
          vertical: AppDimens.spaceMd,
        ),
      ),
      child: icon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: AppDimens.iconMd),
                const SizedBox(width: AppDimens.spaceSm),
                Text(label),
              ],
            )
          : Text(label),
    );
  }
}
