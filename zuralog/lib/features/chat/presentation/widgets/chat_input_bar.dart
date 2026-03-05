/// Zuralog Edge Agent — Chat Input Bar Widget.
///
/// A frosted-glass input bar that floats at the bottom of the Coach Chat
/// screen. Provides a pill-shaped text field with an attachment button on
/// the left and a context-sensitive icon on the right: hold-to-talk mic
/// when the field is empty, filled send button when text (or attachments)
/// is present.
///
/// Supports queuing image and voice note attachments via a bottom sheet
/// picker. Pending attachments are shown in a preview strip above the
/// text field. The mic button provides on-device speech-to-text dictation.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/chat/domain/attachment.dart';
import 'package:zuralog/features/chat/presentation/widgets/attachment_picker_sheet.dart';
import 'package:zuralog/features/chat/presentation/widgets/attachment_preview_strip.dart';
import 'package:zuralog/features/chat/presentation/widgets/voice_recorder.dart';

// ── Chat Input Bar ────────────────────────────────────────────────────────────

/// A frosted-glass chat input bar with attachment, text field, and send/mic.
///
/// [onSend] is called with the trimmed message text when the user taps Send
/// and there are no pending attachments.
/// [onSendWithAttachments] is called with the text and attachment list when
/// the user sends a message that has queued attachments.
/// Hold-to-talk on the mic button triggers on-device speech-to-text via
/// [onVoiceStart], [onVoiceStop], and [onVoiceCancel].
class ChatInputBar extends StatefulWidget {
  /// Callback invoked when the user submits a text-only message.
  final void Function(String text) onSend;

  /// Callback invoked when the user submits a message with attachments.
  final void Function(String text, List<ChatAttachment> attachments)?
      onSendWithAttachments;

  /// Callback invoked when the user starts a hold-to-talk gesture.
  final VoidCallback? onVoiceStart;

  /// Callback invoked when the user releases the hold-to-talk gesture.
  final VoidCallback? onVoiceStop;

  /// Callback invoked when the user cancels voice input (drag away).
  final VoidCallback? onVoiceCancel;

  /// Whether the speech recognizer is currently listening.
  final bool isListening;

  /// The current recognized text during a listening session.
  final String recognizedText;

  /// Microphone sound level (0.0 to 1.0) for visual feedback.
  final double soundLevel;

  /// Creates a [ChatInputBar].
  const ChatInputBar({
    super.key,
    required this.onSend,
    this.onSendWithAttachments,
    this.onVoiceStart,
    this.onVoiceStop,
    this.onVoiceCancel,
    this.isListening = false,
    this.recognizedText = '',
    this.soundLevel = 0.0,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _hasText = false;
  bool _isRecording = false;
  final List<ChatAttachment> _pendingAttachments = [];

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

  @override
  void didUpdateWidget(ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When STT listening stops and we have final text, insert it into the field.
    if (oldWidget.isListening && !widget.isListening) {
      final text = widget.recognizedText.trim();
      if (text.isNotEmpty) {
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: text.length);
      }
    }
  }

  /// Submits the current text (and any pending attachments) then clears state.
  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    if (_pendingAttachments.isNotEmpty) {
      widget.onSendWithAttachments?.call(text, List.of(_pendingAttachments));
    } else {
      widget.onSend(text);
    }

    _controller.clear();
    setState(() => _pendingAttachments.clear());
  }

  /// Shows the attachment picker bottom sheet and handles the result.
  Future<void> _handleAttachTap() async {
    final result = await showAttachmentPicker(context);
    if (result == null || !mounted) return;

    switch (result) {
      case AttachmentPickerResult.camera:
        await _pickImage(ImageSource.camera);
      case AttachmentPickerResult.gallery:
        await _pickImage(ImageSource.gallery);
      case AttachmentPickerResult.voiceNote:
        setState(() => _isRecording = true);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() {
        _pendingAttachments.add(
          ChatAttachment(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: AttachmentType.image,
            filename: picked.name,
            localPath: picked.path,
          ),
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access photos'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onRecordingComplete(String filePath) {
    setState(() {
      _isRecording = false;
      _pendingAttachments.add(
        ChatAttachment(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          type: AttachmentType.audio,
          filename: 'voice_note.m4a',
          localPath: filePath,
        ),
      );
    });
  }

  void _onRecordingCancel() {
    setState(() => _isRecording = false);
  }

  void _removeAttachment(int index) {
    setState(() => _pendingAttachments.removeAt(index));
  }

  bool get _canSend => _hasText || _pendingAttachments.isNotEmpty;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Attachment preview strip ─────────────────────────────
              if (_pendingAttachments.isNotEmpty)
                AttachmentPreviewStrip(
                  attachments: _pendingAttachments,
                  onRemove: _removeAttachment,
                ),

              // ── Recording bar OR normal input ───────────────────────
              if (_isRecording)
                VoiceRecorder(
                  onComplete: _onRecordingComplete,
                  onCancel: _onRecordingCancel,
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // ── Attach button ──────────────────────────────────
                    _AttachButton(onTap: _handleAttachTap),

                    const SizedBox(width: AppDimens.spaceSm),

                    // ── Pill-shaped text field ─────────────────────────
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
                            hintText: 'Message your coach\u2026',
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

                    // ── Send / Mic icon ────────────────────────────────
                    _SendOrMicButton(
                      hasContent: _canSend,
                      onSend: _handleSend,
                      onVoiceStart: widget.onVoiceStart,
                      onVoiceStop: widget.onVoiceStop,
                      onVoiceCancel: widget.onVoiceCancel,
                      isListening: widget.isListening,
                      soundLevel: widget.soundLevel,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// The attach icon button at the left of the input bar.
class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.onTap});

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
/// Shows a send icon when content is present (text or attachments).
/// Shows a hold-to-talk mic button when empty, with animated visual
/// feedback while listening for speech-to-text dictation.
class _SendOrMicButton extends StatelessWidget {
  const _SendOrMicButton({
    required this.hasContent,
    required this.onSend,
    this.onVoiceStart,
    this.onVoiceStop,
    this.onVoiceCancel,
    this.isListening = false,
    this.soundLevel = 0.0,
  });

  final bool hasContent;
  final VoidCallback onSend;
  final VoidCallback? onVoiceStart;
  final VoidCallback? onVoiceStop;
  final VoidCallback? onVoiceCancel;
  final bool isListening;
  final double soundLevel;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: hasContent
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
          : Tooltip(
              message: 'Hold for voice input',
              child: GestureDetector(
                key: const ValueKey('mic'),
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (_) => onVoiceStart?.call(),
                onLongPressEnd: (_) => onVoiceStop?.call(),
                onLongPressCancel: () => onVoiceCancel?.call(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: AppDimens.touchTargetMin,
                  height: AppDimens.touchTargetMin,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isListening
                        ? AppColors.primary.withValues(
                            alpha: 0.15 + (soundLevel * 0.25),
                          )
                        : Colors.transparent,
                  ),
                  child: Icon(
                    isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: isListening
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: AppDimens.iconMd,
                  ),
                ),
              ),
            ),
    );
  }
}
