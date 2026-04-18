// zuralog/lib/features/sleep/presentation/sleep_detail_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';

class SleepDetailScreen extends StatelessWidget {
  const SleepDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: const Text('Sleep'),
      ),
      body: const Center(child: Text('Sleep detail — coming in Phase 1b')),
    );
  }
}
