/// Coach Tab — Scrollable message list.
///
/// Renders the conversation thread. Each item is:
///   - [MessageRole.user]      → CoachUserMessage (right-aligned bubble)
///   - [MessageRole.assistant] → CoachAiResponse (full-width 4-layer block)
///   - [MessageRole.system]    → CoachArtifactCard (inline action card)
///
/// A "Zura did this" divider is injected before the first artifact in each
/// consecutive group of system messages.
///
/// A scroll-to-bottom FAB appears when the user has scrolled up more than
/// 80px from the bottom.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/coach/domain/coach_models.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_ai_response.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_artifact_card.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_user_message.dart';

class CoachMessageList extends StatefulWidget {
  const CoachMessageList({
    super.key,
    required this.messages,
    required this.isStreaming,
    required this.isThinking,
    this.thinkingContent,
    this.activeToolName,
    this.onEditMessage,
    this.onCopyMessage,
    this.onThumbUp,
    this.onThumbDown,
    this.onRedo,
    this.bottomPadding = 0.0,
  });

  final List<ChatMessage> messages;
  final bool isStreaming;
  final bool isThinking;
  final String? thinkingContent;
  final String? activeToolName;

  /// Extra bottom padding added to the scroll list so the last message is
  /// never hidden behind the floating input pill.
  final double bottomPadding;

  /// Called when the user taps "Edit" on a user bubble.
  /// Receives the message index so the caller can pre-fill the input.
  final void Function(int index)? onEditMessage;

  final void Function(String content)? onCopyMessage;
  final void Function(int index)? onThumbUp;
  final void Function(int index)? onThumbDown;
  final VoidCallback? onRedo;

  @override
  State<CoachMessageList> createState() => _CoachMessageListState();
}

class _CoachMessageListState extends State<CoachMessageList> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final distanceFromBottom = _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    final shouldShow = distanceFromBottom > 80;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(CoachMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll when new messages arrive while user is near the bottom.
    if (widget.messages.length != oldWidget.messages.length ||
        widget.isStreaming) {
      if (!_showScrollToBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final lastAssistantIndex = List.generate(widget.messages.length, (i) => i)
        .lastWhere(
          (i) => widget.messages[i].role == MessageRole.assistant,
          orElse: () => -1,
        );
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceMd + widget.bottomPadding,
          ),
          itemCount: widget.messages.length,
          itemBuilder: (context, index) {
            final message = widget.messages[index];
            return _buildItem(index, message, lastAssistantIndex: lastAssistantIndex);
          },
        ),
        if (_showScrollToBottom)
          Positioned(
            bottom: widget.bottomPadding + AppDimens.spaceSm,
            right: AppDimens.spaceMd,
            child: FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: colors.surface,
              foregroundColor: colors.textSecondary,
              elevation: 2,
              child: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
      ],
    );
  }

  Widget _buildItem(int index, ChatMessage message, {required int lastAssistantIndex}) {
    switch (message.role) {
      case MessageRole.user:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
          child: CoachUserMessage(
            content: message.content,
            attachmentUrls: message.attachmentUrls,
            onEdit: () => widget.onEditMessage?.call(index),
          ),
        );

      case MessageRole.assistant:
        // isLast scopes thinking/streaming props to the final persisted message.
        // During active thinking/streaming, a synthetic placeholder row sits
        // after this index (built in coach_screen._buildMessages), so these
        // props evaluate to null for every row while Layer 0 is visible.
        final isLast = index == widget.messages.length - 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
          child: CoachAiResponse(
            content: message.content,
            isStreaming: isLast && widget.isStreaming,
            isThinking: isLast && widget.isThinking,
            thinkingContent: isLast ? widget.thinkingContent : null,
            activeToolName: isLast ? widget.activeToolName : null,
            showFooter: index == lastAssistantIndex,
            onCopy: () => widget.onCopyMessage?.call(message.content),
            onThumbUp: () => widget.onThumbUp?.call(index),
            onThumbDown: () => widget.onThumbDown?.call(index),
            onRedo: () => widget.onRedo?.call(),
            modelUsed: message.modelUsed,
          ),
        );

      case MessageRole.system:
        // Inject "Zura did this" divider before the first card in a
        // consecutive group of system messages.
        final isFirstInGroup = index == 0 ||
            widget.messages[index - 1].role != MessageRole.system;
        final artifactType = artifactTypeFromContent(message.content);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isFirstInGroup) const CoachArtifactDivider(),
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
              child: CoachArtifactCard(
                type: artifactType,
                description: message.content,
              ),
            ),
          ],
        );
    }
  }
}
