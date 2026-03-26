/// Chat Thread Screen — pushed from Conversation Drawer or NewChatScreen.
///
/// Displays an existing conversation with full message history.
/// Streaming AI responses are rendered token-by-token with a live typing
/// indicator bubble. Supports file attachments, voice input, and connection
/// status feedback.
///
/// Handles both:
///  • New conversations (conversationId starts with "new_") — sends the
///    pending first message from [pendingFirstMessageProvider] and replaces
///    the route with the server-assigned UUID once [ConversationCreated] fires.
///  • Existing conversations — loads history via [CoachChatNotifier.loadHistory].
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/coach_input_bar.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

// ── ChatThreadScreen ──────────────────────────────────────────────────────────

/// Chat Thread screen — full message history + live streaming input.
class ChatThreadScreen extends ConsumerStatefulWidget {
  /// Creates a [ChatThreadScreen] for the given [conversationId].
  const ChatThreadScreen({super.key, required this.conversationId});

  /// The conversation ID to load.
  ///
  /// May be a temporary "new_XXXX" string for brand-new conversations;
  /// the screen replaces it with the real UUID after [ConversationCreated].
  final String conversationId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  /// Tracks whether [_initConversation] has been called.
  bool _initialized = false;

  /// True when the user has scrolled up far enough that auto-scroll should pause.
  bool _userScrolledUp = false;

  /// True when the floating scroll-to-bottom arrow button should be visible.
  bool _showScrollToBottom = false;

  /// Fix M9: prevents multiple addPostFrameCallback calls from queuing up.
  bool _scrollScheduled = false;

