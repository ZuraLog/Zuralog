/// Category Detail Screen — pushed from Health Dashboard.
///
/// Drill-down into a specific health category (Activity, Sleep, Heart, etc.)
/// showing all metrics within the category with fl_chart charts and a
/// time-range selector.
///
/// Full implementation: Phase 5, Task 5.2.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Category Detail screen — Phase 5 placeholder.
class CategoryDetailScreen extends StatelessWidget {
  /// Creates a [CategoryDetailScreen] for the given [categoryId].
  const CategoryDetailScreen({super.key, required this.categoryId});

  /// The category identifier (e.g. "activity", "sleep", "heart").
  final String categoryId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_displayName(categoryId)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_rounded, size: 48),
            const SizedBox(height: 16),
            Text(_displayName(categoryId), style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Category: $categoryId',
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

  String _displayName(String id) =>
      id[0].toUpperCase() + id.substring(1).replaceAll('-', ' ');
}
