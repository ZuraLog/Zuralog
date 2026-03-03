/// Reports Screen — pushed from Trends Home.
///
/// List of auto-generated monthly reports from the API. Tap to view report
/// detail: category summaries, top correlations, goal progress, AI
/// recommendations. Exportable as PDF and shareable as image.
///
/// Full implementation: Phase 7, Task 7.3.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Reports screen — Phase 7 placeholder.
class ReportsScreen extends StatelessWidget {
  /// Creates the [ReportsScreen].
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description_rounded, size: 48),
            const SizedBox(height: 16),
            Text('Monthly Reports', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Full implementation in Phase 7',
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
