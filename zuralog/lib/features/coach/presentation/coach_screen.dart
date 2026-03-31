/// Coach Tab — Single adaptive screen replacing NewChatScreen + ChatThreadScreen.
///
/// Renders three visual states based on conversation content and ghost mode:
///   - IdleState: empty conversation, no ghost mode
///   - ConversationState: messages present (history or active chat)
///   - Ghost mode: ConversationState with tinted background + banner
///
/// No route navigation occurs between states — everything is inline.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_ghost_banner.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_idle_state.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_message_list.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/shared/widgets/coach_input_bar.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';
import 'package:zuralog/shared/widgets/zuralog_app_bar.dart';

// ── CoachScreen ───────────────────────────────────────────────────────────────

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  late String _activeConversationId;
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final _inputBarKey = GlobalKey<CoachInputBarState>();
  bool _prefillApplied = false;

  @override
  void initState() {
    super.initState();
    _activeConversationId = 'new_${DateTime.now().millisecondsSinceEpoch}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _prefillApplied) return;
      final pending = ref.read(coachPrefillProvider);
      if (pending != null && pending.isNotEmpty) {
        _prefillApplied = true;
        if (_inputCtrl.text.isEmpty) {
          _inputCtrl.text = pending;
          _inputFocus.requestFocus();
        }
        ref.read(coachPrefillProvider.notifier).state = null;
      }
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _startNewConversation() {
    setState(() {
      _activeConversationId = 'new_${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  void _loadConversation(String conversationId) {
    setState(() => _activeConversationId = conversationId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(coachChatNotifierProvider(conversationId).notifier).loadHistory();
    });
  }

  void _openDrawer() {
    ref.read(hapticServiceProvider).light();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CoachConversationDrawer(
        onConversationTap: (id) {
          Navigator.of(context).pop();
          _loadConversation(id);
        },
        onNewConversation: () {
          Navigator.of(context).pop();
          _startNewConversation();
        },
      ),
    );
  }

  void _onGhostModeButtonTap() {
    final isGhost = ref.read(ghostModeProvider);
    if (isGhost) {
      _showExitGhostSheet();
    } else {
      _showActivateGhostSheet();
    }
  }

  void _showActivateGhostSheet() {
    final colors = AppColorsOf(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(AppDimens.spaceMd),
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ghost Mode', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Nothing you say here will be saved or remembered by Zura. This conversation disappears when you leave.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref.read(ghostModeProvider.notifier).state = true;
                    setState(() {
                      _activeConversationId =
                          'ghost_${DateTime.now().millisecondsSinceEpoch}';
                    });
                  },
                  child: const Text('Start Ghost Session'),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showExitGhostSheet() {
    final colors = AppColorsOf(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(AppDimens.spaceMd),
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('End ghost session?', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'This conversation will be cleared.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref.read(ghostModeProvider.notifier).state = false;
                    _startNewConversation();
                  },
                  child: const Text('End Session'),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage({
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty && attachments.isEmpty) return;
    ref.read(hapticServiceProvider).medium();

    final persona = ref.read(coachPersonaProvider).value;
    final proactivity = ref.read(proactivityLevelProvider).value;
    final responseLength = ref.read(responseLengthProvider).value;
    final isGhost = ref.read(ghostModeProvider);

    final notifierState =
        ref.read(coachChatNotifierProvider(_activeConversationId));
    final effectiveId = notifierState.resolvedConversationId;
    final isNew = effectiveId == null ||
        effectiveId.startsWith('new_') ||
        effectiveId.startsWith('ghost_');

    _inputCtrl.clear();

    try {
      await ref
          .read(coachChatNotifierProvider(_activeConversationId).notifier)
          .sendMessage(
            conversationId: isNew ? null : effectiveId,
            text: text,
            persona: persona,
            proactivity: proactivity,
            responseLength: responseLength,
            attachments: attachments,
          );

      if (!isGhost && mounted) {
        ref.read(coachConversationsProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send. Please try again.')),
        );
      }
    }
  }

  List<ChatMessage> _buildMessages(CoachChatState chatState) {
    if (chatState.streamingContent == null ||
        chatState.streamingContent!.isEmpty) {
      return chatState.messages;
    }
    return [
      ...chatState.messages,
      ChatMessage(
        id: 'streaming',
        conversationId: _activeConversationId,
        role: MessageRole.assistant,
        content: chatState.streamingContent!,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(coachPrefillProvider, (_, prefill) {
      if (prefill != null && prefill.isNotEmpty && !_prefillApplied) {
        _prefillApplied = true;
        _inputCtrl.text = prefill;
        _inputFocus.requestFocus();
        ref.read(coachPrefillProvider.notifier).state = null;
      }
    });

    final chatState =
        ref.watch(coachChatNotifierProvider(_activeConversationId));
    final isGhost = ref.watch(ghostModeProvider);
    final messages = _buildMessages(chatState);
    final isIdle = messages.isEmpty;

    final placeholder = isGhost
        ? 'Ask anything — this stays private'
        : isIdle
            ? 'Ask Zura anything…'
            : 'Message Zura…';

    // Effective conversation ID to pass to CoachInputBar for live attachment
    // uploads. Ghost sessions and new conversations pass null so attachments
    // upload after the server creates a real ID.
    final effectiveConversationId =
        _activeConversationId.startsWith('new_') ||
                _activeConversationId.startsWith('ghost_')
            ? null
            : _activeConversationId;

    final colors = AppColorsOf(context);

    return ZuralogScaffold(
      appBar: ZuralogAppBar(
        title: 'Coach',
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: _openDrawer,
          tooltip: 'Conversations',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_off_rounded),
            color: isGhost ? colors.primary : colors.textSecondary,
            onPressed: _onGhostModeButtonTap,
            tooltip: isGhost ? 'Exit Ghost Mode' : 'Ghost Mode',
          ),
        ],
      ),
      body: ColoredBox(
        color: isGhost ? colors.canvasGhost : colors.canvas,
        child: Column(
          children: [
            if (isGhost) CoachGhostBanner(onExit: _showExitGhostSheet),
            Expanded(
              child: isIdle
                  ? CoachIdleState(
                      onSuggestionTap: (prompt) {
                        _inputCtrl.text = prompt;
                        _sendMessage();
                      },
                    )
                  : CoachMessageList(
                      messages: messages,
                      isStreaming: chatState.isSending,
                      isThinking: chatState.activeToolName != null,
                      onEditMessage: (index) {
                        if (index < messages.length) {
                          _inputCtrl.text = messages[index].content;
                          _inputFocus.requestFocus();
                        }
                      },
                      onCopyMessage: (content) {
                        Clipboard.setData(ClipboardData(text: content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
            ),
            if (chatState.errorMessage != null)
              _ErrorBanner(
                message: chatState.errorMessage!,
                onDismiss: () => ref
                    .read(coachChatNotifierProvider(_activeConversationId)
                        .notifier)
                    .clearError(),
              ),
            CoachInputBar(
              key: _inputBarKey,
              controller: _inputCtrl,
              focusNode: _inputFocus,
              placeholder: placeholder,
              onSend: ({attachments = const [], rawAttachments = const []}) =>
                  _sendMessage(attachments: attachments),
              conversationId: effectiveConversationId,
              isSending: chatState.isSending,
            ),
          ],
        ),
      ),
    );
  }
}

// ── _ErrorBanner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.error.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              color: AppColors.error,
              onPressed: onDismiss,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

// ── _CoachConversationDrawer ──────────────────────────────────────────────────
// Adapted from _ConversationDrawer in new_chat_screen.dart.
// Key difference: tapping a conversation fires onConversationTap(id)
// instead of navigating to a new route.

class _CoachConversationDrawer extends ConsumerStatefulWidget {
  const _CoachConversationDrawer({
    required this.onConversationTap,
    required this.onNewConversation,
  });

  final void Function(String conversationId) onConversationTap;
  final VoidCallback onNewConversation;

  @override
  ConsumerState<_CoachConversationDrawer> createState() =>
      _CoachConversationDrawerState();
}

class _CoachConversationDrawerState
    extends ConsumerState<_CoachConversationDrawer> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Conversation> _filterConversations(
    List<Conversation> conversations,
    String query,
  ) {
    if (query.isEmpty) return conversations;
    final lower = query.toLowerCase();
    return conversations.where((c) {
      final titleMatch = c.title.toLowerCase().contains(lower);
      final previewMatch =
          c.preview != null && c.preview!.toLowerCase().contains(lower);
      return titleMatch || previewMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(coachConversationsProvider);
    final colors = AppColorsOf(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusCard),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppDimens.spaceMd),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Conversations',
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search_rounded),
                      onPressed: () => setState(() => _isSearching = true),
                      tooltip: 'Search conversations',
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () {
                        ref.read(hapticServiceProvider).light();
                        Navigator.of(ctx).pop();
                        widget.onNewConversation();
                      },
                      tooltip: 'New conversation',
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: _isSearching
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimens.spaceMd,
                          0,
                          AppDimens.spaceMd,
                          AppDimens.spaceSm,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.inputBackground,
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusInput,
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            autofocus: true,
                            style: AppTextStyles.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'Search conversations...',
                              hintStyle: AppTextStyles.bodyLarge.copyWith(
                                color: colors.textTertiary,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppDimens.spaceMd,
                                vertical: AppDimens.spaceSm,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: colors.textTertiary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSearching = false;
                                    _searchController.clear();
                                  });
                                  _searchFocus.unfocus();
                                },
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Divider(height: 1, color: colors.border),
              Expanded(
                child: conversationsAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: colors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Could not load conversations',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                  data: (conversations) {
                    if (conversations.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimens.spaceXl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 48,
                                color: colors.textTertiary
                                    .withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: AppDimens.spaceMd),
                              Text(
                                'No conversations yet',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: colors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: AppDimens.spaceSm),
                              Text(
                                'Start a new chat to get started',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: colors.textTertiary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final filtered = _filterConversations(
                      conversations,
                      _searchController.text.trim(),
                    );

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimens.spaceXl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: colors.textTertiary,
                              ),
                              const SizedBox(height: AppDimens.spaceMd),
                              Text(
                                'No conversations match your search',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: colors.textTertiary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimens.spaceSm,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: AppDimens.spaceMd,
                        color: colors.border,
                      ),
                      itemBuilder: (_, i) => _CoachConversationTile(
                        conversation: filtered[i],
                        onTap: () {
                          ref.read(hapticServiceProvider).light();
                          widget.onConversationTap(filtered[i].id);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── _CoachConversationTile ────────────────────────────────────────────────────

class _CoachConversationTile extends StatelessWidget {
  const _CoachConversationTile({
    required this.conversation,
    required this.onTap,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year % 100}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      title: Text(
        conversation.title,
        style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: conversation.preview != null
          ? Text(
              conversation.preview!,
              style: AppTextStyles.bodySmall
                  .copyWith(color: colors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Text(
        _formatDate(conversation.createdAt),
        style:
            AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}
