/// Insight Detail Screen — pushed from Today Feed.
///
/// Full-screen explanation of a single AI insight: charts, data sources,
/// AI reasoning, and "Discuss with Coach" action.
///
/// Full implementation: Phase 3, Task 3.2.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Insight Detail screen — Phase 3 placeholder.
class InsightDetailScreen extends StatelessWidget {
  /// Creates an [InsightDetailScreen] for the given [insightId].
  const InsightDetailScreen({super.key, required this.insightId});

  /// The ID of the insight to display.
  final String insightId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insight')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lightbulb_outline_rounded, size: 48),
            const SizedBox(height: 16),
            Text('Insight Detail', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'ID: $insightId',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
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
