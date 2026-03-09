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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/speech/speech_providers.dart';
import 'package:zuralog/core/speech/speech_state.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';
import 'package:zuralog/features/coach/presentation/widgets/attachment_picker_sheet.dart';
import 'package:zuralog/features/coach/presentation/widgets/attachment_preview_bar.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initConversation());
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Either loads history (existing conversation) or fires the pending
  /// first message (new conversation).
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
        await _dispatchSend(
          conversationId: null, // new — server will create one
          text: pending.text,
          persona: pending.persona,
          proactivity: pending.proactivity,
          responseLength: pending.responseLength,
          attachments: pending.attachments,
        );
      }
    } else {
      // Load existing message history.
      await ref
          .read(coachChatNotifierProvider(widget.conversationId).notifier)
          .loadHistory();
    }
  }

  Future<void> _dispatchSend({
    required String? conversationId,
    required String text,
    required String persona,
    required String proactivity,
    required String responseLength,
    List<Map<String, dynamic>> attachments = const [],
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
          );

      // After the stream completes, check if we got a new conversation ID
      // and replace the current route so the URL reflects the real UUID.
      if (mounted) {
        final resolvedId = ref
            .read(coachChatNotifierProvider(widget.conversationId))
            .resolvedConversationId;
        if (resolvedId != null &&
            resolvedId != widget.conversationId &&
            widget.conversationId.startsWith('new_')) {
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

  void _sendMessage({List<Map<String, dynamic>> attachments = const []}) {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty && attachments.isEmpty) return;
    ref.read(hapticServiceProvider).medium();

    final persona = ref.read(coachPersonaProvider).value;
    final proactivity = ref.read(proactivityLevelProvider).value;
    final responseLength = ref.read(responseLengthProvider).value;

    _inputCtrl.clear();

    // Determine the effective conversation ID.
    // If the notifier already resolved a real ID (e.g. from a prior message
    // in the same session), pass that; otherwise pass the widget ID.
    final notifierState =
        ref.read(coachChatNotifierProvider(widget.conversationId));
    final effectiveId = notifierState.resolvedConversationId;
    final isNewConversation = effectiveId == null ||
        effectiveId.startsWith('new_') ||
        widget.conversationId.startsWith('new_');

    _dispatchSend(
      conversationId: isNewConversation ? null : effectiveId,
      text: text,
      persona: persona,
      proactivity: proactivity,
      responseLength: responseLength,
      attachments: attachments,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    final chatState = ref.watch(coachChatNotifierProvider(widget.conversationId));
    final conversations = ref.watch(coachConversationsProvider).valueOrNull;

    // Auto-scroll whenever new content arrives.
    ref.listen(coachChatNotifierProvider(widget.conversationId), (prev, next) {
      final wasStreaming = prev?.streamingContent != null;
      final isStreaming = next.streamingContent != null;
      final newMessage = (next.messages.length) > (prev?.messages.length ?? 0);
      if (newMessage || (!wasStreaming && isStreaming)) {
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

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: AppTextStyles.h3,
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
          if (chatState.errorMessage != null)
            _ErrorBanner(
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
            ),
          // ── Message list + streaming bubble ──────────────────────────────
          Expanded(
            child: chatState.isLoadingHistory
                ? const _MessagesLoadingSkeleton()
                : _MessageList(
                    messages: chatState.messages,
                    streamingContent: chatState.streamingContent,
                    activeToolName: chatState.activeToolName,
                    scrollController: _scrollCtrl,
                    conversationId: widget.conversationId,
                    isSending: chatState.isSending,
                  ),
          ),
          _ChatInputBar(
            controller: _inputCtrl,
            focusNode: _inputFocus,
            onSend: ({attachments = const []}) =>
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
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: Text('Rename', style: AppTextStyles.body),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showRenameDialog(context, conversationId);
              },
            ),
            const Divider(height: 1, color: AppColors.borderDark),
            ListTile(
              leading: const Icon(Icons.archive_outlined, color: AppColors.primary),
              title: Text('Archive', style: AppTextStyles.body),
              onTap: () {
                Navigator.pop(sheetCtx);
                _archiveAndPop(context, conversationId);
              },
            ),
            const Divider(height: 1, color: AppColors.borderDark),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.statusError),
              title: Text(
                'Delete',
                style: AppTextStyles.body.copyWith(color: AppColors.statusError),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showDeleteDialog(context, conversationId);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, String conversationId) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text('Rename Conversation', style: AppTextStyles.h3),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppTextStyles.body,
          decoration: const InputDecoration(hintText: 'New title…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = ctrl.text.trim();
              if (newTitle.isEmpty) return;
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(coachConversationsProvider.notifier)
                    .rename(conversationId, newTitle);
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Rename failed: $e')),
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
    final nav = GoRouter.of(context);
    try {
      await ref.read(coachConversationsProvider.notifier).archive(conversationId);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Conversation archived')),
        );
        nav.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Archive failed: $e')));
      }
    }
  }

  void _showDeleteDialog(BuildContext context, String conversationId) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text('Delete conversation?', style: AppTextStyles.h3),
        content: Text(
          'This cannot be undone.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              final nav = GoRouter.of(context);
              try {
                await ref
                    .read(coachConversationsProvider.notifier)
                    .delete(conversationId);
                if (mounted) {
                  nav.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Conversation deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger
                      .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.statusError)),
          ),
        ],
      ),
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
              style: AppTextStyles.caption
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
    this.streamingContent,
    this.activeToolName,
  });

  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final String conversationId;
  final bool isSending;
  final String? streamingContent;
  final String? activeToolName;

  /// True when the Regenerate button should be visible:
  /// not streaming, last message is assistant, and there is at least one
  /// user message.
  bool get _showRegenerateButton {
    if (isSending) return false;
    if (streamingContent != null || activeToolName != null) return false;
    if (messages.isEmpty) return false;
    if (messages.last.role != MessageRole.assistant) return false;
    return messages.any((m) => m.role == MessageRole.user);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTypingBubble =
        streamingContent != null || activeToolName != null;
    final showRegenerate = _showRegenerateButton;
    final totalItems =
        messages.length + (showTypingBubble ? 1 : 0) + (showRegenerate ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
      itemCount: totalItems,
      itemBuilder: (_, i) {
        if (i < messages.length) {
          return _MessageBubble(message: messages[i]);
        }
        // Streaming / tool-progress bubble at the bottom.
        if (showTypingBubble && i == messages.length) {
          return _StreamingBubble(
            content: streamingContent,
            toolName: activeToolName,
          );
        }
        // Regenerate button — appears below the last AI message.
        return Padding(
          padding: const EdgeInsets.only(
            bottom: AppDimens.spaceMd,
            top: AppDimens.spaceSm,
          ),
          child: Center(
            child: TextButton.icon(
              onPressed: () => ref
                  .read(coachChatNotifierProvider(conversationId).notifier)
                  .regenerate(),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 16,
              ),
              label: const Text('Regenerate'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondaryDark,
                textStyle: AppTextStyles.caption,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceSm,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── _StreamingBubble ──────────────────────────────────────────────────────────

/// Shows partial streaming tokens or a tool-progress indicator.
class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({this.content, this.toolName});

  final String? content;
  final String? toolName;

  @override
  Widget build(BuildContext context) {
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
                color: AppColors.aiBubbleDark,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDimens.radiusCard),
                  topRight: Radius.circular(AppDimens.radiusCard),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(AppDimens.radiusCard),
                ),
              ),
              child: toolName != null && (content == null || content!.isEmpty)
                  ? _ToolProgressIndicator(toolName: toolName!)
                  : content != null && content!.isNotEmpty
                      ? MarkdownBody(
                          data: content!,
                          styleSheet: MarkdownStyleSheet.fromTheme(
                            Theme.of(context).copyWith(
                              textTheme: Theme.of(context).textTheme.apply(
                                    bodyColor: AppColors.textPrimaryDark,
                                    displayColor: AppColors.textPrimaryDark,
                                  ),
                            ),
                          ).copyWith(
                            p: AppTextStyles.body.copyWith(
                              color: AppColors.textPrimaryDark,
                              height: 1.45,
                            ),
                          ),
                        )
                      : const _TypingIndicator(),
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
      'query_memory' => 'Checking your history…',
      'save_memory' => 'Saving to memory…',
      _ => 'Checking your data…',
    };
  }

  @override
  Widget build(BuildContext context) {
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
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondaryDark,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// ── _MessageBubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

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

  Widget _buildThumbnail(String url) {
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
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
          errorBuilder: (context, error, stack) => Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
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
        color: AppColors.surfaceDark,
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
              style: AppTextStyles.caption.copyWith(
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
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.vertical(
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
                color: AppColors.borderDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            // ── Actions ─────────────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: AppColors.primary),
              title: Text('Copy', style: AppTextStyles.body),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await Clipboard.setData(ClipboardData(text: message.content));
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Copied to clipboard',
                      style: AppTextStyles.body,
                    ),
                  ),
                );
              },
            ),
            // Task 4 will add an Edit ListTile here (user messages only).
            SizedBox(height: MediaQuery.of(sheetCtx).padding.bottom),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAttachments = message.attachmentUrls.isNotEmpty;

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
                if (hasAttachments) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment:
                        _isUser ? WrapAlignment.end : WrapAlignment.start,
                    children:
                        message.attachmentUrls.map(_buildThumbnail).toList(),
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
                          : AppColors.aiBubbleDark,
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
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.userBubbleText,
                              height: 1.45,
                            ),
                          )
                        : MarkdownBody(
                            data: message.content,
                            styleSheet: MarkdownStyleSheet.fromTheme(
                              Theme.of(context).copyWith(
                                textTheme: Theme.of(context).textTheme.apply(
                                      bodyColor: AppColors.textPrimaryDark,
                                      displayColor: AppColors.textPrimaryDark,
                                    ),
                              ),
                            ).copyWith(
                              p: AppTextStyles.body.copyWith(
                                color: AppColors.textPrimaryDark,
                                height: 1.45,
                              ),
                              strong: AppTextStyles.body.copyWith(
                                color: AppColors.textPrimaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                              em: AppTextStyles.body.copyWith(
                                color: AppColors.textPrimaryDark,
                                fontStyle: FontStyle.italic,
                              ),
                              listBullet: AppTextStyles.body.copyWith(
                                color: AppColors.textPrimaryDark,
                                height: 1.45,
                              ),
                              code: AppTextStyles.caption.copyWith(
                                color: AppColors.textPrimaryDark,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.08),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.createdAt, context),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
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
                  color: AppColors.textSecondaryDark.withValues(alpha: opacity),
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

// ── _ChatInputBar ─────────────────────────────────────────────────────────────

class _ChatInputBar extends ConsumerStatefulWidget {
  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.conversationId,
    this.isSending = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function({List<Map<String, dynamic>> attachments}) onSend;

  /// The conversation ID — used to call [cancelStream] on the notifier.
  final String conversationId;

  /// When true the send button is replaced by a stop button.
  final bool isSending;

  @override
  ConsumerState<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<_ChatInputBar> {
  final List<PendingAttachment> _attachments = [];

  Future<void> _handleSend() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;
    if (widget.isSending) return;

    // Upload attachments.
    final List<Map<String, dynamic>> attachmentPayloads = [];
    if (_attachments.isNotEmpty) {
      final attachmentRepo = ref.read(attachmentRepositoryProvider);
      for (final a in _attachments) {
        try {
          final uploaded = await attachmentRepo.uploadAttachment(a.file.path);
          attachmentPayloads.add({
            'type': 'image',
            'filename': a.name,
            'storage_path': uploaded.storagePath ?? '',
            'signed_url': uploaded.signedUrl ?? '',
            'size_bytes': uploaded.sizeBytes ?? 0,
            'mime_type': uploaded.mimeType ?? '',
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload ${a.name}: $e')),
            );
          }
        }
      }
    }

    setState(() => _attachments.clear());
    widget.onSend(attachments: attachmentPayloads);
  }

  @override
  Widget build(BuildContext context) {
    final speechState = ref.watch(speechNotifierProvider);
    final isListening = speechState.status == SpeechStatus.listening;
    final voiceInputEnabled = ref.watch(voiceInputEnabledProvider);

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
          SnackBar(content: Text(next.errorMessage ?? 'Microphone unavailable')),
        );
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(
          top: BorderSide(color: AppColors.borderDark, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AttachmentPreviewBar(
            attachments: _attachments,
            onRemove: (i) => setState(() => _attachments.removeAt(i)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
                    await showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => AttachmentPickerSheet(
                        onAttachment: (a) => setState(() => _attachments.add(a)),
                      ),
                    );
                  },
                  tooltip: 'Attach',
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.inputBackgroundDark,
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusInput),
                    ),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      maxLines: 5,
                      minLines: 1,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'Message your coach…',
                        hintStyle: AppTextStyles.body
                            .copyWith(color: AppColors.textTertiary),
                        border: InputBorder.none,
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
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    final hasContent = hasText || _attachments.isNotEmpty;

                    if (widget.isSending) {
                      return _InputIcon(
                        icon: Icons.stop_rounded,
                        filledColor: AppColors.statusError,
                        onTap: () => ref
                            .read(coachChatNotifierProvider(
                                    widget.conversationId)
                                .notifier)
                            .cancelStream(),
                        tooltip: 'Stop generation',
                      );
                    }

                    if (hasContent) {
                      return _InputIcon(
                        icon: Icons.arrow_upward_rounded,
                        filled: true,
                        onTap: _handleSend,
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
        ],
      ),
    );
  }
}

class _InputIcon extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final Color bgColor;
    final Color defaultIconColor;
    if (filledColor != null) {
      bgColor = filledColor!;
      defaultIconColor = Colors.white;
    } else if (filled) {
      bgColor = AppColors.primary;
      defaultIconColor = AppColors.primaryButtonText;
    } else {
      bgColor = AppColors.inputBackgroundDark;
      defaultIconColor = AppColors.textSecondaryDark;
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
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, _) {
        final opacity = 0.3 + (_shimmerAnim.value * 0.3);
        return Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Column(
            children: [
              _Bubble(isUser: false, width: 260, opacity: opacity),
              const SizedBox(height: AppDimens.spaceMd),
              _Bubble(isUser: true, width: 180, opacity: opacity),
              const SizedBox(height: AppDimens.spaceMd),
              _Bubble(isUser: false, width: 300, opacity: opacity),
              const SizedBox(height: AppDimens.spaceMd),
              _Bubble(isUser: true, width: 140, opacity: opacity),
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
