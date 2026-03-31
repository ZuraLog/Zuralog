/// Coach Tab — Single adaptive screen replacing NewChatScreen + ChatThreadScreen.
///
/// Renders three visual states based on conversation content and ghost mode:
///   - IdleState: empty conversation, no ghost mode
///   - ConversationState: messages present (history or active chat)
///   - Ghost mode: ConversationState with tinted background + banner
///
/// No route navigation occurs between states — everything is inline.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';
import 'package:zuralog/features/coach/presentation/coach_history_screen.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_ghost_banner.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_idle_state.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_message_list.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/shared/widgets/coach_input_bar.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';
import 'package:zuralog/shared/widgets/zuralog_app_bar.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Estimated height of the floating input pill.
///
/// Used to pre-calculate bottom padding for the message list so the last
/// message is never hidden behind the pill. The value accounts for the
/// default single-line input row height.
const double _kInputPillHeight = 68.0;

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
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CoachHistoryScreen(
          onConversationTap: _loadConversation,
          onNewConversation: _startNewConversation,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
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
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 280),
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
        child: Stack(
          children: [
            // Layer 1: Content (full height)
            Column(
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
                          bottomPadding: _kInputPillHeight +
                              AppDimens.bottomClearance(context) +
                              16,
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
              ],
            ),

            // Layer 2: Error banner (positioned just above the pill)
            if (chatState.errorMessage != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: _kInputPillHeight +
                    AppDimens.bottomClearance(context) +
                    8,
                child: _ErrorBanner(
                  message: chatState.errorMessage!,
                  onDismiss: () => ref
                      .read(coachChatNotifierProvider(_activeConversationId)
                          .notifier)
                      .clearError(),
                ),
              ),

            // Layer 3: Floating input pill
            Positioned(
              left: 0,
              right: 0,
              bottom: AppDimens.bottomClearance(context) + 8,
              child: _FrostedInputPill(
                child: CoachInputBar(
                  key: _inputBarKey,
                  controller: _inputCtrl,
                  focusNode: _inputFocus,
                  placeholder: placeholder,
                  onSend: ({
                    attachments = const [],
                    rawAttachments = const [],
                  }) =>
                      _sendMessage(attachments: attachments),
                  conversationId: effectiveConversationId,
                  isSending: chatState.isSending,
                  isFloating: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _FrostedInputPill ─────────────────────────────────────────────────────────

/// Frosted-glass pill container for the floating input bar.
///
/// Uses the same blur + surface overlay recipe as [_FrostedNavigationBar] in
/// [AppShell] so the two floating elements look visually consistent.
class _FrostedInputPill extends StatelessWidget {
  const _FrostedInputPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMdPlus),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.shapePill),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppDimens.navBarBlurSigma,
            sigmaY: AppDimens.navBarBlurSigma,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppDimens.shapePill),
            ),
            child: child,
          ),
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

