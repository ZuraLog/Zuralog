/// Integrations Screen (under Settings).
///
/// Connected / Available / Coming Soon integrations. Rebuild of the existing
/// Integrations Hub, relocated under Settings. Full implementation: Phase 8, Task 8.6.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Integrations settings screen — Phase 8 placeholder.
class IntegrationsScreen extends StatelessWidget {
  /// Creates the [IntegrationsScreen].
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integrations')),
      body: Center(
        child: Text(
          'Integrations\nPhase 8',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}
