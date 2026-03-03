/// Settings Hub Screen — top-level settings menu.
///
/// Entry point for all settings: Account, Notifications, Appearance, Coach,
/// Integrations, Privacy & Data, Subscription, About. Pushed from gear icon
/// in Profile or screen header.
///
/// Full implementation: Phase 8, Task 8.1.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Settings Hub screen — Phase 8 placeholder.
///
/// Provides minimal navigation to all settings sub-screens so that
/// the routing structure can be verified before Phase 8 builds the
/// full implementation.
class SettingsHubScreen extends StatelessWidget {
  /// Creates the [SettingsHubScreen].
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SettingsTile(
            icon: Icons.person_rounded,
            title: 'Account',
            subtitle: 'Email, password, linked accounts',
            onTap: () => context.push(RouteNames.settingsAccountPath),
          ),
          _SettingsTile(
            icon: Icons.notifications_rounded,
            title: 'Notifications',
            subtitle: 'Reminders, briefings, quiet hours',
            onTap: () => context.push(RouteNames.settingsNotificationsPath),
          ),
          _SettingsTile(
            icon: Icons.palette_rounded,
            title: 'Appearance',
            subtitle: 'Theme, haptics, tooltips',
            onTap: () => context.push(RouteNames.settingsAppearancePath),
          ),
          _SettingsTile(
            icon: Icons.psychology_rounded,
            title: 'Coach',
            subtitle: 'AI persona, proactivity level',
            onTap: () => context.push(RouteNames.settingsCoachPath),
          ),
          _SettingsTile(
            icon: Icons.extension_rounded,
            title: 'Integrations',
            subtitle: 'Connected apps and services',
            onTap: () => context.push(RouteNames.settingsIntegrationsPath),
          ),
          _SettingsTile(
            icon: Icons.lock_rounded,
            title: 'Privacy & Data',
            subtitle: 'AI memory, data export, analytics',
            onTap: () => context.push(RouteNames.settingsPrivacyPath),
          ),
          _SettingsTile(
            icon: Icons.workspace_premium_rounded,
            title: 'Subscription',
            subtitle: 'Plan, billing, restore purchases',
            onTap: () => context.push(RouteNames.settingsSubscriptionPath),
          ),
          _SettingsTile(
            icon: Icons.info_rounded,
            title: 'About',
            subtitle: 'Version, licenses, support',
            onTap: () => context.push(RouteNames.settingsAboutPath),
          ),
        ],
      ),
    );
  }
}

/// Reusable list tile for a settings navigation row.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textTertiary),
      title: Text(title, style: AppTextStyles.body),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textTertiary,
      ),
      onTap: onTap,
    );
  }
}
