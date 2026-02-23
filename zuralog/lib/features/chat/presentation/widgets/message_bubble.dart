/// Zuralog Edge Agent — Message Bubble Widget.
///
/// Renders a single chat message as a styled bubble. User messages appear
/// right-aligned with a sage-green background; AI messages appear left-aligned
/// with a muted surface background and include a bot avatar. AI message text
/// is rendered via [MarkdownBody] to support rich formatting. When the message
/// carries a [ChatMessage.clientAction], a [DeepLinkCard] is rendered instead
/// of the text bubble.
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/chat/domain/message.dart';
import 'package:zuralog/features/chat/presentation/widgets/deep_link_card.dart';

// ── Message Bubble ────────────────────────────────────────────────────────────

/// A single chat message bubble.
///
/// Renders differently based on [message.role]:
/// - `'user'` — right-aligned, sage-green bubble with dark text.
/// - `'assistant'` / `'system'` / `'tool'` — left-aligned, muted bubble with
///   a bot avatar circle, markdown-rendered text.
///
/// When [message.clientAction] is non-null, a [DeepLinkCard] is shown in place
/// of the normal text bubble.
class MessageBubble extends StatelessWidget {
  /// The chat message to render.
  final ChatMessage message;

  /// Creates a [MessageBubble] for the given [message].
  const MessageBubble({super.key, required this.message});

  /// Whether this message was sent by the user.
  bool get _isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      child: Row(
        mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bot avatar for AI messages (appears to the left of the bubble).
          if (!_isUser) ...[
            _BotAvatar(),
            const SizedBox(width: AppDimens.spaceSm),
          ],

          // The bubble or deep-link card.
          Flexible(
            child: Column(
              crossAxisAlignment: _isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Content: either a DeepLinkCard or a text bubble.
                if (message.clientAction != null)
                  DeepLinkCard(clientAction: message.clientAction!)
                else
                  _BubbleBody(message: message, isUser: _isUser),

                // Timestamp.
                const SizedBox(height: AppDimens.spaceXs),
                _Timestamp(createdAt: message.createdAt),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bubble Body ───────────────────────────────────────────────────────────────

/// The actual bubble container with text content.
///
/// [isUser] controls color scheme and corner-radius treatment.
/// AI messages use [MarkdownBody] for rich text rendering.
class _BubbleBody extends StatelessWidget {
  const _BubbleBody({required this.message, required this.isUser});

  /// The message whose content is rendered.
  final ChatMessage message;

  /// Whether this bubble belongs to the user.
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final Color bubbleColor;
    final Color textColor;
    final BorderRadius borderRadius;

    if (isUser) {
      bubbleColor = AppColors.primary;
      textColor = AppColors.userBubbleText;
      // User: bottom-right corner flat (4), others 20.
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(4),
      );
    } else {
      bubbleColor = isDark ? AppColors.aiBubbleDark : AppColors.aiBubbleLight;
      textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
      // AI: bottom-left corner flat (4), others 20.
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(20),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm + 2,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: borderRadius,
      ),
      child: isUser
          ? Text(
              message.content,
              style: AppTextStyles.body.copyWith(color: textColor),
            )
          : MarkdownBody(
              data: message.content,
              styleSheet: MarkdownStyleSheet.fromTheme(
                Theme.of(context).copyWith(
                  textTheme: Theme.of(context).textTheme.apply(
                        bodyColor: textColor,
                        displayColor: textColor,
                      ),
                ),
              ).copyWith(
                p: AppTextStyles.body.copyWith(color: textColor),
                strong: AppTextStyles.body.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
                em: AppTextStyles.body.copyWith(
                  color: textColor,
                  fontStyle: FontStyle.italic,
                ),
                code: AppTextStyles.caption.copyWith(
                  color: textColor,
                  backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
                  fontFamily: 'monospace',
                ),
              ),
            ),
    );
  }
}

// ── Timestamp ─────────────────────────────────────────────────────────────────

/// Renders a muted small timestamp below a message bubble.
///
/// [createdAt] is formatted as HH:mm.
class _Timestamp extends StatelessWidget {
  const _Timestamp({required this.createdAt});

  /// The message creation time to display.
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');

    return Text(
      '$hour:$minute',
      style: AppTextStyles.caption.copyWith(
        color: AppColors.textSecondary,
        fontSize: 11,
      ),
    );
  }
}

// ── Bot Avatar ────────────────────────────────────────────────────────────────

/// Small circular avatar representing the AI coach.
class _BotAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
      child: const Icon(
        Icons.psychology_rounded,
        color: AppColors.primary,
        size: 16,
      ),
    );
  }
}
