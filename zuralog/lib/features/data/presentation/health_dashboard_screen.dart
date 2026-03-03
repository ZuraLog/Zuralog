/// Health Dashboard Screen — Tab 1 (Data) root screen.
///
/// Customizable grid/list of health category cards. Users can reorder via
/// drag-and-drop and toggle visibility. Each card shows today's value and a
/// sparkline trend.
///
/// Full implementation: Phase 5, Task 5.1.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Health Dashboard screen — Phase 5 placeholder.
class HealthDashboardScreen extends StatelessWidget {
  /// Creates the [HealthDashboardScreen].
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {},
            tooltip: 'Customize',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text('Health Dashboard', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Customizable health data — Phase 5',
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
