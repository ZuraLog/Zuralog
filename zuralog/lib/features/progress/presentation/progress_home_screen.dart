/// Progress Home Screen — Tab 3 (Progress) root screen.
///
/// Displays active goals with progress rings, current streaks, week-over-week
/// comparison summary, and navigation to Goals, Achievements, Report, Journal.
///
/// Full implementation: Phase 6, Task 6.1.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/profile_avatar_button.dart';

/// Progress Home screen — Phase 6 placeholder.
class ProgressHomeScreen extends ConsumerWidget {
  /// Creates the [ProgressHomeScreen].
  const ProgressHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: AppDimens.spaceMd),
            child: ProfileAvatarButton(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.track_changes_rounded,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text('Progress', style: AppTextStyles.h2),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Goals, streaks & achievements — Phase 6',
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
