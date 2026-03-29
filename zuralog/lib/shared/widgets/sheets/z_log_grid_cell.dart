/// Zuralog Design System — Log Grid Cell Widget.
///
/// A tappable cell for the log grid sheet. Displays a Material icon in a
/// circular container plus a label below. Supports two overlay states:
/// - [isLogged]: green checkmark at top-right of the circle
/// - [isComingSoon]: "Soon" badge at bottom-right, reduced opacity
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/z_badge.dart';

/// A single cell in the log-what-you-want grid sheet.
///
/// Example:
/// ```dart
/// ZLogGridCell(
///   icon: Icons.water_drop_rounded,
///   label: 'Water',
///   isLogged: true,
///   onTap: () => _openWaterPanel(context),
/// )
/// ```
class ZLogGridCell extends StatelessWidget {
  const ZLogGridCell({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLogged = false,
    this.isComingSoon = false,
  });

  /// Icon displayed in the circular icon container.
  final IconData icon;

  /// Label shown below the circle.
  final String label;

  /// Called when the user taps the cell.
  final VoidCallback onTap;

  /// When true, a green checkmark is overlaid at the top-right of the circle.
  final bool isLogged;

  /// When true, the cell is faded and shows a "Soon" badge.
  final bool isComingSoon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    Widget cell = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconCircle(
            icon: icon,
            isLogged: isLogged,
            isComingSoon: isComingSoon,
            colors: colors,
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (isComingSoon) {
      cell = Opacity(opacity: 0.5, child: cell);
    }

    return cell;
  }
}

/// Private circle widget with optional overlays.
class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.icon,
    required this.isLogged,
    required this.isComingSoon,
    required this.colors,
  });

  final IconData icon;
  final bool isLogged;
  final bool isComingSoon;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Icon circle
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 26,
            color: colors.primary,
          ),
        ),

        // Logged checkmark — top-right
        if (isLogged)
          Positioned(
            top: -2,
            right: -2,
            child: Icon(
              Icons.check_circle,
              size: 18,
              color: AppColors.statusConnected, // iOS system green
            ),
          ),

        // Coming-soon badge — bottom-right
        if (isComingSoon)
          Positioned(
            bottom: -4,
            right: -8,
            child: ZBadge(
              label: 'Soon',
              color: colors.primary.withValues(alpha: 0.2),
              textColor: colors.primary,
            ),
          ),
      ],
    );
  }
}
