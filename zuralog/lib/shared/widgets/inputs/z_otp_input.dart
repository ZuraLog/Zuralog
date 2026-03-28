/// Zuralog Design System — OTP/PIN Input Component.
///
/// A 6-slot (configurable) one-time password input with auto-advance,
/// paste support, and error state styling.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A one-time password input with individual character slots.
///
/// Renders [length] boxes (default 6) that each hold a single character.
/// Focus auto-advances as the user types, and pasting a full code fills
/// all slots at once. When every slot is filled, [onCompleted] fires.
///
/// ## Error state
/// Set [hasError] to `true` to show a red border on all slots — useful
/// when the server rejects the code.
///
/// ## Disabled state
/// Set [enabled] to `false` to dim the input and block interaction.
///
/// Example usage:
/// ```dart
/// ZOtpInput(
///   onCompleted: (code) => verifyOtp(code),
///   onChanged: (partial) => clearError(),
///   hasError: _otpRejected,
/// )
/// ```
class ZOtpInput extends StatefulWidget {
  /// Creates a [ZOtpInput].
  const ZOtpInput({
    super.key,
    this.length = 6,
    this.onCompleted,
    this.onChanged,
    this.hasError = false,
    this.enabled = true,
  }) : assert(length > 0, 'OTP length must be greater than zero');

  /// Number of character slots to display.
  final int length;

  /// Called when every slot has been filled.
  final ValueChanged<String>? onCompleted;

  /// Called on every keystroke with the current partial value.
  final ValueChanged<String>? onChanged;

  /// When `true`, all slots show a red error border.
  final bool hasError;

  /// When `false`, the input is dimmed and ignores interaction.
  final bool enabled;

  @override
  State<ZOtpInput> createState() => _ZOtpInputState();
}

class _ZOtpInputState extends State<ZOtpInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  /// Guards against firing [onCompleted] more than once per full entry.
  bool _hasCompleted = false;

  /// Slot dimensions from the brand bible spec.
  static const double _slotWidth = 48;
  static const double _slotHeight = 56;
  static const double _fontSize = 20;
  static const double _borderWidth = 2;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);

    // Auto-focus the hidden field when the widget first appears.
    if (widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(ZOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If re-enabled, grab focus again.
    if (widget.enabled && !oldWidget.enabled) {
      _focusNode.requestFocus();
    }
    // If disabled, release focus immediately.
    if (!widget.enabled && oldWidget.enabled) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Callbacks ───────────────────────────────────────────────────────────

  void _onTextChanged() {
    final text = _controller.text;
    widget.onChanged?.call(text);

    if (text.length < widget.length) {
      // Reset the guard whenever the user deletes a character.
      _hasCompleted = false;
    } else if (!_hasCompleted) {
      // Fire onCompleted exactly once per complete entry.
      _hasCompleted = true;
      widget.onCompleted?.call(text);
    }

    // Trigger a rebuild so the visual slots update.
    setState(() {});
  }

  /// Tapping any slot re-focuses the hidden field and moves the cursor to
  /// the right position (i.e. the end of current text or the tapped slot).
  void _onSlotTapped(int index) {
    if (!widget.enabled) return;
    _focusNode.requestFocus();

    // Move the selection to the end — we always append from the last
    // filled position so the user experience stays predictable.
    final text = _controller.text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Semantics(
      label: 'One-time password input',
      child: Opacity(
        opacity: widget.enabled ? 1.0 : 0.4,
        child: AbsorbPointer(
          absorbing: !widget.enabled,
          child: Stack(
            children: [
              // ── Visual slots row ─────────────────────────────────────
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.length, (i) {
                  final isSeparator = i > 0;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSeparator)
                        const SizedBox(width: AppDimens.spaceSm),
                      _Slot(
                        index: i,
                        char: i < _controller.text.length
                            ? _controller.text[i]
                            : null,
                        isFocused: _focusNode.hasFocus &&
                            i == _controller.text.length &&
                            _controller.text.length < widget.length,
                        hasError: widget.hasError,
                        colors: colors,
                        onTap: () => _onSlotTapped(i),
                      ),
                    ],
                  );
                }),
              ),

              // ── Hidden TextField that drives keyboard input ──────────
              // IgnorePointer blocks OS paste popups from intercepting
              // touches through the invisible overlay.
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: 0,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        maxLength: widget.length,
                        enableSuggestions: false,
                        autocorrect: false,
                        showCursor: false,
                        onSubmitted: (_) => _focusNode.unfocus(),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                          LengthLimitingTextInputFormatter(widget.length),
                        ],
                        style: const TextStyle(
                          color: Colors.transparent,
                          height: 0.01,
                          fontSize: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Individual slot widget ─────────────────────────────────────────────────

class _Slot extends StatelessWidget {
  const _Slot({
    required this.index,
    required this.char,
    required this.isFocused,
    required this.hasError,
    required this.colors,
    required this.onTap,
  });

  final int index;
  final String? char;
  final bool isFocused;
  final bool hasError;
  final AppColorsOf colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Border logic: error > focused > none.
    final BorderSide borderSide;
    if (hasError) {
      borderSide = const BorderSide(
        color: AppColors.statusError,
        width: _ZOtpInputState._borderWidth,
      );
    } else if (isFocused) {
      borderSide = BorderSide(
        // Sage at 30% opacity per spec.
        color: colors.primary.withValues(alpha: 0.3),
        width: _ZOtpInputState._borderWidth,
      );
    } else {
      borderSide = BorderSide.none;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.durationFast,
        curve: AppMotion.curveTransition,
        width: _ZOtpInputState._slotWidth,
        height: _ZOtpInputState._slotHeight,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.shapeSm),
          border: Border.fromBorderSide(borderSide),
        ),
        alignment: Alignment.center,
        child: char != null
            ? Text(
                char!,
                style: TextStyle(
                  fontSize: _ZOtpInputState._fontSize,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              )
            : isFocused
                ? _BlinkingCursor(color: colors.primary)
                : const SizedBox.shrink(),
      ),
    );
  }
}

// ── Blinking underscore cursor ─────────────────────────────────────────────

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor({required this.color});

  final Color color;

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _anim
        ..stop()
        ..value = 1.0;
    } else if (!_anim.isAnimating) {
      _anim.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 20,
        height: 2,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
