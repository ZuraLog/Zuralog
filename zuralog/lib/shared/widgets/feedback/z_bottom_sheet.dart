/// Zuralog Design System — Bottom Sheet Component.
///
/// Modal bottom sheet with brand-correct surface color, drag handle,
/// optional title, and scrollable content area.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A themed bottom sheet that follows the Zuralog design system.
///
/// Uses [surfaceOverlay] background, rounded top corners at [shapeXl],
/// and a centered drag handle indicator.
///
/// Prefer the static [ZBottomSheet.show] helper over building this
/// widget manually.
class ZBottomSheet extends StatelessWidget {
  const ZBottomSheet({
    super.key,
    required this.child,
    this.title,
  });

  /// The scrollable content displayed inside the sheet.
  final Widget child;

  /// Optional title shown below the drag handle.
  final String? title;

  /// Shows a modal bottom sheet with the Zuralog design system styling.
  ///
  /// Returns the value passed to [Navigator.pop] when the sheet closes,
  /// or `null` if dismissed by tapping the scrim.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.40),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ZBottomSheet(title: title, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceOverlay,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimens.shapeXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle.
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.40),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Optional title.
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppDimens.spaceMd,
                right: AppDimens.spaceMd,
                top: AppDimens.spaceMd,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title!,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),

          // Scrollable content.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
