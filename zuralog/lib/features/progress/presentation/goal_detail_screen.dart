/// Goal Detail Screen — pushed from Goals screen.
///
/// Single goal deep-dive: full progress chart over time, milestones hit,
/// projected completion date, AI commentary, and edit/delete actions.
///
/// Full implementation: Phase 6, Task 6.3.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Goal Detail screen — Phase 6 placeholder.
class GoalDetailScreen extends StatelessWidget {
  /// Creates a [GoalDetailScreen] for the given [goalId].
  const GoalDetailScreen({super.key, required this.goalId});

  /// The goal ID to display.
  final String goalId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goal')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_rounded, size: 48),
            const SizedBox(height: 16),
            Text('Goal Detail', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'ID: $goalId',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
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
