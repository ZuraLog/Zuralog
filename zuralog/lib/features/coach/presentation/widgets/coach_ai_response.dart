/// Coach Tab — AI Response Block.
///
/// Renders the 4-layer anatomy for every assistant message:
///   Layer 0: Thinking strip (shown while isThinking, hidden when stream ends)
///   Layer 1: Response text (full-width markdown, streams in token by token)
///   Layer 2: Action row (Copy · 👍 · 👎 · Redo — only after stream ends)
///   Layer 3: Footer (small blob + disclaimer)
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_blob.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_thinking_layer.dart';

/// Full-width AI response block with 4 optional layers.
///
/// - [content] is the accumulated markdown text (may be partial while streaming).
/// - [isStreaming] hides the action row and keeps the blob in talking/thinking state.
/// - [isThinking] shows Layer 0 (thinking strip) and suppresses text.
class CoachAiResponse extends StatelessWidget {
  const CoachAiResponse({
    super.key,
    required this.content,
    required this.isStreaming,
    required this.isThinking,
    required this.onCopy,
    required this.onThumbUp,
    required this.onThumbDown,
    required this.onRedo,
    this.thinkingSteps = const [],
  });

  final String content;
  final bool isStreaming;
  final bool isThinking;
  final VoidCallback onCopy;
  final VoidCallback onThumbUp;
  final VoidCallback onThumbDown;
  final VoidCallback onRedo;
  final List<String> thinkingSteps;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final blobState = isThinking
        ? BlobState.thinking
        : isStreaming
            ? BlobState.talking
            : BlobState.idle;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Layer 0: Thinking ─────────────────────────────────────────
          if (isThinking)
            CoachThinkingLayer(steps: thinkingSteps),

          // ── Layer 1: Response text ────────────────────────────────────
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
              child: MarkdownBody(
                data: content,
                styleSheet: MarkdownStyleSheet(
                  p: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                  code: AppTextStyles.bodySmall.copyWith(
                    color: colors.textPrimary,
                    backgroundColor: colors.surfaceRaised,
                    fontFamily: 'monospace',
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  blockquote: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                selectable: true,
              ),
            ),

          // ── Layer 2: Action row (only after streaming ends) ───────────
          if (!isStreaming && content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    icon: Icons.copy_outlined,
                    tooltip: 'Copy',
                    onTap: onCopy,
                  ),
                  _ActionButton(
                    icon: Icons.thumb_up_outlined,
                    tooltip: 'Helpful',
                    onTap: onThumbUp,
                  ),
                  _ActionButton(
                    icon: Icons.thumb_down_outlined,
                    tooltip: 'Not helpful',
                    onTap: onThumbDown,
                  ),
                  _ActionButton(
                    icon: Icons.replay_rounded,
                    tooltip: 'Redo',
                    onTap: onRedo,
                  ),
                ],
              ),
            ),

          // ── Layer 3: Footer ───────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CoachBlob(state: blobState, size: 28),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Text(
                  'AI can make mistakes. Please double-check responses.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      iconSize: AppDimens.iconSm,
      color: colors.textSecondary,
      tooltip: tooltip,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceXs,
        vertical: AppDimens.spaceXs,
      ),
      constraints: const BoxConstraints(),
      style: const ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
