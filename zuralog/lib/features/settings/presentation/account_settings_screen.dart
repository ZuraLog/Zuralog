/// Account Settings Screen — pushed from Settings Hub.
///
/// Email display, password change, linked social accounts, goals editor,
/// Emergency Health Card link, and delete account.
///
/// Full implementation: Phase 8, Task 8.2.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Account Settings screen — Phase 8 placeholder.
class AccountSettingsScreen extends StatelessWidget {
  /// Creates the [AccountSettingsScreen].
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Center(
        child: Text(
          'Full implementation in Phase 8',
          style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
        ),
      ),
    );
  }
}
