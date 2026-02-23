/// Zuralog Edge Agent — Chat Input Bar Widget.
///
/// A frosted-glass input bar that floats at the bottom of the Coach Chat
/// screen. Provides a pill-shaped text field with an attachment button on
/// the left and a context-sensitive icon on the right: microphone when the
/// field is empty, filled send button when text is present.
///
/// Visual design:
/// - [BackdropFilter] with [ImageFilter.blur] for frosted-glass effect.
/// - Background color with [AppDimens.navBarFrostOpacity] opacity.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

// ── Chat Input Bar ────────────────────────────────────────────────────────────

/// A frosted-glass chat input bar with attachment, text field, and send/mic.
///
/// [onSend] is called with the trimmed message text when the user taps Send.
/// The bar uses [resizeToAvoidBottomInset] safe area to stay above the
/// keyboard — the parent [Scaffold] must set `resizeToAvoidBottomInset: true`.
class ChatInputBar extends StatefulWidget {
  /// Callback invoked when the user submits a message.
  ///
  /// [text] is the trimmed, non-empty message string.
  final void Function(String text) onSend;

  /// Creates a [ChatInputBar].
  ///
  /// [onSend] must not be null.
  const ChatInputBar({super.key, required this.onSend});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  /// Controller for the text input field.
  final TextEditingController _controller = TextEditingController();

  /// Whether the text field currently has content.
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Listener that updates [_hasText] whenever the field content changes.
  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  /// Submits the current text via [widget.onSend] and clears the field.
  ///
  /// Does nothing if the field is empty.
  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final frostedBg = isDark
        ? AppColors.backgroundDark.withValues(alpha: AppDimens.navBarFrostOpacity)
        : AppColors.backgroundLight.withValues(alpha: AppDimens.navBarFrostOpacity);
    final fieldColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppDimens.navBarBlurSigma,
          sigmaY: AppDimens.navBarBlurSigma,
        ),
        child: Container(
          color: frostedBg,
          padding: EdgeInsets.only(
            left: AppDimens.spaceMd,
            right: AppDimens.spaceMd,
            top: AppDimens.spaceSm,
            bottom: AppDimens.spaceSm +
                MediaQuery.of(context).padding.bottom,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── Attach button ──────────────────────────────────────────
              _AttachButton(onTap: () => _showAttachmentSnackBar(context)),

              const SizedBox(width: AppDimens.spaceSm),

              // ── Pill-shaped text field ─────────────────────────────────
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: fieldColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    style: AppTextStyles.body.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Message your coach…',
                      hintStyle: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                        vertical: AppDimens.spaceSm + 2,
                      ),
                      filled: false,
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
              ),

              const SizedBox(width: AppDimens.spaceSm),

              // ── Send / Mic icon ────────────────────────────────────────
              _SendOrMicButton(
                hasText: _hasText,
                onSend: _handleSend,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows an informational SnackBar when the user taps the attach button.
  void _showAttachmentSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File attachments coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// The attach icon button at the left of the input bar.
///
/// [onTap] is called when the user taps the button.
class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.onTap});

  /// Called when the user taps the attach button.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.attach_file_rounded),
      color: AppColors.textSecondary,
      iconSize: AppDimens.iconMd,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: AppDimens.touchTargetMin,
        minHeight: AppDimens.touchTargetMin,
      ),
      tooltip: 'Attach file',
    );
  }
}

/// The send / mic button at the right of the input bar.
///
/// Shows a mic icon when [hasText] is false, and a filled send icon
/// (colored [AppColors.primary]) when [hasText] is true.
class _SendOrMicButton extends StatelessWidget {
  const _SendOrMicButton({required this.hasText, required this.onSend});

  /// Whether the text field currently has content.
  final bool hasText;

  /// Called when the user taps the send button.
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: hasText
          ? IconButton(
              key: const ValueKey('send'),
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
              color: AppColors.primary,
              iconSize: AppDimens.iconMd,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: AppDimens.touchTargetMin,
                minHeight: AppDimens.touchTargetMin,
              ),
              tooltip: 'Send message',
            )
          : IconButton(
              key: const ValueKey('mic'),
              onPressed: null, // Mic is decorative for now.
              icon: const Icon(Icons.mic_none_rounded),
              color: AppColors.textSecondary,
              iconSize: AppDimens.iconMd,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: AppDimens.touchTargetMin,
                minHeight: AppDimens.touchTargetMin,
              ),
              tooltip: 'Voice input coming soon',
            ),
    );
  }
}