  // Fix H10: Edit state is now managed in CoachChatNotifier / CoachChatState.
  // The local _isEditing, _editingContent, _editSnapshot fields are removed;
  // use chatState.isEditing, chatState.editingContent, chatState.editSnapshot.

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initConversation());
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Updates [_userScrolledUp] based on the current scroll position.
  ///
  /// When the user is within 80 px of the bottom they are considered "at the
  /// bottom" and auto-scroll is active. Beyond 80 px auto-scroll pauses so
  /// the user can read earlier messages without being interrupted.
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 80.0;
    _userScrolledUp = !atBottom;
    final shouldShow = _userScrolledUp;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  /// Either loads history (existing conversation) or fires the pending
  /// first message (new conversation).
  ///
  /// For new conversations, any [PendingMessage.rawAttachments] are uploaded
  /// AFTER the first message completes and the server has assigned a real
  /// conversation UUID (received via the [ConversationCreated] stream event).
  /// They are then delivered as a follow-up message so the user sees them in
  /// the thread without losing any content.
  Future<void> _initConversation() async {
    if (_initialized) return;
    _initialized = true;

    final isNew = widget.conversationId.startsWith('new_');

    if (isNew) {
      // Pick up the pending message stored by NewChatScreen.
      final pending = ref.read(pendingFirstMessageProvider(widget.conversationId));
      if (pending != null) {
        // Clear the pending message immediately to prevent double-send.
        ref.read(pendingFirstMessageProvider(widget.conversationId).notifier).state = null;

        // Determine whether there are raw attachments that need to be uploaded
        // after the conversation is created. If so, we must suppress the
        // route-replace that normally fires inside _dispatchSend — otherwise
        // the widget is disposed before the uploads complete. The route-replace
        // is performed manually at the very end of this method instead.
        final hasRawAttachments = pending.rawAttachments.isNotEmpty;

        // Send the text message first (no attachments — the conversation does
        // not exist on the server yet, so there is no endpoint to upload to).
        await _dispatchSend(
          conversationId: null, // new — server will create one
          text: pending.text,
          persona: pending.persona,
          proactivity: pending.proactivity,
          responseLength: pending.responseLength,
          attachments: pending.attachments,
          // Suppress route-replace when raw attachments follow — the widget
          // must stay alive until all uploads and the follow-up send finish.
          skipRouteReplace: hasRawAttachments,
          systemPromptExtra: pending.systemPromptExtra,
        );

        // After the first send completes, the notifier holds a real UUID from
        // the ConversationCreated event. Upload any raw attachments now and
        // deliver them as a follow-up message so they appear in the thread.
        // The widget is guaranteed to still be mounted here because the
        // route-replace was deferred via skipRouteReplace above.
        if (hasRawAttachments && mounted) {
          final resolvedId = ref
              .read(coachChatNotifierProvider(widget.conversationId))
              .resolvedConversationId;

          if (resolvedId != null && !resolvedId.startsWith('new_')) {
            final attachmentRepo = ref.read(attachmentRepositoryProvider);
            final List<Map<String, dynamic>> uploadedPayloads = [];

            for (final raw in pending.rawAttachments) {
              final path = raw['path'] ?? '';
              final name = raw['name'] ?? '';
              if (path.isEmpty) continue;
              try {
                final uploaded = await attachmentRepo.uploadAttachment(
                  path,
                  conversationId: resolvedId,
                );
                uploadedPayloads.add({
                  'type': uploaded.type.name,
                  'filename': name,
                  'storage_path': uploaded.storagePath ?? '',
                  'signed_url': uploaded.signedUrl ?? '',
                  'size_bytes': uploaded.sizeBytes ?? 0,
                  'mime_type': uploaded.mimeType ?? '',
                });
              } on DioException catch (e) {
                if (mounted) {
                  final msg = e.response?.statusCode == 413
                      ? '$name is too large to upload.'
                      : 'Failed to upload $name. Check your connection.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
                  );
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to upload $name. Please try again.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            }

            // Send the uploaded attachments as a follow-up message so they
            // appear visually in the conversation thread.
            if (uploadedPayloads.isNotEmpty && mounted) {
              await _dispatchSend(
                conversationId: resolvedId,
                text: '',
                persona: pending.persona,
                proactivity: pending.proactivity,
                responseLength: pending.responseLength,
                attachments: uploadedPayloads,
                // Route-replace still suppressed — we do it once below after
                // all uploads and follow-up sends are done.
                skipRouteReplace: true,
              );
            }

            // All async work is done — now it is safe to replace the route.
            // Seed the incoming notifier first so the new screen shows the
            // streamed + attachment messages instead of loading stale history.
            if (mounted) {
              final currentState = ref.read(
                coachChatNotifierProvider(widget.conversationId),
              );
              ref
                  .read(coachChatNotifierProvider(resolvedId).notifier)
                  .seedFromPrior(
                    messages: currentState.messages,
                    resolvedConversationId: resolvedId,
                  );
              context.replaceNamed(
                RouteNames.coachThread,
                pathParameters: {'id': resolvedId},
              );
            }
          }
        }
      }
    } else {
      // If the notifier was pre-seeded (e.g. after a new-conversation
      // route-replace from _dispatchSend), messages are already present —
      // skip the history load to avoid replacing them with stale data.
      final alreadySeeded =
          ref.read(coachChatNotifierProvider(widget.conversationId)).messages.isNotEmpty;
      if (!alreadySeeded) {
        await ref
            .read(coachChatNotifierProvider(widget.conversationId).notifier)
            .loadHistory();
      }
    }
  }

  /// Sends a message via the notifier and optionally replaces the route.
  ///
  /// [skipRouteReplace] — when true the `context.replaceNamed` call that
  /// transitions to the real conversation UUID is suppressed. Use this when
  /// the caller (e.g. [_initConversation]) needs to do additional async work
  /// (such as uploading raw attachments and sending a follow-up message)
  /// before navigation happens. The caller is then responsible for performing
  /// the route-replace once all work is complete.
  Future<void> _dispatchSend({
    required String? conversationId,
    required String text,
    required String persona,
    required String proactivity,
    required String responseLength,
    List<Map<String, dynamic>> attachments = const [],
    bool skipRouteReplace = false,
    String? systemPromptExtra,
  }) async {
    final transaction = Sentry.startTransaction(
      'ai.chat_response',
      'ai',
      description: 'AI coach chat response',
    );

    ref.read(analyticsServiceProvider).capture(
      event: 'coach_message_sent',
      properties: {
        'source': 'thread',
        'conversation_id': conversationId ?? 'new',
        'char_count': text.length,
      },
    );

    try {
      await ref
          .read(coachChatNotifierProvider(widget.conversationId).notifier)
          .sendMessage(
            conversationId: conversationId,
            text: text,
            persona: persona,
            proactivity: proactivity,
            responseLength: responseLength,
            attachments: attachments,
            systemPromptExtra: systemPromptExtra,
          );

      // After the stream completes, check if we got a new conversation ID
      // and replace the current route so the URL reflects the real UUID.
      // Skipped when the caller needs to do more async work before navigation.
      if (!skipRouteReplace && mounted) {
        // Fix C7: don't proceed with route replace if an error occurred and
        // the conversation ID was never resolved.
        final st = ref.read(coachChatNotifierProvider(widget.conversationId));
        if ((st.resolvedConversationId == null ||
                st.resolvedConversationId!.startsWith('new_')) &&
            st.errorMessage != null) {
          return; // Error banner is visible; don't proceed with route replace.
        }

        final currentState =
            ref.read(coachChatNotifierProvider(widget.conversationId));
        final resolvedId = currentState.resolvedConversationId;
        if (resolvedId != null &&
            resolvedId != widget.conversationId &&
            widget.conversationId.startsWith('new_')) {
          // Seed the incoming notifier (keyed on the real UUID) with the
          // messages that were streamed under the temp ID. This prevents the
          // new ChatThreadScreen from calling loadHistory() and replacing the
          // conversation with stale/mock data.
          ref
              .read(coachChatNotifierProvider(resolvedId).notifier)
              .seedFromPrior(
                messages: currentState.messages,
                resolvedConversationId: resolvedId,
              );

          // Replace the current route — keeps the back stack clean.
          context.replaceNamed(
            RouteNames.coachThread,
            pathParameters: {'id': resolvedId},
          );
        }
      }

      transaction.finish(status: const SpanStatus.ok());
    } catch (e, st) {
      transaction.finish(status: const SpanStatus.internalError());
      Sentry.captureException(e, stackTrace: st);
    }

    _scrollToBottom();
  }

  // Fix H8: _sendMessage is now async and awaitable.
  Future<void> _sendMessage({List<Map<String, dynamic>> attachments = const []}) async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty && attachments.isEmpty) return;
    ref.read(hapticServiceProvider).medium();

    final persona = ref.read(coachPersonaProvider).value;
    final proactivity = ref.read(proactivityLevelProvider).value;
    final responseLength = ref.read(responseLengthProvider).value;

    _inputCtrl.clear();
    // Fix H10: clear edit state via notifier.
    final notifierForEdit = ref.read(coachChatNotifierProvider(widget.conversationId).notifier);
    if (ref.read(coachChatNotifierProvider(widget.conversationId)).isEditing) {
      notifierForEdit.cancelEditing();
    }

    // Determine the effective conversation ID.
    // If the notifier already resolved a real ID (e.g. from a prior message
    // in the same session), pass that; otherwise pass the widget ID.
    final notifierState =
        ref.read(coachChatNotifierProvider(widget.conversationId));
    final effectiveId = notifierState.resolvedConversationId;
    final isNewConversation = effectiveId == null ||
        effectiveId.startsWith('new_') ||
        widget.conversationId.startsWith('new_');

    try {
      await _dispatchSend(
        conversationId: isNewConversation ? null : effectiveId,
        text: text,
        persona: persona,
        proactivity: proactivity,
        responseLength: responseLength,
        attachments: attachments,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send. Please try again.')),
        );
      }
    }
  }

  void _scrollToBottom() {
    // Respect the user's scroll position — if they scrolled up to read
    // earlier messages, don't yank them back to the bottom mid-stream.
    // Fix M9: debounce by tracking whether a scroll is already scheduled.
    if (_scrollScheduled || _userScrolledUp) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final chatState = ref.watch(coachChatNotifierProvider(widget.conversationId));
    final conversations = ref.watch(coachConversationsProvider).valueOrNull;

    // Auto-scroll whenever new content arrives, respecting the user's
    // scroll position via the [_userScrolledUp] guard in [_scrollToBottom].
    ref.listen(coachChatNotifierProvider(widget.conversationId), (prev, next) {
      final newMessage = next.messages.length > (prev?.messages.length ?? 0);
      final streamStarted =
          prev?.streamingContent == null && next.streamingContent != null;
      final isActivelyStreaming = next.streamingContent != null;
      final streamFinished =
          (prev?.isSending ?? false) && !next.isSending && next.streamingContent == null;

      if (streamFinished) {
        // Response complete — do nothing; let the user stay where they are.
        // The floating scroll-to-bottom button will be visible if they scrolled up.
      } else if (newMessage || streamStarted || isActivelyStreaming) {
        // Respects [_userScrolledUp] guard inside [_scrollToBottom].
        _scrollToBottom();
      }
    });

    // Derive title: prefer the conversation list entry (which gets updated
    // once the server assigns the AI-generated title), fall back to "Conversation".
    final resolvedId =
        chatState.resolvedConversationId ?? widget.conversationId;
    final convo = conversations?.where((c) => c.id == resolvedId).firstOrNull;
    final title = convo?.title ??
        (widget.conversationId.startsWith('new_') ? 'New Conversation' : 'Conversation');

    return ZuralogScaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: AppTextStyles.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showConversationOptions(context, resolvedId),
            tooltip: 'More options',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Error banner ─────────────────────────────────────────────────
          if (chatState.isNotFound)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.textTertiary),
                    const SizedBox(height: 16),
                    Text('Conversation not found', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'This conversation no longer exists.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.goNamed(RouteNames.coach),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            )
          else if (chatState.errorMessage != null)
            Builder(
              builder: (context) {
                final isUpgradeNeeded =
                    chatState.errorMessage?.toLowerCase().contains('upgrade') == true ||
                    chatState.errorMessage?.toLowerCase().contains('daily messages') == true ||
                    chatState.errorMessage?.toLowerCase().contains('free daily') == true;

                if (isUpgradeNeeded) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceSm,
                    ),
                    color: AppColors.statusError.withValues(alpha: 0.15),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            color: AppColors.statusError, size: 18),
                        const SizedBox(width: AppDimens.spaceSm),
                        Expanded(
                          child: Text(
                            chatState.errorMessage!,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.statusError),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.pushNamed(RouteNames.settingsSubscription),
                          child: const Text('Upgrade',
                              style: TextStyle(color: AppColors.statusError)),
                        ),
                      ],
                    ),
                  );
                }

                return _ErrorBanner(
                  message: chatState.errorMessage!,
                  onRetry: () {
                    final notifier = ref.read(
                      coachChatNotifierProvider(widget.conversationId).notifier,
                    );
                    if (widget.conversationId.startsWith('new_')) {
                      // For new conversations there is no history to load —
                      // just clear the error so the user can re-type and send.
                      notifier.clearError();
                    } else {
                      notifier.loadHistory();
                    }
                  },
                );
              },
            ),
          // ── Message list + streaming bubble ──────────────────────────────
          Expanded(
            child: Stack(
              children: [
                chatState.isLoadingHistory
                    ? const _MessagesLoadingSkeleton()
                    : _MessageList(
                        messages: chatState.messages,
                        streamingContent: chatState.streamingContent,
                        activeToolName: chatState.activeToolName,
                        scrollController: _scrollCtrl,
                        conversationId: widget.conversationId,
                        isSending: chatState.isSending,
                        onEditMessage: (content) {
                          // Fix H10: snapshot is managed by startEditing() in the
                          // notifier; we only need the content to prefill the input.
                          _inputCtrl.text = content;
                          _inputCtrl.selection = TextSelection.collapsed(
                            offset: content.length,
                          );
                          _inputFocus.requestFocus();
                        },
                      ),
                // ── Scroll-to-bottom button ───────────────────────────────
                Positioned(
                  right: AppDimens.spaceMd,
                  bottom: AppDimens.spaceMd,
                  child: AnimatedOpacity(
                    opacity: _showScrollToBottom ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_showScrollToBottom,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _userScrolledUp = false;
                            _showScrollToBottom = false;
                          });
                          _scrollToBottom();
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Generation cancelled indicator ───────────────────────────────
          // Fix H3: show a transient label when stream was cancelled.
          if (chatState.isCancelled && !chatState.isSending)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
              color: colors.cardBackground,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.stop_circle_outlined,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppDimens.spaceXs),
                  Text(
                    'Generation stopped',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          // ── Editing indicator bar ─────────────────────────────────────────
          // Fix H10: read edit state from notifier.
          if (chatState.isEditing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
              color: colors.cardBackground,
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: Text(
                      chatState.editingContent != null
                          ? 'Editing: ${chatState.editingContent}'
                          : 'Editing message',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.textTertiary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Cancel edit',
                    onPressed: () {
                      ref
                          .read(
                            coachChatNotifierProvider(
                              widget.conversationId,
                            ).notifier,
                          )
                          .cancelEditing();
                      _inputCtrl.clear();
                    },
                  ),
                ],
              ),
            ),
          CoachInputBar(
            controller: _inputCtrl,
            focusNode: _inputFocus,
            onSend: ({attachments = const [], rawAttachments = const []}) =>
                _sendMessage(attachments: attachments),
            isSending: chatState.isSending,
            conversationId: widget.conversationId,
          ),
        ],
      ),
    );
  }

  Future<void> _showConversationOptions(
    BuildContext context,
    String conversationId,
  ) async {
    if (conversationId.startsWith('new_')) return;
    ref.read(hapticServiceProvider).light();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final sheetColors = AppColorsOf(sheetCtx);
        return Container(
        decoration: BoxDecoration(
          color: sheetColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: sheetColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: Text('Rename', style: AppTextStyles.bodyLarge),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showRenameDialog(context, conversationId);
              },
            ),
            Divider(height: 1, color: sheetColors.border),
            ListTile(
              leading: const Icon(Icons.archive_outlined, color: AppColors.primary),
              title: Text('Archive', style: AppTextStyles.bodyLarge),
              onTap: () {
                Navigator.pop(sheetCtx);
                _archiveAndPop(context, conversationId);
              },
            ),
            Divider(height: 1, color: sheetColors.border),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.statusError),
              title: Text(
                'Delete',
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.statusError),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showDeleteDialog(context, conversationId);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      );
      },
    );
  }

  void _showRenameDialog(BuildContext context, String conversationId) {
    final ctrl = TextEditingController();
    // Capture messenger before async gap.
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColorsOf(dialogCtx).surface,
         title: Text('Rename Conversation', style: AppTextStyles.titleMedium),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 100,
          style: AppTextStyles.bodyLarge,
          decoration: const InputDecoration(hintText: 'New title…'),
        ),
        actions: [
          TextButton(
            // Fix C8: use dialogCtx, not outer context.
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = ctrl.text.trim();
              if (newTitle.isEmpty) return;
              // Fix C8: use dialogCtx, not outer context.
              Navigator.pop(dialogCtx);
              try {
                await ref
                    .read(coachConversationsProvider.notifier)
                    .rename(conversationId, newTitle);
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Rename failed. Please try again.')),
                  );
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _archiveAndPop(BuildContext context, String conversationId) async {
    final messenger = ScaffoldMessenger.of(context);
    // Fix L3: capture router before async gap.
    final router = GoRouter.of(context);
    try {
      await ref.read(coachConversationsProvider.notifier).archive(conversationId);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Conversation archived')),
        );
        // Fix L3: explicit navigation to coach root.
        router.goNamed(RouteNames.coach);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Archive failed. Please try again.')));
      }
    }
  }

  void _showDeleteDialog(BuildContext context, String conversationId) {
    // Fix L3: capture router and messenger before async gap.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        final dialogColors = AppColorsOf(dialogCtx);
        return AlertDialog(
        backgroundColor: dialogColors.surface,
         title: Text('Delete conversation?', style: AppTextStyles.titleMedium),
        content: Text(
          'This cannot be undone.',
          style: AppTextStyles.bodyLarge.copyWith(color: dialogColors.textSecondary),
        ),
        actions: [
          TextButton(
            // Fix C8: use dialogCtx, not outer context.
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Fix C8: use dialogCtx, not outer context.
              Navigator.pop(dialogCtx);
              try {
                await ref
                    .read(coachConversationsProvider.notifier)
                    .delete(conversationId);
                if (mounted) {
                  // Fix L3: explicit navigation to coach root.
                  router.goNamed(RouteNames.coach);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Conversation deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger
                      .showSnackBar(SnackBar(content: Text('Delete failed. Please try again.')));
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.statusError)),
          ),
        ],
      );
      },
    );
  }
}

