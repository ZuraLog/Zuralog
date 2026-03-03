/// Achievements Screen — pushed from Progress Home.
///
/// Badge gallery grouped by category (Getting Started, Consistency, Goals,
/// Data, Coach, Health). Locked/unlocked states with dates. Unlock animation.
///
/// Full implementation: Phase 6, Task 6.4.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Achievements screen — Phase 6 placeholder.
class AchievementsScreen extends StatelessWidget {
  /// Creates the [AchievementsScreen].
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded, size: 48),
            const SizedBox(height: 16),
            Text('Achievements', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Full implementation in Phase 6',
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
