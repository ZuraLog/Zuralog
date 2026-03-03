/// Subscription Screen.
///
/// Current plan, upgrade/downgrade, restore purchases.
/// Full implementation: Phase 8, Task 8.8.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Subscription screen — Phase 8 placeholder.
class SubscriptionSettingsScreen extends StatelessWidget {
  /// Creates the [SubscriptionSettingsScreen].
  const SubscriptionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: Center(
        child: Text(
          'Subscription\nPhase 8',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}
