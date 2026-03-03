/// About Screen.
///
/// Version info, licenses, support links.
/// Full implementation: Phase 8, Task 8.9.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// About screen — Phase 8 placeholder.
class AboutScreen extends StatelessWidget {
  /// Creates the [AboutScreen].
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: Text(
          'About\nPhase 8',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}
