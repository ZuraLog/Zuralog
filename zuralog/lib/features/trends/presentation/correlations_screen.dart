/// Correlations Screen — pushed from Trends Home.
///
/// Interactive correlation explorer: two-metric picker, scatter plot with
/// trend line, Pearson correlation coefficient, lag support selector,
/// and AI plain-language annotation.
///
/// Full implementation: Phase 7, Task 7.2.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Correlations screen — Phase 7 placeholder.
class CorrelationsScreen extends StatelessWidget {
  /// Creates the [CorrelationsScreen].
  const CorrelationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Correlations')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.scatter_plot_rounded, size: 48),
            const SizedBox(height: 16),
            Text('Correlations', style: AppTextStyles.h2),
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
