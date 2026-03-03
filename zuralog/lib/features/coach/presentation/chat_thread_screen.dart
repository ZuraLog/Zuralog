/// Chat Thread Screen — pushed from Conversation Drawer.
///
/// Displays an existing conversation with full message history.
/// Streaming AI responses, voice input, markdown rendering, file attachments,
/// and in-chat confirmation cards (NL logging, food photo, memory extraction).
///
/// Full implementation: Phase 4, Task 4.3.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Chat Thread screen — Phase 4 placeholder.
class ChatThreadScreen extends StatelessWidget {
  /// Creates a [ChatThreadScreen] for the given [conversationId].
  const ChatThreadScreen({super.key, required this.conversationId});

  /// The conversation ID to load and display.
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_rounded, size: 48),
            const SizedBox(height: 16),
            Text('Chat Thread', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'ID: $conversationId',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Full implementation in Phase 4',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
