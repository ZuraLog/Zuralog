/// Zuralog Design System — Unified Button Component.
///
/// Fully custom-painted button with brand pattern overlay support.
/// Does not rely on Material button styles — uses Container + GestureDetector
/// for complete control over appearance and pattern integration.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// Button visual style variants.
enum ZButtonVariant { primary, secondary, destructive, text }

/// Button size presets.
enum ZButtonSize {
  large(height: 52, hPadding: 28),
  medium(height: 44, hPadding: 24),
  small(height: 32, hPadding: 18);

  const ZButtonSize({required this.height, required this.hPadding});
  final double height;
  final double hPadding;
}

/// Unified button component for Zuralog.
///
/// Custom-painted with Container + GestureDetector for full control over
/// pattern overlays, pill radius, and press states.
///
/// Usage:
/// ```dart
/// ZButton(label: 'Save', onPressed: _save)
/// ZButton(label: 'Delete', onPressed: _delete, variant: ZButtonVariant.destructive)
/// ZButton(label: 'Cancel', onPressed: _cancel, variant: ZButtonVariant.text)
/// ZButton(label: 'Small', onPressed: _tap, size: ZButtonSize.small)
/// ```
class ZButton extends StatefulWidget {
  const ZButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ZButtonVariant.primary,
    this.size = ZButtonSize.large,
    this.isLoading = false,
    this.icon,
    this.leadingWidget,
    this.isFullWidth = true,
  });

  /// The button label text.
  final String label;

  /// Tap callback. Pass null to disable the button.
  final VoidCallback? onPressed;

  /// Visual style variant. Defaults to [ZButtonVariant.primary].
  final ZButtonVariant variant;

  /// Size preset. Defaults to [ZButtonSize.large].
  final ZButtonSize size;

  /// When true, shows a loading spinner and disables the button.
  final bool isLoading;

  /// Optional leading icon.
  final IconData? icon;

  /// Optional custom leading widget. Takes precedence over [icon] when both
  /// are provided. Use this for non-icon content like a styled text glyph.
  final Widget? leadingWidget;

  /// Whether the button expands to fill available width. Defaults to true.
  final bool isFullWidth;

  @override
  State<ZButton> createState() => _ZButtonState();
}

class _ZButtonState extends State<ZButton> {
  bool _isPressed = false;

  bool get _isDisabled => widget.onPressed == null || widget.isLoading;

  // ── Colors ──────────────────────────────────────────────────────────────

  Color _backgroundColor() {
    switch (widget.variant) {
      case ZButtonVariant.primary:
        return AppColors.primary;
      case ZButtonVariant.destructive:
        return AppColors.error;
      case ZButtonVariant.secondary:
      case ZButtonVariant.text:
        return Colors.transparent;
    }
  }

  Color _foregroundColor() {
    switch (widget.variant) {
      case ZButtonVariant.primary:
        return AppColors.textOnSage;
      case ZButtonVariant.destructive:
        return Colors.white;
      case ZButtonVariant.secondary:
        return AppColors.warmWhite;
      case ZButtonVariant.text:
        return AppColors.primary;
    }
  }

  Color _spinnerColor() {
    switch (widget.variant) {
      case ZButtonVariant.primary:
        return AppColors.textOnSage;
      case ZButtonVariant.text:
        return AppColors.primary;
      case ZButtonVariant.destructive:
        return Colors.white;
      case ZButtonVariant.secondary:
        return AppColors.warmWhite;
    }
  }

  // ── Pattern config ──────────────────────────────────────────────────────

  bool get _hasPattern =>
      !_isDisabled &&
      (widget.variant == ZButtonVariant.primary ||
          widget.variant == ZButtonVariant.destructive);

  ZPatternVariant get _patternVariant => widget.variant == ZButtonVariant.primary
      ? ZPatternVariant.sage
      : ZPatternVariant.crimson;

  // ── Border ──────────────────────────────────────────────────────────────

  BoxBorder? _border() {
    if (widget.variant == ZButtonVariant.secondary) {
      return Border.all(
        color: const Color(0x33F0EEE9), // rgba(240,238,233,0.2)
        width: 1.5,
      );
    }
    return null;
  }

  // ── Text style ─────────────────────────────────────────────────────────

  TextStyle _textStyle() {
    final baseStyle = widget.size == ZButtonSize.small
        ? AppTextStyles.labelMedium
        : AppTextStyles.labelLarge;

    final color = _foregroundColor();

    // Secondary and text variants use SemiBold 600 (which is already the
    // default for labelLarge/labelMedium), so no extra weight override needed.
    return baseStyle.copyWith(color: color);
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.size.height;
    final hPadding = widget.size.hPadding;
    final borderRadius = BorderRadius.circular(AppDimens.shapePill);
    final effectiveOpacity =
        _isDisabled ? 0.40 : (_isPressed ? 0.85 : 1.0);

    // ── Content ─────────────────────────────────────────────────────────
    Widget content;
    if (widget.isLoading) {
      content = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(_spinnerColor()),
        ),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.leadingWidget != null) ...[
            widget.leadingWidget!,
            const SizedBox(width: AppDimens.spaceSm),
          ] else if (widget.icon != null) ...[
            Icon(widget.icon, size: 18, color: _foregroundColor()),
            const SizedBox(width: AppDimens.spaceSm),
          ],
          Text(widget.label, style: _textStyle()),
        ],
      );
    }

    if (widget.isFullWidth) {
      content = Center(child: content);
    }

    // ── Button body ─────────────────────────────────────────────────────
    Widget button = ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          // Background container
          Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: hPadding),
            decoration: BoxDecoration(
              color: _backgroundColor(),
              borderRadius: borderRadius,
              border: _border(),
            ),
            alignment: widget.isFullWidth ? Alignment.center : null,
            child: content,
          ),
          // Pattern overlay (primary & destructive only, not when disabled)
          if (_hasPattern)
            Positioned.fill(
              child: ZPatternOverlay(
                variant: _patternVariant,
                opacity: 0.15,
                blendMode: BlendMode.colorBurn,
              ),
            ),
        ],
      ),
    );

    // Apply full width constraint
    if (widget.isFullWidth) {
      button = SizedBox(
        width: double.infinity,
        height: height,
        child: button,
      );
    }

    // ── Scale + opacity for press/disabled states ──────────────────────
    button = AnimatedScale(
      duration: AppMotion.durationFast,
      curve: AppMotion.curveEntrance,
      scale: _isPressed ? 0.95 : 1.0,
      child: AnimatedOpacity(
        duration: AppMotion.durationFast,
        opacity: effectiveOpacity,
        child: button,
      ),
    );

    // ── Gesture handling ────────────────────────────────────────────────
    return Semantics(
      button: true,
      enabled: !_isDisabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _isDisabled ? null : (_) => setState(() => _isPressed = true),
        onTapUp: _isDisabled
            ? null
            : (_) {
                setState(() => _isPressed = false);
                widget.onPressed?.call();
              },
        onTapCancel:
            _isDisabled ? null : () => setState(() => _isPressed = false),
        behavior: HitTestBehavior.opaque,
        child: button,
      ),
    );
  }
}
