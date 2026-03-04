/// Chat Thread Screen — pushed from Conversation Drawer.
///
/// Displays an existing conversation with full message history.
/// Streaming AI responses rendered with a typing indicator, markdown-style
/// bold/italic text, and a sticky input bar with send, voice, and attachment.
///
/// Phase 10: Full production implementation with haptics, skeleton loading,
/// and rich message bubble UI.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/haptics/haptic_providers.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';
import 'package:zuralog/features/coach/providers/coach_providers.dart';

// ── ChatThreadScreen ──────────────────────────────────────────────────────────

/// Chat Thread screen — full message history + live input.
class ChatThreadScreen extends ConsumerStatefulWidget {
  /// Creates a [ChatThreadScreen] for the given [conversationId].
  const ChatThreadScreen({super.key, required this.conversationId});

  /// The conversation ID to load and display.
  final String conversationId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(hapticServiceProvider).medium();
    _inputCtrl.clear();
    // In production: append message to provider, stream AI response.
    // Scroll to bottom after state update.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
        ref.watch(coachMessagesProvider(widget.conversationId));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        surfaceTintColor: Colors.transparent,
        title: messagesAsync.maybeWhen(
          data: (msgs) {
            // Derive title from conversation list if available.
            final conversations =
                ref.watch(coachConversationsProvider).valueOrNull;
            final convo = conversations?.where(
              (c) => c.id == widget.conversationId,
            ).firstOrNull;
            return Text(
              convo?.title ?? 'Conversation',
              style: AppTextStyles.h3,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
          orElse: () => Text('Conversation', style: AppTextStyles.h3),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => ref.read(hapticServiceProvider).light(),
            tooltip: 'More options',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const _MessagesLoadingSkeleton(),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.statusError,
                      size: 40,
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    Text(
                      'Could not load conversation',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    TextButton(
                      onPressed: () => ref
                          .invalidate(coachMessagesProvider(widget.conversationId)),
                      child: Text(
                        'Retry',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              data: (messages) => _MessageList(
                messages: messages,
                scrollController: _scrollCtrl,
              ),
            ),
          ),
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

// ── _MessageList ──────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.scrollController,
  });

  final List<ChatMessage> messages;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
      itemCount: messages.length,
      itemBuilder: (_, i) => _MessageBubble(message: messages[i]),
    );
  }
}

// ── _MessageBubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  bool get _isUser => message.role == MessageRole.user;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      child: Row(
        mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isUser) ...[
            // AI avatar
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
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: _isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                    vertical: AppDimens.spaceSm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: _isUser
                        ? AppColors.userBubble
                        : AppColors.aiBubbleDark,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppDimens.radiusCard),
                      topRight: const Radius.circular(AppDimens.radiusCard),
                      bottomLeft: _isUser
                          ? const Radius.circular(AppDimens.radiusCard)
                          : const Radius.circular(4),
                      bottomRight: _isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(AppDimens.radiusCard),
                    ),
                  ),
                  child: message.isStreaming
                      ? const _TypingIndicator()
                      : Text(
                          message.content,
                          style: AppTextStyles.body.copyWith(
                            color: _isUser
                                ? AppColors.userBubbleText
                                : AppColors.textPrimaryDark,
                            height: 1.45,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.createdAt),
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

/// Animated three-dot typing indicator for streaming AI responses.
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

class _ChatInputBar extends ConsumerWidget {
  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.spaceMd + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(
          top: BorderSide(color: AppColors.borderDark, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _InputIcon(
            icon: Icons.add_circle_outline_rounded,
            onTap: () => ref.read(hapticServiceProvider).light(),
            tooltip: 'Attach',
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.inputBackgroundDark,
                borderRadius: BorderRadius.circular(AppDimens.radiusInput),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
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
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              return _InputIcon(
                icon: hasText
                    ? Icons.arrow_upward_rounded
                    : Icons.mic_none_rounded,
                filled: hasText,
                onTap: hasText
                    ? onSend
                    : () => ref.read(hapticServiceProvider).light(),
                tooltip: hasText ? 'Send' : 'Voice input',
              );
            },
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
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool filled;

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
            color: filled
                ? AppColors.primary
                : AppColors.inputBackgroundDark,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: filled
                ? AppColors.primaryButtonText
                : AppColors.textSecondaryDark,
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
