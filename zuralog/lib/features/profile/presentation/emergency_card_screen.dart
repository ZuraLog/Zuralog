/// Emergency Health Card Screen.
///
/// Read-only view of blood type, allergies, medications, conditions,
/// and emergency contacts. Full implementation: Phase 8.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Emergency Health Card screen — Phase 8 placeholder.
class EmergencyCardScreen extends StatelessWidget {
  /// Creates the [EmergencyCardScreen].
  const EmergencyCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Card'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.push(RouteNames.emergencyCardEditPath),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Emergency Health Card\nPhase 8',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}
