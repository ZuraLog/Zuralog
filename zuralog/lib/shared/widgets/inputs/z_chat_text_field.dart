/// Zuralog Design System — Chat-Style Text Field.
///
/// Dark pill-shaped single-line input with a trailing filled send button.
/// Visually matches the existing onboarding text input so catch-up flows
/// and settings editors feel native to the conversational surface.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// A pill-shaped chat input with a sage-circle send button.
class ZChatTextField extends StatefulWidget {
  const ZChatTextField({
    super.key,
    this.maxLength = 120,
    this.placeholder,
    required this.onSubmit,
    this.autofocus = false,
    this.allowEmptySubmit = false,
  });

  final int maxLength;
  final String? placeholder;
  final ValueChanged<String> onSubmit;
  final bool autofocus;

  /// When true, the send button stays enabled even when the field is empty —
  /// tapping it submits an empty string. Used for "send to skip" cases.
  final bool allowEmptySubmit;

  @override
  State<ZChatTextField> createState() => _ZChatTextFieldState();
}

class _ZChatTextFieldState extends State<ZChatTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  static const double _fieldHeight = 48;
  static const double _sendButtonSize = 36;
  static const Duration _fadeDuration = Duration(milliseconds: 220);

  // Full dark theme so the nested Material reads dark tokens correctly
  // (flipping brightness at the parent isn't enough — the TextField's
  // Material reads colorScheme.surface directly).
  static final ThemeData _darkFieldTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surface,
      onSurface: AppColors.warmWhite,
      primary: AppColors.primary,
      onPrimary: Color(0xFF1A2E22),
    ),
    scaffoldBackgroundColor: AppColors.surface,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: Color(0x33CFE1B9),
      selectionHandleColor: AppColors.primary,
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _hasText => _controller.text.trim().isNotEmpty;
  bool get _canSend => widget.allowEmptySubmit || _hasText;

  void _submit() {
    if (!_canSend) return;
    final value = _controller.text.trim();
    HapticFeedback.mediumImpact();
    widget.onSubmit(value);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _darkFieldTheme,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_fieldHeight / 2),
        clipBehavior: Clip.antiAlias,
        child: Container(
          height: _fieldHeight,
          padding: const EdgeInsets.only(left: 18, right: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(_fieldHeight / 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLength: widget.maxLength,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  cursorColor: AppColors.primary,
                  keyboardAppearance: Brightness.dark,
                  autofillHints: const <String>[],
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(widget.maxLength),
                  ],
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.warmWhite,
                    letterSpacing: -0.1,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.placeholder,
                    hintStyle: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondaryDark,
                      letterSpacing: -0.1,
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              AnimatedOpacity(
                duration: _fadeDuration,
                curve: Curves.easeOut,
                opacity: _canSend ? 1.0 : 0.35,
                child: AnimatedScale(
                  duration: _fadeDuration,
                  curve: Curves.easeOutBack,
                  scale: _canSend ? 1.0 : 0.85,
                  child: GestureDetector(
                    onTap: _canSend ? _submit : null,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: _sendButtonSize,
                      height: _sendButtonSize,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.all(AppDimens.spaceXs),
                      decoration: BoxDecoration(
                        color: _canSend
                            ? AppColors.primary
                            : AppColors.surfaceRaised,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        size: 20,
                        color: _canSend
                            ? const Color(0xFF1A2E22)
                            : AppColors.textSecondaryDark,
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
