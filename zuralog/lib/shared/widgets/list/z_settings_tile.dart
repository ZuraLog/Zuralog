/// Zuralog Design System — Settings Tile Component.
///
/// A settings-style list tile with an icon badge, title, optional subtitle,
/// and optional trailing widget or chevron.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Vertical padding for the tile row — intentionally off-grid (not 8 or 16)
/// to match the visual rhythm of platform settings lists.
const double _kVerticalPadding = 14.0;

/// A settings-style list tile with an icon badge, title, optional subtitle,
/// and optional trailing widget or chevron.
///
/// Wraps the entire row in a [ZuralogSpringButton] for press animation —
/// no manual [bool _pressed] or [GestureDetector] needed.
///
/// Usage:
/// ```dart
/// ZSettingsTile(
///   icon: Icons.person_rounded,
///   iconColor: AppColors.primary,
///   title: 'Profile',
///   onTap: () => context.push(RouteNames.profile),
/// )
/// ```
class ZSettingsTile extends StatelessWidget {
  /// Creates a [ZSettingsTile].
  const ZSettingsTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.showChevron = true,
    this.titleColor,
    this.iconBadgeSize = 36,
  });

  /// The icon shown inside the [ZIconBadge].
  final IconData icon;

  /// The accent color for the [ZIconBadge] background and icon.
  final Color iconColor;

  /// The primary label for this tile.
  final String title;

  /// Optional secondary label shown below [title].
  final String? subtitle;

  /// Callback invoked when the tile is tapped.
  final VoidCallback? onTap;

  /// Custom trailing widget. When provided, overrides the chevron.
  final Widget? trailing;

  /// Whether to show a [Icons.chevron_right_rounded] when [trailing] is null.
  /// Defaults to `true`.
  final bool showChevron;

  /// Override for the title text color.
  /// Defaults to [ColorScheme.onSurface] (theme-aware).
  /// Use [AppColors.statusError] for destructive rows.
  final Color? titleColor;

  /// The size of the [ZIconBadge]. Defaults to 36.
  final double iconBadgeSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = AppColorsOf(context);

    final Widget trailingWidget;
    if (trailing != null) {
      trailingWidget = trailing!;
    } else if (showChevron) {
      trailingWidget = Icon(
        Icons.chevron_right_rounded,
        size: AppDimens.iconMd,
        color: colors.textTertiary,
      );
    } else {
      trailingWidget = const SizedBox.shrink();
    }

    return ZuralogSpringButton(
      onTap: onTap,
      disabled: onTap == null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: _kVerticalPadding,
        ),
        child: Row(
          children: [
            ZIconBadge(
              icon: icon,
              color: iconColor,
              size: iconBadgeSize,
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: titleColor ?? colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            trailingWidget,
          ],
        ),
      ),
    );
  }
}
