/// Zuralog — Onboarding Text Input.
///
/// A premium chat-style text field that sits at the bottom of the
/// [ChatOnboardingScreen]. One-line only — when the user submits, the
/// field clears and the parent advances the conversation.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class OnboardingTextInput extends StatefulWidget {
  const OnboardingTextInput({
    super.key,
    required this.hint,
    required this.onSubmit,
    this.minChars = 1,
    this.textCapitalization = TextCapitalization.words,
  });

  /// Placeholder shown when the field is empty.
  final String hint;

  /// Called with the trimmed value once the user presses send.
  final ValueChanged<String> onSubmit;

  /// Minimum number of characters required before send is enabled.
  final int minChars;

  final TextCapitalization textCapitalization;

  @override
  State<OnboardingTextInput> createState() => _OnboardingTextInputState();
}

class _OnboardingTextInputState extends State<OnboardingTextInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  static const double _fieldHeight = 48;
  static const double _sendButtonSize = 36;
  static const Duration _sendFadeDuration = Duration(milliseconds: 220);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    // Autofocus after the first frame so the keyboard glides up with
    // the chat already on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSend =>
      _controller.text.trim().length >= widget.minChars;

  void _submit() {
    if (!_canSend) return;
    final value = _controller.text.trim();
    HapticFeedback.mediumImpact();
    widget.onSubmit(value);
    _controller.clear();
  }

  // Full dark ColorScheme so the TextField's internal Material + cursor
  // + selection all read brand-dark regardless of system theme. Just
  // flipping Theme.brightness at the parent ISN'T enough — the Material
  // inside TextField reads colorScheme.surface directly.
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
    inputDecorationTheme: const InputDecorationTheme(
      filled: false,
      border: InputBorder.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Wrap the field in a proper dark Theme so nested Material widgets
    // read dark tokens from the colorScheme. Also disable iOS autofill
    // suggestion overlays (which render a light pill on top of the field
    // and look out of place on our dark canvas).
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
              textCapitalization: widget.textCapitalization,
              textInputAction: TextInputAction.send,
              cursorColor: AppColors.primary,
              keyboardAppearance: Brightness.dark,
              autofillHints: const <String>[],
              autocorrect: false,
              enableSuggestions: false,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.warmWhite,
                letterSpacing: -0.1,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondaryDark,
                  letterSpacing: -0.1,
                ),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
          ),
          AnimatedOpacity(
            duration: _sendFadeDuration,
            curve: Curves.easeOut,
            opacity: _canSend ? 1.0 : 0.35,
            child: AnimatedScale(
              duration: _sendFadeDuration,
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