// ── _ErrorBanner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      color: AppColors.statusError.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.statusError, size: 18),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.statusError),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry',
                style: TextStyle(color: AppColors.statusError)),
          ),
        ],
      ),
    );
  }
}

// ── _MessageList ──────────────────────────────────────────────────────────────

class _MessageList extends ConsumerWidget {
  const _MessageList({
    required this.messages,
    required this.scrollController,
    required this.conversationId,
    required this.isSending,
    required this.onEditMessage,
    this.streamingContent,
    this.activeToolName,
  });

  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final String conversationId;
  final bool isSending;

  /// Called when the user taps "Edit" on a user message bubble.
  /// Receives the [content] of the message being edited.
  /// The snapshot is saved internally by [CoachChatNotifier.startEditing].
  final void Function(String content) onEditMessage;

  final String? streamingContent;
  final String? activeToolName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show the streaming bubble whenever the AI is working — including the
    // "thinking" gap between Send and the first token/tool event.
    final showTypingBubble =
        isSending || streamingContent != null || activeToolName != null;
    // Pre-compute the last assistant message index for the Regenerate action.
    final lastAssistantIndex = (!isSending && streamingContent == null && activeToolName == null)
        ? messages.lastIndexWhere((m) => m.role == MessageRole.assistant)
        : -1;
    final totalItems = messages.length + (showTypingBubble ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
      itemCount: totalItems,
      itemBuilder: (_, i) {
        if (i < messages.length) {
          final msg = messages[i];
          // Regenerate is available on the last assistant message only,
          // and only when nothing is in flight.
          final isLastAssistant =
              msg.role == MessageRole.assistant && i == lastAssistantIndex;
          return _MessageBubble(
            message: msg,
            onEdit: (msg.role == MessageRole.user && !isSending)
                ? () {
                    // Fix H10: startEditing saves snapshot and truncates state.
                    final notifier = ref.read(
                      coachChatNotifierProvider(conversationId).notifier,
                    );
                    notifier.startEditing(i);
                    final content = ref
                        .read(coachChatNotifierProvider(conversationId))
                        .editingContent;
                    if (content != null) {
                      onEditMessage(content);
                    }
                  }
                : null,
            onRegenerate: isLastAssistant
                ? () => ref
                    .read(coachChatNotifierProvider(conversationId).notifier)
                    .regenerate()
                : null,
          );
        }
        // Streaming / tool-progress / thinking bubble at the bottom.
        return _StreamingBubble(
          content: streamingContent,
          toolName: activeToolName,
          isSending: isSending,
        );
      },
    );
  }
}

