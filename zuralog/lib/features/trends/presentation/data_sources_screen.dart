/// Data Sources Screen — pushed from Trends Home.
///
/// Read-only data provenance screen: per-integration cards showing name,
/// icon, connection status, last sync timestamp, staleness indicator,
/// data types contributed, and a reconnect button for error-state integrations.
///
/// Full implementation: Phase 7, Task 7.4.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Data Sources screen — Phase 7 placeholder.
class DataSourcesScreen extends StatelessWidget {
  /// Creates the [DataSourcesScreen].
  const DataSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Sources')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.source_rounded, size: 48),
            const SizedBox(height: 16),
            Text('Data Sources', style: AppTextStyles.h2),
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
