/// Profile Screen.
///
/// User avatar, name, stats summary, and navigation to Settings/Emergency Card.
/// Pushed from avatar icon in any screen header.
/// Full implementation: Phase 8.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Profile screen — Phase 8 placeholder.
class ProfileScreen extends StatelessWidget {
  /// Creates the [ProfileScreen].
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push(RouteNames.settingsPath),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Profile\nPhase 8',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}