// ── _StreamingBubble ──────────────────────────────────────────────────────────

/// Shows partial streaming tokens, a tool-progress indicator, or a
/// "Thinking…" label while the AI is formulating its first response.
class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({this.content, this.toolName, required this.isSending});

  final String? content;
  final String? toolName;

  /// True while [CoachChatState.isSending] is set — used to display the
  /// "Thinking…" label before the first token arrives.
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm + 2,
              ),
              decoration: BoxDecoration(
                color: colors.aiBubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDimens.radiusCard),
                  topRight: Radius.circular(AppDimens.radiusCard),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(AppDimens.radiusCard),
                ),
              ),
              child: toolName != null && (content == null || content!.isEmpty)
                  // Tool in progress — show named tool indicator.
                  ? _ToolProgressIndicator(toolName: toolName!)
                  : content != null && content!.isNotEmpty
                      // Tokens streaming — render markdown live.
                      ? MarkdownBody(
                          data: content!,
                          styleSheet: MarkdownStyleSheet.fromTheme(
                            Theme.of(context).copyWith(
                              textTheme: Theme.of(context).textTheme.apply(
                                    bodyColor: colors.textPrimary,
                                    displayColor: colors.textPrimary,
                                  ),
                            ),
                          ).copyWith(
                            p: AppTextStyles.bodyLarge.copyWith(
                              color: colors.textPrimary,
                              height: 1.45,
                            ),
                          ),
                        )
                      // Thinking phase — animated dots + label.
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _TypingIndicator(),
                            const SizedBox(height: 6),
                            Text(
                              'Thinking…',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: colors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolProgressIndicator extends StatelessWidget {
  const _ToolProgressIndicator({required this.toolName});

  final String toolName;

  String _friendlyName(String tool) {
    return switch (tool) {
      'apple_health_read_metrics' => 'Reading your health data…',
      'health_connect_read_metrics' => 'Reading your health data…',
      'get_activities' => 'Checking your Strava activities…',
      'get_fitbit_data' => 'Checking your Fitbit data…',
      'get_oura_data' => 'Checking your Oura data…',
      'withings_get_measurements' => 'Checking Withings data…',
      'oura_get_daily_activity' => 'Reading Oura Ring activity…',
      'oura_get_sleep' => 'Reading Oura Ring sleep…',
      'oura_get_heart_rate' => 'Reading Oura Ring heart rate…',
      'query_memory' => 'Checking your history…',
      'save_memory' => 'Saving to memory…',
      _ => 'Checking your data…',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Text(
          _friendlyName(toolName),
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// ── _MessageBubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onEdit, this.onRegenerate});

  final ChatMessage message;

  /// Called when the user taps "Edit" in the long-press sheet.
  /// Only provided for user messages; null for AI messages.
  final VoidCallback? onEdit;

  /// Called when the user taps "Regenerate" in the long-press sheet.
  /// Only provided for the last assistant message when nothing is in flight.
  final VoidCallback? onRegenerate;

  bool get _isUser => message.role == MessageRole.user;

  String _formatTime(DateTime dt, BuildContext context) {
    return TimeOfDay.fromDateTime(dt).format(context);
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  String _filename(String url) {
    final name = url.split('/').last.split('?').first;
    return name.length > 18 ? '${name.substring(0, 15)}…' : name;
  }

  Widget _buildThumbnail(BuildContext context, String url) {
    final colors = AppColorsOf(context);
    if (_isImageUrl(url)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
          errorBuilder: (context, error, stack) => Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.broken_image_outlined,
                color: AppColors.textTertiary, size: 28),
          ),
        ),
      );
    }
    return Container(
      width: 80,
      height: 52,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf_rounded,
              color: AppColors.statusError, size: 24),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _filename(url),
               style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showCopySheet(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final sheetColors = AppColorsOf(sheetCtx);
        return Container(
        decoration: BoxDecoration(
          color: sheetColors.cardBackground,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusCard),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: sheetColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            // ── Actions ─────────────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: AppColors.primary),
              title: Text('Copy', style: AppTextStyles.bodyLarge),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await Clipboard.setData(ClipboardData(text: message.content));
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Copied to clipboard',
                      style: AppTextStyles.bodyLarge,
                    ),
                  ),
                );
              },
            ),
            if (onEdit != null) ...[
              Divider(height: 1, color: sheetColors.border),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
                title: Text('Edit', style: AppTextStyles.bodyLarge),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  onEdit!();
                },
              ),
            ],
            if (onRegenerate != null) ...[
              Divider(height: 1, color: sheetColors.border),
              ListTile(
                leading: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                title: Text('Regenerate', style: AppTextStyles.bodyLarge),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  onRegenerate!();
                },
              ),
            ],
            SizedBox(height: MediaQuery.of(sheetCtx).padding.bottom),
          ],
        ),
      );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      child: Row(
        mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: AppDimens.spaceSm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: _isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (message.hasAttachments) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment:
                        _isUser ? WrapAlignment.end : WrapAlignment.start,
                    children:
                        message.attachmentUrls.map((url) => _buildThumbnail(context, url)).toList(),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                ],
                GestureDetector(
                  onLongPress: () => _showCopySheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceSm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: _isUser
                          ? AppColors.userBubble
                          : colors.aiBubble,
                      borderRadius: BorderRadius.only(
                        topLeft:
                            const Radius.circular(AppDimens.radiusCard),
                        topRight:
                            const Radius.circular(AppDimens.radiusCard),
                        bottomLeft: _isUser
                            ? const Radius.circular(AppDimens.radiusCard)
                            : const Radius.circular(4),
                        bottomRight: _isUser
                            ? const Radius.circular(4)
                            : const Radius.circular(AppDimens.radiusCard),
                      ),
                    ),
                    child: _isUser
                        ? Text(
                            message.content,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.userBubbleText,
                              height: 1.45,
                            ),
                          )
                        : MarkdownBody(
                            data: message.content,
                            styleSheet: MarkdownStyleSheet.fromTheme(
                              Theme.of(context).copyWith(
                                textTheme: Theme.of(context).textTheme.apply(
                                      bodyColor: colors.textPrimary,
                                      displayColor: colors.textPrimary,
                                    ),
                              ),
                            ).copyWith(
                              p: AppTextStyles.bodyLarge.copyWith(
                                color: colors.textPrimary,
                                height: 1.45,
                              ),
                              strong: AppTextStyles.bodyLarge.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              em: AppTextStyles.bodyLarge.copyWith(
                                color: colors.textPrimary,
                                fontStyle: FontStyle.italic,
                              ),
                              listBullet: AppTextStyles.bodyLarge.copyWith(
                                color: colors.textPrimary,
                                height: 1.45,
                              ),
                              code: AppTextStyles.bodySmall.copyWith(
                                color: colors.textPrimary,
                                backgroundColor:
                                    colors.isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.createdAt, context),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                ),
                // SF2: Visible copy button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      color: AppColors.textTertiary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: message.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── _TypingIndicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
            final opacity = 0.3 + (phase * 0.7);
            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 4.0 : 0),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── _MessagesLoadingSkeleton ──────────────────────────────────────────────────

class _MessagesLoadingSkeleton extends StatefulWidget {
  const _MessagesLoadingSkeleton();

  @override
  State<_MessagesLoadingSkeleton> createState() =>
      _MessagesLoadingSkeletonState();
}

class _MessagesLoadingSkeletonState extends State<_MessagesLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmerAnim =
        CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fix L4: use screen-width-relative skeleton widths.
    final sw = MediaQuery.of(context).size.width;
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, _) {
        final opacity = 0.3 + (_shimmerAnim.value * 0.3);
        return Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Column(
            children: [
              _Bubble(isUser: false, width: sw * 0.65, opacity: opacity),
              const SizedBox(height: AppDimens.spaceMd),
              _Bubble(isUser: true, width: sw * 0.45, opacity: opacity),
              const SizedBox(height: AppDimens.spaceMd),
              _Bubble(isUser: false, width: sw * 0.75, opacity: opacity),
              const SizedBox(height: AppDimens.spaceMd),
              _Bubble(isUser: true, width: sw * 0.35, opacity: opacity),
            ],
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.isUser,
    required this.width,
    required this.opacity,
  });

  final bool isUser;
  final double width;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.shimmerBase.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
          ],
          Container(
            width: width,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            ),
          ),
        ],
      ),
    );
  }
}
