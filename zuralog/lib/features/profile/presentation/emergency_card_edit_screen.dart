/// Emergency Health Card Edit Screen.
///
/// Edit blood type, allergies, medications, conditions, emergency contacts.
/// Full implementation: Phase 8.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Emergency Health Card edit screen — Phase 8 placeholder.
class EmergencyCardEditScreen extends StatelessWidget {
  /// Creates the [EmergencyCardEditScreen].
  const EmergencyCardEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Emergency Card')),
      body: Center(
        child: Text(
          'Emergency Card Edit\nPhase 8',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}
