/// Trends Home Screen — Tab 4 (Trends) root screen.
///
/// AI-surfaced correlation cards and a time-machine strip for browsing
/// historical summaries week-by-week or month-by-month.
///
/// Full implementation: Phase 7, Task 7.1.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Trends Home screen — Phase 7 placeholder.
class TrendsHomeScreen extends StatelessWidget {
  /// Creates the [TrendsHomeScreen].
  const TrendsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.trending_up_rounded,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text('Trends', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Correlations & patterns — Phase 7',
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
