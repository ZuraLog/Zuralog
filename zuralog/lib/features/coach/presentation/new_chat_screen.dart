/// New Chat Screen — Tab 2 (Coach) root screen.
///
/// Opens to a fresh empty conversation. Shows personalized suggested prompt
/// chips when empty, integration context banner, and chat input with voice
/// and attachment support. Drawer accessible via hamburger icon or swipe.
///
/// Full implementation: Phase 4, Task 4.1.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// New Chat screen — Phase 4 placeholder.
class NewChatScreen extends StatelessWidget {
  /// Creates the [NewChatScreen].
  const NewChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach'),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () {},
          tooltip: 'Conversations',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded),
            onPressed: () {},
            tooltip: 'Quick Actions',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_rounded,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text('AI Coach', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Conversational health coaching — Phase 4',
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
