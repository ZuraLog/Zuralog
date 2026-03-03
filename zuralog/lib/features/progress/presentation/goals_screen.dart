/// Goals Screen — pushed from Progress Home.
///
/// Full goal management: create, edit, delete goals. Each goal shows a
/// progress ring, deadline, trend line, and AI commentary.
///
/// Full implementation: Phase 6, Task 6.2.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Goals screen — Phase 6 placeholder.
class GoalsScreen extends StatelessWidget {
  /// Creates the [GoalsScreen].
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_rounded, size: 48),
            const SizedBox(height: 16),
            Text('Goals', style: AppTextStyles.h2),
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
