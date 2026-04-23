/// Shared input bar for coach chat screens.
///
/// Used by both [NewChatScreen] (no conversation ID yet, deferred upload) and
/// [ChatThreadScreen] (live conversation, immediate upload).
///
/// The two screens have slightly different send semantics:
///
/// **Deferred mode** — [conversationId] is null.
///   [onSend] receives `rawAttachments` (path + name maps) so the caller can
///   upload once the server assigns a real UUID.
///
/// **Live mode** — [conversationId] is non-null.
///   Attachments are uploaded here before [onSend] is called.
///   The stop-generation button is shown when [isSending] is true.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/speech/speech_providers.dart';
import 'package:zuralog/core/speech/speech_state.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_attachment_panel.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';

// ── CoachInputBar ─────────────────────────────────────────────────────────────

class CoachInputBar extends ConsumerStatefulWidget {
  const CoachInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.conversationId,
    this.isSending = false,
    this.attachmentCountNotifier,
    this.stagedAttachmentsNotifier,
    this.placeholder = 'Message Zura…',
    this.isFloating = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Called when the user taps Send.
  ///
  /// In **live mode** ([conversationId] is non-null): [attachments] contains
  /// fully-uploaded attachment payloads ready for the message API.
  ///
  /// In **deferred mode** ([conversationId] is null): [rawAttachments] contains
  /// raw local file info (path + name) so the caller can upload after the
  /// server assigns a real UUID.
  final void Function({
    List<Map<String, dynamic>> attachments,
    List<Map<String, String>> rawAttachments,
  }) onSend;

  /// When non-null, the widget operates in live mode: attachments are uploaded
  /// immediately and the stop button is available.
  final String? conversationId;

  /// When true the send button is replaced by a stop button.
  /// Only relevant in live mode ([conversationId] != null).
  final bool isSending;

  /// When provided, updated with the current number of staged attachments
  /// after every add/remove so the parent can warn before quick actions.
  final ValueNotifier<int>? attachmentCountNotifier;

  /// When provided, updated with the current staged attachments list
  /// after every add/remove so a parent can render previews externally.
  final ValueNotifier<List<PendingAttachment>>? stagedAttachmentsNotifier;

  /// The hint text shown inside the text field when it is empty.
  ///
  /// Defaults to `'Message Zura…'`.
  final String placeholder;

  /// When true, the input bar renders without a top border or background color
  /// so it can be wrapped inside a [_FrostedInputPill] that provides its own
  /// frosted-glass decoration.
  ///
  /// Bottom padding is reduced to [AppDimens.spaceSm] (the pill handles
  /// its own vertical positioning). Defaults to false.
  final bool isFloating;

  /// Maximum allowed message length.
  static const int maxLength = 4000;

  @override
  ConsumerState<CoachInputBar> createState() => CoachInputBarState();
}

class CoachInputBarState extends ConsumerState<CoachInputBar> {
  final List<PendingAttachment> _attachments = [];

  void _updateAttachmentCount() {
    widget.attachmentCountNotifier?.value = _attachments.length;
  }

  /// Clears all staged attachments and resets the count notifier.
  ///
  /// Called by [NewChatScreenState] after a quick action is triggered so
  /// attachments are not silently dropped.
  void clearAttachments() {
    setState(() {
      _attachments.clear();
      _updateAttachmentCount();
      widget.stagedAttachmentsNotifier?.value = List.unmodifiable(_attachments);
    });
  }

