/// Zuralog Design System — Toggle Switch Component.
///
/// Custom-painted toggle with Sage track pattern overlay when active.
/// Does not use Material Switch — fully brand-aligned.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart'
    show ZPatternVariant, effectivePatternVariant, effectivePatternOpacity;

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
    HapticFeedback.lightImpact();
    widget.onChanged!(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Track visual, wrapped in a 48px tap target.
    final trackVisual = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final patternImage = effectivePatternVariant(ZPatternVariant.sage, isLight).assetPath;
        final patternOpacity = effectivePatternOpacity(1.0, isLight);
        return SizedBox(
          width: _trackWidth,
          height: _trackHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            child: Stack(
              children: [
                // Base track — surfaceRaised color always present underneath.
                Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(_trackHeight / 2),
                  ),
                ),
                // Pattern layer fades in on top when ON.
                if (_controller.value > 0.0)
                  Opacity(
                    opacity: _controller.value * patternOpacity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_trackHeight / 2),
                        image: DecorationImage(
                          image: AssetImage(patternImage),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                // Thumb.
                Positioned(
                  left: _position.value,
                  top: _thumbPadding,
                  child: Container(
                    width: _thumbDiameter,
                    height: _thumbDiameter,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // 48×48 tap target with track centered inside.
    final tapTarget = SizedBox(
      width: 48,
      height: 48,
      child: Center(child: trackVisual),
    );

    final toggle = Semantics(
      toggled: widget.value,
      label: widget.label ?? 'Toggle',
      enabled: widget.enabled,
      child: IgnorePointer(
        ignoring: widget.onChanged == null,
        child: Opacity(
          opacity: widget.onChanged != null
              ? 1.0
              : AppDimens.disabledOpacity,
          child: GestureDetector(
            onTap: _handleTap,
            child: tapTarget,
          ),
        ),
      ),
    );

    if (widget.label == null) return toggle;

    // When a label is present, the single outer GestureDetector in the
    // Semantics subtree covers the whole row — no second GestureDetector.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label!,
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        toggle,
      ],
    );
  }
}
