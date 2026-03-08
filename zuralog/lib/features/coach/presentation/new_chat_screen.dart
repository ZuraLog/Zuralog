/// New Chat Screen — Tab 2 (Coach) root screen.
///
/// Opens to a fresh empty conversation. Shows personalized suggested prompt
/// chips when empty, integration context banner, and chat input with voice
/// and attachment support. Drawer accessible via hamburger icon or swipe.
///
/// Phase 10: Full production implementation with haptics, onboarding tooltip,
/// conversation drawer, quick actions sheet, and skeleton loading state.
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/speech/speech_providers.dart';
import 'package:zuralog/core/speech/speech_state.dart';
import 'package:zuralog/core/theme/app_assets.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';
import 'package:zuralog/features/coach/presentation/widgets/attachment_picker_sheet.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';
import 'package:zuralog/features/coach/presentation/widgets/attachment_preview_bar.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/shared/widgets/onboarding_tooltip.dart';
import 'package:zuralog/shared/widgets/profile_avatar_button.dart';
import 'package:zuralog/shared/widgets/quick_log_sheet.dart';

// ── NewChatScreen ─────────────────────────────────────────────────────────────

/// Coach tab root — new conversation entry point.
///
/// When no conversation is active, renders the branded welcome state with
/// prompt suggestion chips. Input field + send / voice / attachment buttons
/// are always visible at the bottom.
class NewChatScreen extends ConsumerStatefulWidget {
  /// Creates the [NewChatScreen].
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _openDrawer(BuildContext ctx) {
    ref.read(hapticServiceProvider).light();
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ConversationDrawer(),
    );
  }

  void _openQuickActions(BuildContext ctx) {
    ref.read(hapticServiceProvider).light();
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _QuickActionsSheet(
        onActionTap: (prompt) {
          Navigator.of(sheetCtx).pop();
          if (prompt.isNotEmpty) {
            _inputCtrl.text = prompt;
            _sendMessage();
          } else {
            // "Ask Anything" — just focus the input field
            _inputFocus.requestFocus();
          }
        },
      ),
    );
  }

  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(hapticServiceProvider).medium();

    // Read current coach preferences to include in message payload.
    final persona = ref.read(coachPersonaProvider).value;
    final proactivity = ref.read(proactivityLevelProvider).value;
    final responseLength = ref.read(responseLengthProvider).value;

    ref
        .read(analyticsServiceProvider)
        .capture(
          event: 'coach_message_sent',
          properties: {'source': 'new_chat', 'char_count': text.length},
        );
    _inputCtrl.clear();

    // Capture a single ID so the sendMessage call and the navigation route
    // reference the same conversation. Using two separate DateTime.now() calls
    // would produce different IDs across the ~1ms gap.
    final newConversationId = 'new_${DateTime.now().millisecondsSinceEpoch}';

    // Send message with coach preferences to backend.
    // TODO(phase9): await response and handle streaming once real API is wired.
    // Errors are intentionally ignored here — when the real API is wired, replace
    // this with an awaited call inside a try/catch that shows a SnackBar on failure.
    ref.read(coachRepositoryProvider).sendMessage(
      conversationId: newConversationId,
      text: text,
      persona: persona,
      proactivity: proactivity,
      responseLength: responseLength,
    ).ignore();

    // In production: create a new conversation via the repository, then push
    // to the thread screen. For Phase 10 we just navigate to a stub thread.
    context.pushNamed(
      RouteNames.coachThread,
      pathParameters: {'id': newConversationId},
    );
  }

  void _onSuggestionTap(String text) {
    ref.read(hapticServiceProvider).light();
    ref
        .read(analyticsServiceProvider)
        .capture(
          event: 'coach_suggestion_tapped',
          properties: {'suggestion_text': text},
        );
    _inputCtrl.text = text;
    _inputFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for metric deep-link prefill text set by the Data tab.
    ref.listen<String?>(coachPrefillProvider, (_, prefill) {
      if (prefill != null && prefill.isNotEmpty) {
        _inputCtrl.text = prefill;
        _inputFocus.requestFocus();
        // Clear the provider so it is not re-applied on subsequent rebuilds.
        ref.read(coachPrefillProvider.notifier).state = null;
      }
    });

    // Handle prefill value that was set before this build cycle ran
    // (e.g., navigating from Data/Insight tab to Coach tab).
    final pendingPrefill = ref.read(coachPrefillProvider);
    if (pendingPrefill != null && pendingPrefill.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Only apply if the field is still empty (don't overwrite user input).
        if (_inputCtrl.text.isEmpty) {
          _inputCtrl.text = pendingPrefill;
          _inputFocus.requestFocus();
        }
        ref.read(coachPrefillProvider.notifier).state = null;
      });
    }

    final suggestionsAsync = ref.watch(coachPromptSuggestionsProvider);
    final suggestedPromptsEnabled = ref.watch(suggestedPromptsEnabledProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        surfaceTintColor: Colors.transparent,
        title: Text('Coach', style: AppTextStyles.h2),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _openDrawer(context),
          tooltip: 'Conversations',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded),
            onPressed: () => _openQuickActions(context),
            tooltip: 'Quick Actions',
          ),
          const Padding(
            padding: EdgeInsets.only(right: AppDimens.spaceMd),
            child: ProfileAvatarButton(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Empty State Body ───────────────────────────────────────────────
          Expanded(
            child: suggestionsAsync.when(
              loading: () => const _CoachLoadingSkeleton(),
              error: (e, _) => _CoachEmptyState(
                onSuggestionTap: _onSuggestionTap,
                suggestions: const [],
                suggestedPromptsEnabled: suggestedPromptsEnabled,
              ),
              data: (suggestions) => _CoachEmptyState(
                onSuggestionTap: _onSuggestionTap,
                suggestions: suggestions,
                suggestedPromptsEnabled: suggestedPromptsEnabled,
              ),
            ),
          ),
          const _IntegrationContextBanner(),
          // ── Input Bar ──────────────────────────────────────────────────────
          _ChatInputBar(
            controller: _inputCtrl,
            focusNode: _inputFocus,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ── _CoachEmptyState ──────────────────────────────────────────────────────────

class _CoachEmptyState extends StatelessWidget {
  const _CoachEmptyState({
    required this.suggestions,
    required this.onSuggestionTap,
    required this.suggestedPromptsEnabled,
  });

  final List<PromptSuggestion> suggestions;
  final ValueChanged<String> onSuggestionTap;
  final bool suggestedPromptsEnabled;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Column(
        children: [
          const SizedBox(height: AppDimens.spaceXxl),
          // ── Brand icon ─────────────────────────────────────────────────────
          OnboardingTooltip(
            screenKey: 'coach_new_chat',
            tooltipKey: 'welcome',
            message:
                'Ask me anything about your health. I can see data from all your connected apps and remember our past conversations.',
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SvgPicture.asset(
                  AppAssets.logoSvg,
                  colorFilter: const ColorFilter.mode(
                    AppColors.primary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Your health coach',
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Ask me anything. I have full context from\nyour connected apps and health history.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceXl),
          // ── Suggestion chips ───────────────────────────────────────────────
          if (suggestedPromptsEnabled && suggestions.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Try asking',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Wrap(
              spacing: AppDimens.spaceSm,
              runSpacing: AppDimens.spaceSm,
              children: suggestions
                  .map(
                    (s) => _SuggestionChip(
                      text: s.text,
                      onTap: () => onSuggestionTap(s.text),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: AppDimens.spaceXl),
        ],
      ),
    );
  }
}

// ── _SuggestionChip ───────────────────────────────────────────────────────────

class _SuggestionChip extends ConsumerWidget {
  const _SuggestionChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(hapticServiceProvider).light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
          border: Border.all(color: AppColors.borderDark, width: 1),
        ),
        child: Text(
          text,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
      ),
    );
  }
}

// ── _IntegrationContextBanner ─────────────────────────────────────────────────

/// Compact, dismissible banner shown above the input bar that surfaces which
/// apps the AI has access to for the current session.
///
/// Returns [SizedBox.shrink] when no integrations are connected or after the
/// user taps the dismiss button. Dismissal is ephemeral (session only).
class _IntegrationContextBanner extends ConsumerStatefulWidget {
  const _IntegrationContextBanner();

  @override
  ConsumerState<_IntegrationContextBanner> createState() =>
      _IntegrationContextBannerState();
}

class _IntegrationContextBannerState
    extends ConsumerState<_IntegrationContextBanner> {
  bool _dismissed = false;

  void _dismiss() => setState(() => _dismissed = true);

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final integrationsState = ref.watch(integrationsProvider);
    final connected = integrationsState.integrations
        .where((i) => i.status == IntegrationStatus.connected)
        .toList();

    if (connected.isEmpty) return const SizedBox.shrink();

    // Build the label: list all names when ≤2, otherwise first two + "+N more".
    final String namesLabel;
    if (connected.length <= 2) {
      namesLabel = connected.map((i) => i.name).join(', ');
    } else {
      final first2 = connected.take(2).map((i) => i.name).join(', ');
      final remaining = connected.length - 2;
      namesLabel = '$first2 +$remaining more';
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              'AI has access to: $namesLabel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: _dismiss,
            color: AppColors.textTertiary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

// ── _ChatInputBar ─────────────────────────────────────────────────────────────

class _ChatInputBar extends ConsumerStatefulWidget {
  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  ConsumerState<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<_ChatInputBar> {
  final List<PendingAttachment> _attachments = [];
  bool _isSending = false;

  Future<void> _handleSend() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;
    if (_isSending) return;
    _isSending = true;

    try {
      // Mock upload attachments before sending.
      // TODO(supabase): pass attachmentUrls to onSend once backend upload is wired
      List<String> attachmentUrls = [];
      if (_attachments.isNotEmpty) {
        // TODO(supabase): replace with real Supabase Storage upload
        for (final a in _attachments) {
          await Future.delayed(const Duration(milliseconds: 800));
          if (kDebugMode) {
            attachmentUrls.add(
              'https://mock.supabase.co/storage/attachments/${a.name}',
            );
          }
        }
      }

      setState(() => _attachments.clear());
      widget.onSend();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final speechState = ref.watch(speechNotifierProvider);
    final isListening = speechState.status == SpeechStatus.listening;
    final voiceInputEnabled = ref.watch(voiceInputEnabledProvider);

    // Sync recognized text to input field.
    ref.listen<SpeechState>(speechNotifierProvider, (prev, next) {
      // Stream partial results while listening.
      if (next.recognizedText.isNotEmpty && !next.isFinal) {
        widget.controller.text = next.recognizedText;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );
      }
      // Commit final transcript when listening ends.
      if (prev?.isFinal == false &&
          next.isFinal &&
          next.recognizedText.isNotEmpty) {
        widget.controller.text = next.recognizedText;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );
      }
      // Show error snackbar.
      if (next.status == SpeechStatus.error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Microphone unavailable'),
          ),
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
          // ── Attachment previews ──────────────────────────────────────────
          AttachmentPreviewBar(
            attachments: _attachments,
            onRemove: (i) => setState(() => _attachments.removeAt(i)),
          ),
          // ── Input row ────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              AppDimens.bottomClearance(context),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment
                _InputIconButton(
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
                      builder: (_) => AttachmentPickerSheet(
                        onAttachment: (attachment) {
                          setState(() => _attachments.add(attachment));
                        },
                      ),
                    );
                  },
                  tooltip: 'Attach',
                ),
                const SizedBox(width: AppDimens.spaceSm),
                // Text field
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
                        hintStyle: AppTextStyles.body.copyWith(
                          color: AppColors.textTertiary,
                        ),
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
                // Send / Voice
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    final hasContent = hasText || _attachments.isNotEmpty;
                    if (hasContent) {
                      return _InputIconButton(
                        icon: Icons.arrow_upward_rounded,
                        filled: true,
                        onTap: _handleSend,
                        tooltip: 'Send',
                      );
                    }
                    if (!voiceInputEnabled) {
                      return const SizedBox.shrink();
                    }
                    return _InputIconButton(
                      icon: isListening
                          ? Icons.stop_circle_rounded
                          : Icons.mic_none_rounded,
                      filled: false,
                      activeColor: isListening ? AppColors.statusError : null,
                      onTap: () {
                        if (isListening) {
                          ref
                              .read(speechNotifierProvider.notifier)
                              .stopListening();
                          ref.read(hapticServiceProvider).light();
                        } else {
                          ref.read(hapticServiceProvider).medium();
                          ref
                              .read(speechNotifierProvider.notifier)
                              .startListening();
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

class _InputIconButton extends ConsumerWidget {
  const _InputIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.filled = false,
    this.activeColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool filled;

  /// Override icon color (e.g. red when mic is recording).
  final Color? activeColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: filled ? AppColors.primary : AppColors.inputBackgroundDark,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: activeColor ??
                (filled
                    ? AppColors.primaryButtonText
                    : AppColors.textSecondaryDark),
          ),
        ),
      ),
    );
  }
}

// ── _ConversationDrawer ───────────────────────────────────────────────────────

/// Bottom sheet listing past conversations (Conversation Drawer).
class _ConversationDrawer extends ConsumerWidget {
  const _ConversationDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(coachConversationsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackgroundDark,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimens.radiusCard),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: AppDimens.spaceMd),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
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
                      child: Text('Conversations', style: AppTextStyles.h3),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () {
                        ref.read(hapticServiceProvider).light();
                        Navigator.of(ctx).pop();
                      },
                      tooltip: 'New conversation',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderDark),
              // List
              Expanded(
                child: conversationsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Could not load conversations',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  data: (conversations) => ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimens.spaceSm,
                    ),
                    itemCount: conversations.length,
                    separatorBuilder: (context, _) => const Divider(
                      height: 1,
                      indent: AppDimens.spaceMd,
                      color: AppColors.borderDark,
                    ),
                    itemBuilder: (_, i) => _ConversationTile(
                      conversation: conversations[i],
                      onTap: () {
                        ref.read(hapticServiceProvider).light();
                        Navigator.of(ctx).pop();
                        context.pushNamed(
                          RouteNames.coachThread,
                          pathParameters: {'id': conversations[i].id},
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  Future<void> _showActionsSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
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
                leading: const Icon(
                  Icons.archive_outlined,
                  color: AppColors.primary,
                ),
                title: Text('Archive', style: AppTextStyles.body),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _archiveConversation(context, ref);
                },
              ),
              const Divider(height: 1, color: AppColors.borderDark),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.statusError,
                ),
                title: Text(
                  'Delete',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.statusError,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showDeleteConfirmation(context, ref);
                },
              ),
              SizedBox(
                height: MediaQuery.of(context).padding.bottom,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _archiveConversation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await ref
        .read(coachRepositoryProvider)
        .archiveConversation(conversation.id);
    ref.invalidate(coachConversationsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation archived')),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text('Delete conversation?', style: AppTextStyles.h3),
        content: Text(
          'This cannot be undone.',
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(context, ref);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.statusError),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    ref.read(hapticServiceProvider).medium();
    await ref
        .read(coachRepositoryProvider)
        .deleteConversation(conversation.id);
    ref.invalidate(coachConversationsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: () => _showActionsSheet(context, ref),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceMd,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.title,
                            style: AppTextStyles.h3.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Text(
                          _formatDate(conversation.updatedAt),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    if (conversation.preview != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        conversation.preview!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _QuickActionsSheet ────────────────────────────────────────────────────────

class _QuickActionsSheet extends ConsumerWidget {
  const _QuickActionsSheet({required this.onActionTap});

  final ValueChanged<String> onActionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionsAsync = ref.watch(coachQuickActionsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.8,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackgroundDark,
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
                    color: AppColors.borderDark,
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Quick Actions', style: AppTextStyles.h3),
                ),
              ),
              const Divider(height: 1, color: AppColors.borderDark),
              Expanded(
                child: actionsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Could not load quick actions',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  data: (actions) {
                    final totalCount = actions.length + 1; // +1 for Quick Log tile
                    return GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppDimens.spaceMd),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppDimens.spaceSm,
                            crossAxisSpacing: AppDimens.spaceSm,
                            childAspectRatio: 1.6,
                          ),
                      itemCount: totalCount,
                      itemBuilder: (gridCtx, i) {
                        if (i == actions.length) {
                          return _QuickLogTile(outerContext: ctx);
                        }
                        return _QuickActionTile(
                          action: actions[i],
                          onTap: () {
                            ref.read(hapticServiceProvider).medium();
                            ref
                                .read(analyticsServiceProvider)
                                .capture(
                                  event: 'coach_quick_action_tapped',
                                  properties: {'title': actions[i].title},
                                );
                            onActionTap(actions[i].prompt);
                          },
                        );
                      },
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

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.onTap});

  final QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              IconData(action.icon, fontFamily: 'MaterialIcons'),
              size: 24,
              color: AppColors.primary,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  action.subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLogTile extends ConsumerWidget {
  const _QuickLogTile({required this.outerContext});
  final BuildContext outerContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(hapticServiceProvider).light();
        Navigator.of(outerContext).pop(); // close quick actions sheet
        showModalBottomSheet<void>(
          context: outerContext,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollController) => QuickLogSheet(
              scrollController: scrollController,
              onSubmit: (QuickLogData data) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(outerContext).showSnackBar(
                  SnackBar(
                    content: const Text('Health data logged!'),
                    backgroundColor: AppColors.surfaceDark,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusButtonMd,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(
            color: AppColors.categoryActivity.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(
              Icons.edit_note_rounded,
              size: 24,
              color: AppColors.categoryActivity,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Log',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Log metrics manually',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── _CoachLoadingSkeleton ─────────────────────────────────────────────────────

/// Shimmer skeleton shown while prompt suggestions are loading.
class _CoachLoadingSkeleton extends StatefulWidget {
  const _CoachLoadingSkeleton();

  @override
  State<_CoachLoadingSkeleton> createState() => _CoachLoadingSkeletonState();
}

class _CoachLoadingSkeletonState extends State<_CoachLoadingSkeleton>
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
    _shimmerAnim = CurvedAnimation(
      parent: _shimmerCtrl,
      curve: Curves.easeInOut,
    );
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
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Column(
            children: [
              const SizedBox(height: AppDimens.spaceXxl),
              // Avatar skeleton
              Center(
                child: _Bone(
                  width: 72,
                  height: 72,
                  radius: 36,
                  opacity: opacity,
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Center(child: _Bone(width: 160, height: 22, opacity: opacity)),
              const SizedBox(height: AppDimens.spaceSm),
              Center(child: _Bone(width: 240, height: 16, opacity: opacity)),
              const SizedBox(height: AppDimens.spaceXl),
              // Label
              Align(
                alignment: Alignment.centerLeft,
                child: _Bone(width: 80, height: 12, opacity: opacity),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              // Chips row 1
              Wrap(
                spacing: AppDimens.spaceSm,
                runSpacing: AppDimens.spaceSm,
                children: [
                  _Bone(width: 180, height: 36, radius: 18, opacity: opacity),
                  _Bone(width: 140, height: 36, radius: 18, opacity: opacity),
                  _Bone(width: 200, height: 36, radius: 18, opacity: opacity),
                  _Bone(width: 160, height: 36, radius: 18, opacity: opacity),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({
    required this.width,
    required this.height,
    required this.opacity,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double opacity;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.shimmerBase.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
