/// Zuralog Design System — Toggle Switch Component.
///
/// Custom-painted toggle with Sage track pattern overlay when active.
/// Does not use Material Switch — fully brand-aligned.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// A brand-styled toggle switch.
///
/// When on, the track fills with Sage (#CFE1B9) and shows a topographic
/// pattern overlay. When off, the track uses surfaceRaised with a muted thumb.
///
/// If [label] is provided, the label appears to the left of the toggle
/// separated by [AppDimens.spaceSm].
class ZToggle extends StatefulWidget {
  const ZToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.enabled = true,
    this.label,
  });

  /// Whether the toggle is currently on.
  final bool value;

  /// Called when the user taps the toggle. Null disables interaction.
  final ValueChanged<bool>? onChanged;

  /// Whether the toggle is interactive.
  final bool enabled;

  /// Optional label shown to the left of the toggle.
  final String? label;

  @override
  State<ZToggle> createState() => _ZToggleState();
}

class _ZToggleState extends State<ZToggle> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _position;
  late final Animation<Color?> _trackColor;
  late final Animation<Color?> _thumbColor;

  static const _trackWidth = 44.0;
  static const _trackHeight = 26.0;
  static const _thumbDiameter = 22.0;
  static const _thumbPadding = 2.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.durationFast,
      value: widget.value ? 1.0 : 0.0,
    );
    _position = Tween<double>(
      begin: _thumbPadding,
      end: _trackWidth - _thumbDiameter - _thumbPadding,
    ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.curveEntrance));
    _trackColor = ColorTween(
      begin: AppColors.surfaceRaised,
      end: AppColors.primary,
    ).animate(_controller);
    _thumbColor = ColorTween(
      begin: AppColors.textSecondary,
      end: Colors.white,
    ).animate(_controller);
  }

  @override
  void didUpdateWidget(ZToggle old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.enabled || widget.onChanged == null) return;
    widget.onChanged!(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final toggle = Semantics(
      toggled: widget.value,
      label: widget.label ?? 'Toggle',
      enabled: widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1.0 : 0.4,
        child: GestureDetector(
          onTap: _handleTap,
          child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return SizedBox(
              width: _trackWidth,
              height: _trackHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_trackHeight / 2),
                child: Stack(
                  children: [
                    // Track background.
                    Container(
                      decoration: BoxDecoration(
                        color: _trackColor.value,
                        borderRadius: BorderRadius.circular(_trackHeight / 2),
                      ),
                    ),
                    // Pattern overlay — visible only when on.
                    if (_controller.value > 0.0)
                      Opacity(
                        opacity: _controller.value,
                        child: const ZPatternOverlay(
                          variant: ZPatternVariant.sage,
                          opacity: 0.15,
                          blendMode: BlendMode.colorBurn,
                        ),
                      ),
                    // Thumb.
                    Positioned(
                      left: _position.value,
                      top: _thumbPadding,
                      child: Container(
                        width: _thumbDiameter,
                        height: _thumbDiameter,
                        decoration: BoxDecoration(
                          color: _thumbColor.value,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      ),
    );

    if (widget.label == null) return toggle;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          toggle,
        ],
      ),
    );
  }
}
