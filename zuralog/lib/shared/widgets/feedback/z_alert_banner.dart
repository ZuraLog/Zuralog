/// Zuralog Design System — Alert Banner Component.
///
/// An inline banner with a colored left accent, variant icon, and
/// optional title, body text, and dismiss button.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// Visual variant that controls the accent color and icon.
enum ZAlertVariant {
  info(
    color: AppColors.syncing,
    icon: Icons.info_outline,
  ),
  success(
    color: AppColors.success,
    icon: Icons.check_circle_outline,
    patternVariant: ZPatternVariant.sage,
  ),
  warning(
    color: AppColors.warning,
    icon: Icons.warning_amber_rounded,
    patternVariant: ZPatternVariant.amber,
  ),
  error(
    color: AppColors.error,
    icon: Icons.error_outline,
    patternVariant: ZPatternVariant.crimson,
  );

  const ZAlertVariant({
    required this.color,
    required this.icon,
    this.patternVariant,
  });

  /// Accent and icon color for this variant.
  final Color color;

  /// Leading icon for this variant.
  final IconData icon;

  /// Optional pattern variant for the subtle background overlay.
  final ZPatternVariant? patternVariant;
}

/// An inline alert banner with a left accent border and variant icon.
///
/// Shows a message and optional title inside a [surfaceRaised] container
/// with a 3px colored left border. When [onDismiss] is provided, an X
/// button appears in the top-right corner.
class ZAlertBanner extends StatelessWidget {
  const ZAlertBanner({
    super.key,
    required this.variant,
    required this.message,
    this.title,
    this.onDismiss,
  });

  /// Controls the accent color and leading icon.
  final ZAlertVariant variant;

  /// The body text of the banner.
  final String message;

  /// Optional title displayed above the body in bold.
  final String? title;

  /// When provided, shows an X dismiss button in the top-right corner.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: variant.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Subtle pattern overlay matching the variant.
          if (variant.patternVariant != null)
            Positioned.fill(
              child: ZPatternOverlay(
                variant: variant.patternVariant!,
                opacity: 0.04,
              ),
            ),
          IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left accent border.
          Container(
            width: 4,
            // Match the height of the content by letting it expand.
            color: variant.color,
          ),

          // Icon.
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppDimens.spaceMd - 4, // account for accent width
                top: AppDimens.spaceMd,
              ),
              child: Icon(
                variant.icon,
                size: 20,
                color: variant.color,
              ),
            ),
          ),

          const SizedBox(width: AppDimens.spaceSm),

          // Text content.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimens.spaceMd,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceXxs),
                  ],
                  Text(
                    message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dismiss button.
          if (onDismiss != null)
            Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: onDismiss,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceSm + 4),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
        ],
      ),
    );
  }
}
