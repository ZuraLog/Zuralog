/// Metric Detail Screen — pushed from Category Detail.
///
/// Single metric deep-dive with full chart, pinch-to-zoom, data source
/// attribution, raw data table toggle, and "Ask Coach about this" action.
///
/// Full implementation: Phase 5, Task 5.3.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Metric Detail screen — Phase 5 placeholder.
class MetricDetailScreen extends StatelessWidget {
  /// Creates a [MetricDetailScreen] for the given [metricId].
  const MetricDetailScreen({super.key, required this.metricId});

  /// The metric identifier.
  final String metricId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metric')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.show_chart_rounded, size: 48),
            const SizedBox(height: 16),
            Text('Metric Detail', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Metric: $metricId',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Full implementation in Phase 5',
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
