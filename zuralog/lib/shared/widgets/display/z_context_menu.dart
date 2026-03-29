/// Zuralog Design System — Context Menu Component.
///
/// Wraps any child widget with long-press detection and shows a branded popup
/// menu. Menu background uses Surface Raised (#272729), rounded corners at
/// shapeSm (12px), and supports destructive item styling.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A single item shown inside the [ZContextMenu] popup.
class ZContextMenuItem {
  /// Creates a context menu item.
  const ZContextMenuItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.isDestructive = false,
  });

  /// The text label for this menu option.
  final String label;

  /// Called when the user taps this item.
  final VoidCallback onTap;

  /// Optional leading icon displayed before the label.
  final IconData? icon;

  /// When `true`, the label and icon are rendered in error red (#FF3B30).
  final bool isDestructive;
}

/// Wraps a [child] widget with long-press context menu behavior.
///
/// On long press, a popup menu appears with the given [items]. The menu uses
/// the brand Surface Raised color and shapeSm radius.
///
/// ```dart
/// ZContextMenu(
///   items: [
///     ZContextMenuItem(label: 'Edit', icon: Icons.edit, onTap: _edit),
///     ZContextMenuItem(label: 'Delete', icon: Icons.delete, onTap: _delete, isDestructive: true),
///   ],
///   child: MyCardWidget(),
/// )
/// ```
class ZContextMenu extends StatelessWidget {
  /// Creates a context menu wrapper.
  const ZContextMenu({
    super.key,
    required this.child,
    required this.items,
  });

  /// The widget that responds to a long press.
  final Widget child;

  /// The menu items to display in the popup.
  final List<ZContextMenuItem> items;

  Future<void> _showMenu(BuildContext context) async {
    // Find the position of the child widget on screen so the menu appears
    // near it.
    final renderBox = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(
          renderBox.size.center(Offset.zero),
          ancestor: overlay,
        ),
        renderBox.localToGlobal(
          renderBox.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final result = await showMenu<int>(
      context: context,
      position: position,
      color: AppColorsOf(context).surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.shapeSm),
      ),
      elevation: 8,
      items: [
        for (int i = 0; i < items.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 44,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
            ),
            child: Row(
              children: [
                if (items[i].icon != null) ...[
                  Icon(
                    items[i].icon,
                    size: 20,
                    color: items[i].isDestructive
                        ? AppColorsOf(context).error
                        : AppColorsOf(context).textPrimary,
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                ],
                Text(
                  items[i].label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: items[i].isDestructive
                        ? AppColorsOf(context).error
                        : AppColorsOf(context).textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (result != null && result >= 0 && result < items.length) {
      items[result].onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showMenu(context),
      child: child,
    );
  }
}
