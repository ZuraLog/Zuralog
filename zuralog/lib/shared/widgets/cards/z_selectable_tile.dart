/// Zuralog Design System — Selectable Tile Component.
///
/// A frame-only selectable tile that handles selection decoration.
/// Wrap any content in this widget to give it animated selection state.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/shared/widgets/buttons/spring_button.dart';

/// A frame-only selectable tile that handles selection decoration.
/// Wrap any content in this widget to give it animated selection state.
///
/// Usage:
/// ```dart
/// ZSelectableTile(
///   isSelected: _selected,
///   onTap: () => setState(() => _selected = !_selected),
///   child: Text('Option A'),
/// )
/// ```
class ZSelectableTile extends StatelessWidget {
  const ZSelectableTile({
    super.key,
    required this.isSelected,
    required this.onTap,
    required this.child,
    this.selectedColor,
    this.padding,
    this.borderRadius,
    this.showCheckIndicator = true,
    this.scaleTarget = 0.97,
  });

  /// Whether this tile is currently selected.
  final bool isSelected;

  /// Called when the tile is tapped.
  final VoidCallback onTap;

  /// The content displayed inside the tile.
  final Widget child;

  /// The accent color used for the border and background tint when selected.
  ///
  /// Defaults to [AppColors.primary].
  final Color? selectedColor;

  /// Inner padding around [child].
  ///
  /// Defaults to [EdgeInsets.all(AppDimens.spaceMd)].
  final EdgeInsetsGeometry? padding;

  /// Corner radius of the tile.
  ///
  /// Defaults to [AppDimens.shapeMd].
  final double? borderRadius;

  /// When true, shows a check_circle_rounded icon in the top-right corner
  /// that fades in when selected and out when deselected.
  ///
  /// Defaults to true.
  final bool showCheckIndicator;

  /// The scale factor applied on press-down by [ZuralogSpringButton].
  ///
  /// Defaults to 0.97.
  final double scaleTarget;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedColor = selectedColor ?? AppColors.primary;
    final resolvedRadius = BorderRadius.circular(
      borderRadius ?? AppDimens.shapeMd,
    );
    final resolvedPadding =
        padding ?? const EdgeInsets.all(AppDimens.spaceMd);

    final animatedContainer = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding: resolvedPadding,
      decoration: BoxDecoration(
        color: isSelected
            ? resolvedColor.withValues(alpha: 0.08)
            : colorScheme.surface,
        border: isSelected
            ? Border.all(color: resolvedColor, width: 1.5)
            : Border.all(
                color: colorScheme.outline.withValues(alpha: 0.4),
                width: 1.0,
              ),
        borderRadius: resolvedRadius,
      ),
      child: showCheckIndicator
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                child,
                Positioned(
                  top: 8,
                  right: 8,
                  child: AnimatedOpacity(
                    opacity: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: resolvedColor,
                      size: AppDimens.iconMd,
                    ),
                  ),
                ),
              ],
            )
          : child,
    );

    return ZuralogSpringButton(
      onTap: onTap,
      scaleTarget: scaleTarget,
      child: animatedContainer,
    );
  }
}
