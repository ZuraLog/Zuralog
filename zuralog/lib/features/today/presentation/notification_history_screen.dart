/// Notification History Screen — pushed from Today header bell icon.
///
/// Scrollable list of all past push notifications grouped by day.
/// Tapping a notification deep-links to the relevant insight or metric.
///
/// Full implementation: Phase 3, Task 3.3.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Notification History screen — Phase 3 placeholder.
class NotificationHistoryScreen extends StatelessWidget {
  /// Creates the [NotificationHistoryScreen].
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_outlined, size: 48),
            const SizedBox(height: 16),
            Text('Notification History', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Full implementation in Phase 3',
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
