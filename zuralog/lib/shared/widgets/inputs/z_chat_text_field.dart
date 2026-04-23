/// Zuralog Design System — Chat-Style Text Field.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A rounded chat-style text field with a trailing send button.
///
/// Used in the onboarding chat and catch-up flow for free-text answers
/// (e.g. "Biggest frustration"). Submits on the send button or enter key.
/// Empty submissions are no-ops.
class ZChatTextField extends StatefulWidget {
  const ZChatTextField({
    super.key,
    this.maxLength = 120,
    this.placeholder,
    required this.onSubmit,
    this.autofocus = false,
  });

  final int maxLength;
  final String? placeholder;
  final ValueChanged<String> onSubmit;
  final bool autofocus;

  @override
  State<ZChatTextField> createState() => _ZChatTextFieldState();
}

class _ZChatTextFieldState extends State<ZChatTextField> {
  late final TextEditingController _controller;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChange() {
    final next = _controller.text.trim().isNotEmpty;
    if (next != _canSubmit) setState(() => _canSubmit = next);
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapePill),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              maxLength: widget.maxLength,
              textInputAction: TextInputAction.send,
              inputFormatters: [
                LengthLimitingTextInputFormatter(widget.maxLength),
              ],
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
                border: InputBorder.none,
                counterText: '',
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
              onSubmitted: (_) => _submit(),
            ),
          ),
          IconButton(
            tooltip: 'Send',
            icon: Icon(
              Icons.arrow_upward_rounded,
              color: _canSubmit ? colors.primary : colors.textSecondary,
            ),
            onPressed: _canSubmit
                ? () {
                    HapticFeedback.selectionClick();
                    _submit();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
