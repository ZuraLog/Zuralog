/// Zuralog Design System — List Item Component.
///
/// A brand-bible-compliant list item row with a pattern-textured icon square,
/// title, optional subtitle, and trailing chevron or custom widget.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// The divider color between list item rows — warm white at 4% opacity,
/// per the brand bible spec for grouped list dividers.
const Color _kDividerColor = Color.fromRGBO(240, 238, 233, 0.04);

/// A list item row matching the brand bible specification.
///
/// Different from [ZSettingsTile] — this variant uses a pattern-textured
/// icon square (32px, radius 8, with [ZPatternOverlay] at 12% opacity)
/// instead of a [ZIconBadge].
///
/// Usage:
/// ```dart
/// ZListItem(
///   icon: Icons.person_rounded,
///   iconColor: AppColors.primary,
///   title: 'Profile',
///   subtitle: 'Manage your account',
///   onTap: () => context.push(RouteNames.profile),
/// )
/// ```
class ZListItem extends StatelessWidget {
  /// Creates a [ZListItem].
  const ZListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.showChevron = true,
    this.onTap,
    this.showDivider = true,
  });

  /// The primary label for this row.
  final String title;

  /// Optional secondary label shown below [title].
  final String? subtitle;

  /// Icon displayed inside the pattern-textured square.
  final IconData? icon;

  /// Tint color for the icon. Falls back to [AppColors.textPrimary] via theme.
  final Color? iconColor;

  /// Custom trailing widget. When provided, replaces the default chevron.
  final Widget? trailing;

  /// Whether to show a chevron arrow when [trailing] is null.
  /// Defaults to `true`.
  final bool showChevron;

  /// Callback invoked when the row is tapped.
  final VoidCallback? onTap;

  /// Whether to draw a 1px divider along the bottom edge.
  /// Defaults to `true`.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    // --- Trailing -----------------------------------------------------------
    final Widget trailingWidget;
    if (trailing != null) {
      trailingWidget = trailing!;
    } else if (showChevron) {
      trailingWidget = Icon(
        Icons.chevron_right_rounded,
        size: AppDimens.iconMd,
        color: colors.textSecondary,
      );
    } else {
      trailingWidget = const SizedBox.shrink();
    }

    // --- Row content --------------------------------------------------------
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd, // 16
        vertical: 12,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            _PatternIconSquare(
              icon: icon!,
              iconColor: iconColor ?? colors.textPrimary,
              backgroundColor: colors.surfaceRaised,
            ),
            const SizedBox(width: AppDimens.spaceMd),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          trailingWidget,
        ],
      ),
    );

    // --- Tappable wrapper ---------------------------------------------------
    final Widget tappable;
    if (onTap != null) {
      tappable = Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: row,
          ),
        ),
      );
    } else {
      tappable = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: row,
      );
    }

    // --- Divider ------------------------------------------------------------
    if (!showDivider) return tappable;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tappable,
        Container(height: 1, color: _kDividerColor),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private helper: the 32px pattern-textured icon square.
// ---------------------------------------------------------------------------

class _PatternIconSquare extends StatelessWidget {
  const _PatternIconSquare({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  static const double _size = 32;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.shapeXs), // 8
      child: SizedBox.square(
        dimension: _size,
        child: Stack(
          children: [
            // Layer 1: solid background
            Positioned.fill(
              child: ColoredBox(color: backgroundColor),
            ),
            // Layer 2: pattern texture at 12% opacity
            const Positioned.fill(
              child: ZPatternOverlay(
                opacity: 0.12,
                variant: ZPatternVariant.original,
              ),
            ),
            // Layer 3: centered icon
            Center(
              child: Icon(
                icon,
                size: 18,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
