/// Coach Settings Screen.
///
/// AI persona selector (Tough Love / Balanced / Gentle) and proactivity level.
/// Full implementation: Phase 8, Task 8.5.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Coach Settings screen — Phase 8 placeholder.
class CoachSettingsScreen extends StatelessWidget {
  /// Creates the [CoachSettingsScreen].
  const CoachSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: Center(
        child: Text(
          'Coach Settings\nPhase 8',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}
