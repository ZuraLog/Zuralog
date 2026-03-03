/// Notification Settings Screen.
///
/// Morning briefing, smart reminders, quiet hours, per-category toggles.
/// Full implementation: Phase 8, Task 8.3.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Notification Settings screen — Phase 8 placeholder.
class NotificationSettingsScreen extends StatelessWidget {
  /// Creates the [NotificationSettingsScreen].
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Center(
        child: Text(
          'Notification Settings\nPhase 8',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}
