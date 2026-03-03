/// Journal / Daily Log Screen — pushed from Progress Home.
///
/// Daily reflection: mood slider (1-10), energy, stress, sleep quality,
/// text notes, context tags. Calendar/date-list view of past entries.
///
/// Full implementation: Phase 6, Task 6.6.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Journal screen — Phase 6 placeholder.
class JournalScreen extends StatelessWidget {
  /// Creates the [JournalScreen].
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.book_outlined, size: 48),
            const SizedBox(height: 16),
            Text('Daily Journal', style: AppTextStyles.h2),
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