  /// Removes the staged attachment at [index] and syncs notifiers.
  void removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
      _updateAttachmentCount();
      widget.stagedAttachmentsNotifier?.value =
          List.unmodifiable(_attachments);
    });
  }

  Future<void> _handleSend() async {
    try {
      final text = widget.controller.text.trim();
      if (text.isEmpty && _attachments.isEmpty) return;
      if (widget.isSending) return;

      final conversationId = widget.conversationId;

      if (conversationId == null) {
        // Deferred mode — no real conversation ID yet, so we can't hit the
        // upload endpoint. Encode images inline as base64 data URIs here so
        // the WebSocket payload still carries the actual image bytes for the
        // vision LLM. Non-image files fall back to the legacy raw-path
        // handoff so NewChatScreen can upload them after the conversation is
        // created.
        final attachmentPayloads = <Map<String, dynamic>>[];
        final rawAttachments = <Map<String, String>>[];
        for (final a in _attachments) {
          if (a.type == AttachmentType.image) {
            try {
              final bytes = await a.file.readAsBytes();
              final mime = lookupMimeType(a.file.path) ?? 'image/jpeg';
              final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
              attachmentPayloads.add({
                'type': 'image',
                'filename': a.name,
                'data_url': dataUrl,
                'size_bytes': bytes.length,
                'mime_type': mime,
              });
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to read ${a.name}. Please try again.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          } else {
            rawAttachments.add({'path': a.file.path, 'name': a.name});
          }
        }

        setState(() {
          _attachments.clear();
          _updateAttachmentCount();
          widget.stagedAttachmentsNotifier?.value = List.unmodifiable(_attachments);
        });
        widget.onSend(
          rawAttachments: rawAttachments,
          attachments: attachmentPayloads,
        );
        return;
      }

      // Live mode — upload attachments before sending.
      final List<Map<String, dynamic>> attachmentPayloads = [];
      if (_attachments.isNotEmpty) {
        // Resolve the real conversation UUID — must not be a temp "new_" ID.
        final notifierState = ref.read(
          coachChatNotifierProvider(conversationId),
        );
        final resolvedConvId = notifierState.resolvedConversationId;

        if (resolvedConvId == null || resolvedConvId.startsWith('new_')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Attachments cannot be uploaded yet — please wait for the conversation to start.',
                ),
              ),
            );
          }
          return;
        }

        final attachmentRepo = ref.read(attachmentRepositoryProvider);
        for (final a in _attachments) {
          try {
            final uploaded = await attachmentRepo.uploadAttachment(
              a.file.path,
              conversationId: resolvedConvId,
            );
            attachmentPayloads.add({
              'type': uploaded.type.name,
              'filename': a.name,
              'storage_path': uploaded.storagePath ?? '',
              'signed_url': uploaded.signedUrl ?? '',
              if (uploaded.dataUrl != null) 'data_url': uploaded.dataUrl,
              'size_bytes': uploaded.sizeBytes ?? 0,
              'mime_type': uploaded.mimeType ?? '',
            });
          } on DioException catch (e) {
            if (mounted) {
              final msg = e.response?.statusCode == 413
                  ? '${a.name} is too large to upload.'
                  : 'Failed to upload ${a.name}. Check your connection.';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to upload ${a.name}. Please try again.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      }

      setState(() {
        _attachments.clear();
        _updateAttachmentCount();
        widget.stagedAttachmentsNotifier?.value = List.unmodifiable(_attachments);
      });
      widget.onSend(attachments: attachmentPayloads, rawAttachments: const []);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final speechState = ref.watch(speechNotifierProvider);
    final isListening = speechState.status == SpeechStatus.listening;
    final voiceInputEnabled = ref.watch(voiceInputEnabledProvider);
    final usageAsync = ref.watch(coachUsageProvider);
    final isExhausted = usageAsync.whenOrNull(data: (u) => u.isFullyExhausted) ?? false;

    ref.listen<SpeechState>(speechNotifierProvider, (prev, next) {
      if (next.recognizedText.isNotEmpty && !next.isFinal) {
        widget.controller.text = next.recognizedText;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );
      }
      if (prev?.isFinal == false &&
          next.isFinal &&
          next.recognizedText.isNotEmpty) {
        widget.controller.text = next.recognizedText;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );
      }
      if (next.status == SpeechStatus.error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Microphone unavailable'),
          ),
        );
      }
    });

    final colors = AppColorsOf(context);

    return Container(
      decoration: widget.isFloating
          ? const BoxDecoration()
          : BoxDecoration(
              color: colors.background,
              border: Border(
                top: BorderSide(color: colors.border, width: 0.5),
              ),
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Input row ────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              widget.isFloating
                  ? AppDimens.spaceSm
                  : MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              crossAxisAlignment: widget.isFloating
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.end,
              children: [
                // Attachment
                _InputIcon(
                  icon: Icons.add_circle_outline_rounded,
                  onTap: () async {
                    if (_attachments.length >= 3) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Maximum 3 attachments per message'),
                        ),
                      );
                      return;
                    }
                    ref.read(hapticServiceProvider).light();
                    await Navigator.of(context, rootNavigator: true).push<void>(
                      PageRouteBuilder<void>(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            CoachAttachmentPanel(
                          onAttachment: (a) => setState(() {
                            _attachments.add(a);
                            _updateAttachmentCount();
                            widget.stagedAttachmentsNotifier?.value =
                                List.unmodifiable(_attachments);
                          }),
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          final offsetAnimation = Tween<Offset>(
                            begin: const Offset(0.0, 1.0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          ));
                          return SlideTransition(
                            position: offsetAnimation,
                            child: child,
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 300),
                        reverseTransitionDuration:
                            const Duration(milliseconds: 300),
                      ),
                    );
                    if (!mounted) return;
                  },
                  tooltip: 'Attach',
                ),
                const SizedBox(width: AppDimens.spaceSm),
                // Text field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.inputBackground,
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusInput),
                      border: Border.all(color: colors.border, width: 1),
                    ),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      maxLines: 5,
                      minLines: 1,
                      readOnly: isExhausted,
                      maxLength: CoachInputBar.maxLength,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        hintText: isExhausted ? 'Message limit reached' : widget.placeholder,
                        hintStyle: AppTextStyles.bodyLarge
                            .copyWith(color: colors.textTertiary),
                        // Outer Container paints the visible outline (see BoxDecoration above).
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceMd,
                          vertical: AppDimens.spaceSm,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                // Send / Stop / Voice
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    final hasContent = hasText || _attachments.isNotEmpty;

                    if (widget.isSending && widget.conversationId != null) {
                      return _InputIcon(
                        icon: Icons.stop_rounded,
                        filledColor: AppColors.statusError,
                        onTap: () => ref
                            .read(coachChatNotifierProvider(
                                    widget.conversationId!)
                                .notifier)
                            .cancelStream(),
                        tooltip: 'Stop generation',
                      );
                    }

                    if (hasContent) {
                      return _InputIcon(
                        icon: Icons.arrow_upward_rounded,
                        filled: !isExhausted,
                        onTap: isExhausted ? null : _handleSend,
                        tooltip: 'Send',
                      );
                    }

                    if (!voiceInputEnabled) return const SizedBox.shrink();

                    return _InputIcon(
                      icon: isListening
                          ? Icons.stop_circle_rounded
                          : Icons.mic_none_rounded,
                      activeColor: isListening ? AppColors.statusError : null,
                      onTap: () async {
                        if (isListening) {
                          ref
                              .read(speechNotifierProvider.notifier)
                              .stopListening();
                          ref.read(hapticServiceProvider).light();
                        } else {
                          ref.read(hapticServiceProvider).medium();
                          final notifier =
                              ref.read(speechNotifierProvider.notifier);
                          if (ref.read(speechNotifierProvider).status ==
                              SpeechStatus.uninitialized) {
                            final available = await notifier.initialize();
                            if (!available) return;
                          }
                          notifier.startListening();
                        }
                      },
                      tooltip: isListening ? 'Stop listening' : 'Voice input',
                    );
                  },
                ),
              ],
            ),
          ),
          // SF1: Character counter — visible when text length >= 3500
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) {
              final remaining = 4000 - value.text.length;
              if (remaining > 500) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$remaining',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: remaining <= 0
                          ? AppColors.statusError
                          : AppColorsOf(context).textTertiary,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── _InputIcon ────────────────────────────────────────────────────────────────

class _InputIcon extends StatelessWidget {
  const _InputIcon({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.filled = false,
    this.filledColor,
    this.activeColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  /// When true, fills the background with [AppColors.primary].
  final bool filled;

  /// When non-null, fills the background with this color instead of
  /// [AppColors.primary]. Takes precedence over [filled].
  final Color? filledColor;

  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final Color bgColor;
    final Color defaultIconColor;
    if (filledColor != null) {
      bgColor = filledColor!;
      defaultIconColor = Colors.white;
    } else if (filled) {
      bgColor = colors.primary;
      defaultIconColor = colors.textOnSage;
    } else {
      bgColor = colors.inputBackground;
      defaultIconColor = colors.textSecondary;
    }

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: activeColor ?? defaultIconColor,
          ),
        ),
      ),
    );
  }
}
