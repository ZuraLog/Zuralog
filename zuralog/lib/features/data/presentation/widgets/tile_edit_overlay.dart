/// Zuralog — TileEditOverlay widget (Phase 7).
///
/// Wraps a [MetricTile] in edit mode, overlaying visual controls (size badge,
/// palette icon, visibility toggle) and applying a wiggle animation.
///
/// The drag handle for [ReorderableDragStartListener] is NOT part of this
/// widget — the grid (Phase 8) wraps [TileEditOverlay] externally.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';

// ── TileEditOverlay ────────────────────────────────────────────────────────────

/// Wraps [child] (a [MetricTile]) in edit mode.
///
/// Adds:
/// - Size badge (top-left): cycles through [TileId.allowedSizes] on tap.
/// - Palette button (top-right): opens a colour picker via [onColorPick].
/// - Eye button (top-right): toggles tile visibility via [onVisibilityToggled].
/// - Wiggle animation: ±2° oscillating rotation (iOS home-screen style).
/// - Dimmed + strikethrough overlay when [isVisible] is false.
/// - Accessibility [customSemanticsActions] for screen-reader users.
class TileEditOverlay extends StatefulWidget {
  const TileEditOverlay({
    super.key,
    required this.tileId,
    required this.currentSize,
    required this.isVisible,
    required this.currentColorOverride,
    required this.onSizeChanged,
    required this.onVisibilityToggled,
    required this.onColorPick,
    required this.child,
  });

  /// The tile identifier — used to determine available sizes.
  final TileId tileId;

  /// Current layout size of the tile.
  final TileSize currentSize;

  /// Whether the tile is visible. False = shown dimmed with strikethrough.
  final bool isVisible;

  /// ARGB color int override, or null for the default category color.
  final int? currentColorOverride;

  /// Called with the next [TileSize] when the size badge is tapped.
  final ValueChanged<TileSize> onSizeChanged;

  /// Called when the eye button is tapped.
  final VoidCallback onVisibilityToggled;

  /// Called when the palette button is tapped (parent opens the picker sheet).
  final VoidCallback onColorPick;

  /// The underlying tile widget being wrapped.
  final Widget child;

  @override
  State<TileEditOverlay> createState() => _TileEditOverlayState();
}

class _TileEditOverlayState extends State<TileEditOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _wiggle;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _wiggle = Tween<double>(begin: -0.035, end: 0.035).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Stagger: each tile starts at a different phase so they don't all sync.
    _controller.value = widget.tileId.index / TileId.values.length;
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _sizeLabel(TileSize size) {
    switch (size) {
      case TileSize.square:
        return '1×1';
      case TileSize.tall:
        return '1×2';
      case TileSize.wide:
        return '2×1';
    }
  }

  void _handleSizeChanged() {
    widget.onSizeChanged(widget.tileId.nextSize(widget.currentSize));
  }

  // ── Semantic actions ────────────────────────────────────────────────────────

  Map<CustomSemanticsAction, VoidCallback> get _semanticActions => {
        if (widget.tileId.allowedSizes.length > 1)
          const CustomSemanticsAction(label: 'Change Size'): _handleSizeChanged,
        const CustomSemanticsAction(label: 'Toggle Visibility'):
            widget.onVisibilityToggled,
      };

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    Widget content = AnimatedBuilder(
      animation: _wiggle,
      builder: (context, child) {
        return Transform.rotate(
          angle: _wiggle.value,
          child: child,
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Underlying tile ─────────────────────────────────────────────────
          widget.child,

          // ── Top-right: Size badge + Palette + Eye ──────────────────────────
          Positioned(
            top: 2,
            right: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.tileId.allowedSizes.length > 1) ...[
                  GestureDetector(
                    onTap: _handleSizeChanged,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _sizeLabel(widget.currentSize),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                _ControlIconButton(
                  icon: Icons.palette_rounded,
                  onTap: widget.onColorPick,
                ),
                const SizedBox(width: 4),
                _ControlIconButton(
                  icon: widget.isVisible
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  onTap: widget.onVisibilityToggled,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Apply dim for hidden tiles, with strikethrough as a Stack sibling
    // so the strikethrough is NOT dimmed by the Opacity wrapper.
    if (!widget.isVisible) {
      content = Stack(
        children: [
          Opacity(
            opacity: AppDimens.disabledOpacity,
            child: content,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _StrikethroughPainter(color: colors.textTertiary),
              ),
            ),
          ),
        ],
      );
    }

    return Semantics(
      customSemanticsActions: _semanticActions,
      child: content,
    );
  }
}

// ── _ControlIconButton ─────────────────────────────────────────────────────────

/// A small icon button used in the edit overlay controls row.
class _ControlIconButton extends StatelessWidget {
  const _ControlIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.cardBackground.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: colors.textPrimary),
      ),
    );
  }
}

// ── _StrikethroughPainter ─────────────────────────────────────────────────────

/// Draws a single horizontal line across the centre of the tile.
class _StrikethroughPainter extends CustomPainter {
  const _StrikethroughPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_StrikethroughPainter oldDelegate) =>
      oldDelegate.color != color;
}
