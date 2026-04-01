/// Coach Tab — Single adaptive screen replacing NewChatScreen + ChatThreadScreen.
///
/// Renders two visual states based on conversation content:
///   - IdleState: empty conversation
///   - ConversationState: messages present (history or active chat)
///
/// No route navigation occurs between states — everything is inline.
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/chat/domain/attachment_types.dart';
import 'package:zuralog/features/coach/presentation/widgets/attachment_preview_bar.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';
import 'package:zuralog/features/coach/presentation/coach_history_screen.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_idle_state.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_message_list.dart';
import 'package:zuralog/features/coach/data/coach_draft_service.dart';
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
///
/// [AttachmentPreviewBar] now renders in a separate floating layer above the
/// pill, so the pill height is always constant at this estimate.
const double _kInputPillHeight = 68.0;

/// Gap between the bottom of the floating input pill and the screen edge.
///
/// Applied as extra breathing room below the pill and as padding on content
/// so the last item is never hidden. 16px = [_kPillBottomGap] * 2.
const double _kPillBottomGap = 8.0;

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
  final _stagedAttachments = ValueNotifier<List<PendingAttachment>>(const []);
  bool _prefillApplied = false;
  Timer? _draftDebounce;

  String get _draftKey =>
      _activeConversationId.startsWith('new_') ? '__pending' : _activeConversationId;

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
    _inputCtrl.addListener(_onInputChanged);
    if (!_prefillApplied) {
      final saved = ref.read(coachDraftServiceProvider).loadDraft(_draftKey);
      if (saved != null && saved.isNotEmpty) {
        _inputCtrl.text = saved;
        _inputCtrl.selection = TextSelection.collapsed(offset: saved.length);
      }
    }
  }

  @override
  void dispose() {
    _inputCtrl.removeListener(_onInputChanged);
    _draftDebounce?.cancel();
    ref.read(coachDraftServiceProvider).saveDraft(_draftKey, _inputCtrl.text);
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _stagedAttachments.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(coachDraftServiceProvider).saveDraft(_draftKey, _inputCtrl.text);
    });
  }

  void _startNewConversation() {
    _draftDebounce?.cancel();
    ref.read(coachDraftServiceProvider).saveDraft(_draftKey, _inputCtrl.text);
    setState(() {
      _activeConversationId = 'new_${DateTime.now().millisecondsSinceEpoch}';
    });
    // New conversations always map to __pending via _draftKey.
    final saved = ref.read(coachDraftServiceProvider).loadDraft(_draftKey);
    _inputCtrl.text = saved ?? '';
    if (_inputCtrl.text.isNotEmpty) {
      _inputCtrl.selection =
          TextSelection.collapsed(offset: _inputCtrl.text.length);
    }
  }

  void _loadConversation(String conversationId) {
    _draftDebounce?.cancel();
    ref.read(coachDraftServiceProvider).saveDraft(_draftKey, _inputCtrl.text);
    setState(() => _activeConversationId = conversationId);
    final saved = ref.read(coachDraftServiceProvider).loadDraft(_draftKey);
    _inputCtrl.text = saved ?? '';
    if (_inputCtrl.text.isNotEmpty) {
      _inputCtrl.selection =
          TextSelection.collapsed(offset: _inputCtrl.text.length);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(coachChatNotifierProvider(conversationId).notifier).loadHistory();
    });
  }

  void _openDrawer() {
    ref.read(hapticServiceProvider).light();
    Navigator.of(context, rootNavigator: true).push(
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

  Future<void> _sendMessage({
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty && attachments.isEmpty) return;
    ref.read(hapticServiceProvider).medium();

    final persona = ref.read(coachPersonaProvider).value;
    final proactivity = ref.read(proactivityLevelProvider).value;
    final responseLength = ref.read(responseLengthProvider).value;
    final notifierState =
        ref.read(coachChatNotifierProvider(_activeConversationId));
    final effectiveId = notifierState.resolvedConversationId;
    final isNew = effectiveId == null || effectiveId.startsWith('new_');

    _inputCtrl.clear();
    _draftDebounce?.cancel();
    ref.read(coachDraftServiceProvider).clearDraft(_draftKey);

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send. Please try again.')),
        );
      }
    }
  }

  List<ChatMessage> _buildMessages(CoachChatState chatState) {
    // Streaming phase: live assistant bubble with accumulated tokens.
    if (chatState.streamingContent != null &&
        chatState.streamingContent!.isNotEmpty) {
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
    // Thinking phase: blank placeholder so CoachThinkingLayer (Layer 0) has
    // an assistant row to render into before any tokens arrive.
    if (chatState.isSending) {
      return [
        ...chatState.messages,
        ChatMessage(
          id: 'thinking',
          conversationId: _activeConversationId,
          role: MessageRole.assistant,
          content: '',
          createdAt: DateTime.now(),
        ),
      ];
    }
    return chatState.messages;
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
    final messages = _buildMessages(chatState);
    final isIdle = messages.isEmpty;

    final placeholder = isIdle ? 'Ask Zura anything…' : 'Message Zura…';

    // Effective conversation ID to pass to CoachInputBar for live attachment
    // uploads. New conversations pass null so attachments upload after the
    // server creates a real ID.
    final effectiveConversationId =
        _activeConversationId.startsWith('new_') ? null : _activeConversationId;

    final colors = AppColorsOf(context);

    return ZuralogScaffold(
      appBar: ZuralogAppBar(
        title: 'Coach',
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: _openDrawer,
          tooltip: 'Conversations',
        ),
      ),
      body: ColoredBox(
        color: colors.canvas,
        child: Stack(
          children: [
            // Layer 1: Content (full height)
            Column(
              children: [
                Expanded(
                  child: isIdle
                      ? CoachIdleState(
                          bottomPadding: _kInputPillHeight +
                              AppDimens.bottomClearance(context) +
                              _kPillBottomGap * 2,
                          onSuggestionTap: (prompt) {
                            _inputCtrl.text = prompt;
                            _sendMessage();
                          },
                        )
                      : CoachMessageList(
                          messages: messages,
                          isStreaming: chatState.isSending,
                          // True from send until the first StreamToken sets
                          // streamingContent — covers tool calls, thinking
                          // tokens, and the initial wait. Mutually exclusive
                          // with the synthetic streaming message in
                          // _buildMessages which only renders when
                          // streamingContent != null.
                          isThinking: chatState.isSending && chatState.streamingContent == null,
                          thinkingContent: chatState.thinkingContent,
                          activeToolName: chatState.activeToolName,
                          bottomPadding: _kInputPillHeight +
                              AppDimens.bottomClearance(context) +
                              _kPillBottomGap * 2,
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
                          onThumbUp: (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Thanks for the feedback!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          onThumbDown: (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Got it. We\'ll work on improving this.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          onRedo: () {
                            ref
                                .read(coachChatNotifierProvider(_activeConversationId).notifier)
                                .regenerate();
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
                    _kPillBottomGap,
                child: _ErrorBanner(
                  message: chatState.errorMessage!,
                  onDismiss: () => ref
                      .read(coachChatNotifierProvider(_activeConversationId)
                          .notifier)
                      .clearError(),
                ),
              ),

            // Layer 2.5: Floating attachment previews (above the pill)
            ValueListenableBuilder<List<PendingAttachment>>(
              valueListenable: _stagedAttachments,
              builder: (context, attachments, _) {
                if (attachments.isEmpty) return const SizedBox.shrink();
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: _kInputPillHeight +
                      AppDimens.bottomClearance(context) +
                      _kPillBottomGap,
                  child: AttachmentPreviewBar(
                    attachments: attachments,
                    onRemove: (i) =>
                        _inputBarKey.currentState?.removeAttachment(i),
                  ),
                );
              },
            ),

            // Layer 3: Floating input pill
            Positioned(
              left: 0,
              right: 0,
              bottom: AppDimens.bottomClearance(context) + _kPillBottomGap,
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
                  stagedAttachmentsNotifier: _stagedAttachments,
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
              color: colors.surface.withValues(alpha: AppDimens.navBarFrostOpacity),
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

