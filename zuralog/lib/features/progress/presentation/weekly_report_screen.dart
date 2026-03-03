/// Weekly Report Screen — pushed from Progress Home.
///
/// Story-style swipeable card sequence (PageView): Week Summary → Top Metrics
/// → Streaks & Goals → AI Highlights → Areas for Improvement → Next Week Focus.
/// Shareable as an image.
///
/// Full implementation: Phase 6, Task 6.5.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Weekly Report screen — Phase 6 placeholder.
class WeeklyReportScreen extends StatelessWidget {
  /// Creates the [WeeklyReportScreen].
  const WeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Report')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 48),
            const SizedBox(height: 16),
            Text('Weekly Report', style: AppTextStyles.h2),
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
