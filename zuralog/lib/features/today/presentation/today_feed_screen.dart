/// Today Feed — Tab 0 root screen.
///
/// Curated daily briefing: Health Score hero, AI insight cards, wellness
/// check-in, contextual quick actions, streak badge, and Quick Log FAB.
///
/// Full implementation: Phase 3, Task 3.1.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Today Feed screen — Phase 3 placeholder.
///
/// Displays the skeleton scaffold for the Today tab. The full implementation
/// with Health Score widget, AI insight cards, and quick actions is built in
/// Phase 3.
class TodayFeedScreen extends StatelessWidget {
  /// Creates the [TodayFeedScreen].
  const TodayFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wb_sunny_rounded,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Today',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 8),
            Text(
              'Daily briefing — Phase 3',
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
