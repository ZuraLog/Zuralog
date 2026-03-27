/// Zuralog Design System — Toast Component.
///
/// Overlay-based toast notifications with status dot, auto-dismiss,
/// and slide-from-top animation. Does not depend on ScaffoldMessenger.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// Visual variant that controls the status dot color.
enum ZToastVariant {
  success(AppColors.success),
  error(AppColors.error),
  warning(AppColors.warning),
  info(AppColors.syncing);

  const ZToastVariant(this.dotColor);

  /// The color used for the leading status dot.
  final Color dotColor;
}

/// An overlay-based toast that appears at the top of the screen.
///
/// Use the static convenience methods ([ZToast.success], [ZToast.error],
/// etc.) to show a toast without dealing with overlay management.
///
/// The toast slides in from the top over 350ms (easeOut), stays visible
/// for 3.5 seconds, then slides out over 250ms (easeIn).
class ZToast {
  ZToast._();

  /// Shows a success toast with a green status dot.
  static void success(BuildContext context, String message, {String? action, VoidCallback? onAction}) {
    _show(context, message, ZToastVariant.success, action: action, onAction: onAction);
  }

  /// Shows an error toast with a red status dot.
  static void error(BuildContext context, String message, {String? action, VoidCallback? onAction}) {
    _show(context, message, ZToastVariant.error, action: action, onAction: onAction);
  }

  /// Shows a warning toast with an amber status dot.
  static void warning(BuildContext context, String message, {String? action, VoidCallback? onAction}) {
    _show(context, message, ZToastVariant.warning, action: action, onAction: onAction);
  }

  /// Shows an info toast with a blue status dot.
  static void info(BuildContext context, String message, {String? action, VoidCallback? onAction}) {
    _show(context, message, ZToastVariant.info, action: action, onAction: onAction);
  }

  static void _show(
    BuildContext context,
    String message,
    ZToastVariant variant, {
    String? action,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _ZToastOverlay(
        message: message,
        variant: variant,
        action: action,
        onAction: onAction,
        onDismissed: () {
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

// ── Private overlay widget ──────────────────────────────────────────────────

class _ZToastOverlay extends StatefulWidget {
  const _ZToastOverlay({
    required this.message,
    required this.variant,
    required this.onDismissed,
    this.action,
    this.onAction,
  });

  final String message;
  final ZToastVariant variant;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback onDismissed;

  @override
  State<_ZToastOverlay> createState() => _ZToastOverlayState();
}

class _ZToastOverlayState extends State<_ZToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideIn;
  late final Animation<Offset> _slideOut;
  late final Animation<double> _fadeIn;
  late final Animation<double> _fadeOut;

  static const _enterDuration = Duration(milliseconds: 350);
  static const _exitDuration = Duration(milliseconds: 250);
  static const _displayDuration = Duration(milliseconds: 3500);

  /// Total animation length = enter + display + exit.
  Duration get _totalDuration => Duration(
        milliseconds:
            _enterDuration.inMilliseconds +
            _displayDuration.inMilliseconds +
            _exitDuration.inMilliseconds,
      );

  /// Fraction of the total time spent entering.
  double get _enterFraction =>
      _enterDuration.inMilliseconds / _totalDuration.inMilliseconds;

  /// Fraction at which the exit begins.
  double get _exitStart =>
      1.0 -
      (_exitDuration.inMilliseconds / _totalDuration.inMilliseconds);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onDismissed();
        }
      });

    // Slide & fade in during the first fraction.
    _slideIn = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0, _enterFraction, curve: Curves.easeOut),
    ));

    _fadeIn = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0, _enterFraction, curve: Curves.easeOut),
    ));

    // Slide & fade out during the last fraction.
    _slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(_exitStart, 1, curve: Curves.easeIn),
    ));

    _fadeOut = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(_exitStart, 1, curve: Curves.easeIn),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + AppDimens.spaceSm;

    return Positioned(
      top: topPadding,
      left: AppDimens.spaceMd,
      right: AppDimens.spaceMd,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // During enter phase, use slideIn/fadeIn. During exit, use
          // slideOut/fadeOut. In between they both resolve to identity.
          final offset = _controller.value <= _enterFraction + 0.01
              ? _slideIn.value
              : _slideOut.value;
          final opacity = _controller.value <= _enterFraction + 0.01
              ? _fadeIn.value
              : _fadeOut.value;

          return FractionalTranslation(
            translation: offset,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: _buildToast(context),
      ),
    );
  }

  Widget _buildToast(BuildContext context) {
    final colors = AppColorsOf(context);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppDimens.shapePill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status dot.
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.variant.dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            // Message.
            Flexible(
              child: Text(
                widget.message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Optional action.
            if (widget.action != null) ...[
              const SizedBox(width: AppDimens.spaceSm),
              GestureDetector(
                onTap: widget.onAction,
                child: Text(
                  widget.action!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Workaround: Flutter's [AnimatedBuilder] is the modern name for
/// [AnimatedWidget]-style builders. We use the standard approach here.
/// Note: In Flutter 3.x+, AnimatedBuilder is available directly.
