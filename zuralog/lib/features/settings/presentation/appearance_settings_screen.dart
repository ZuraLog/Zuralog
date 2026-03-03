/// Appearance Settings Screen.
///
/// Theme selector, haptic toggle, tooltip reset/disable.
/// Full implementation: Phase 8, Task 8.4.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Appearance Settings screen — Phase 8 placeholder.
class AppearanceSettingsScreen extends StatelessWidget {
  /// Creates the [AppearanceSettingsScreen].
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: Center(
        child: Text(
          'Appearance Settings\nPhase 8',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}
