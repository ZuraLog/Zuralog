/// Settings Hub Screen — top-level settings navigation menu.
///
/// Entry point for all settings: Account, Notifications, Appearance, Coach,
/// Integrations, Privacy & Data, Subscription, About. Pushed from gear icon
/// in Profile or screen header.
///
/// Full implementation: Phase 8, Task 8.1.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/settings/presentation/widgets/settings_section_label.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Settings Hub — the top-level settings navigation screen.
///
/// Provides a grouped list of all setting categories. Each row uses a
/// category-color icon badge, title, subtitle, and trailing chevron.
///
/// Design: editorial / premium Apple-Settings-caliber layout with
/// section groupings and a fixed app bar.
class SettingsHubScreen extends ConsumerWidget {
  /// Creates the [SettingsHubScreen].
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    void openSection(String title, String path) {
      ref.read(analyticsServiceProvider).capture(
        event: AnalyticsEvents.settingsSectionOpened,
        properties: {'section': title.toLowerCase()},
      );
      context.push(path);
    }

    return ZuralogScaffold(
      appBar: const ZuralogAppBar(title: 'Settings', showProfileAvatar: false),
      body: ListView(
        children: [
          // ── Section 1: Account & Profile ──────────────────────────────
          const SettingsSectionLabel('Account'),

          ZSettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.person_rounded,
                iconColor: AppColors.categoryWellness,
                title: 'Account',
                subtitle: 'Email, password, linked accounts',
                onTap: () => openSection('Account', RouteNames.settingsAccountPath),
              ),
              ZSettingsTile(
                icon: Icons.workspace_premium_rounded,
                iconColor: AppColors.categoryNutrition,
                title: 'Subscription',
                subtitle: 'Plan, billing, restore purchases',
                onTap: () => openSection('Subscription', RouteNames.settingsSubscriptionPath),
              ),
            ],
          ),

          // ── Section 2: Experience ──────────────────────────────────────
          const SettingsSectionLabel('Experience'),

          ZSettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.notifications_rounded,
                iconColor: AppColors.categoryHeart,
                title: 'Notifications',
                subtitle: 'Reminders, briefings, quiet hours',
                onTap: () => openSection('Notifications', RouteNames.settingsNotificationsPath),
              ),
              ZSettingsTile(
                icon: Icons.palette_rounded,
                iconColor: colors.primary,
                title: 'Appearance',
                subtitle: 'Theme, haptics, tooltips',
                onTap: () => openSection('Appearance', RouteNames.settingsAppearancePath),
              ),
              ZSettingsTile(
                icon: Icons.psychology_rounded,
                iconColor: AppColors.categorySleep,
                title: 'Coach',
                subtitle: 'AI persona, proactivity level',
                onTap: () => openSection('Coach', RouteNames.settingsCoachPath),
              ),
              ZSettingsTile(
                icon: Icons.book_outlined,
                iconColor: AppColors.categoryActivity,
                title: 'Journal',
                subtitle: 'Default mode when tapping Write',
                onTap: () => openSection('Journal', RouteNames.settingsJournalPath),
              ),
            ],
          ),

          // ── Section 3: Data & Privacy ──────────────────────────────────
          const SettingsSectionLabel('Data & Privacy'),

          ZSettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.extension_rounded,
                iconColor: AppColors.categoryActivity,
                title: 'Integrations',
                subtitle: 'Connected apps and services',
                onTap: () => openSection('Integrations', RouteNames.settingsIntegrationsPath),
              ),
              ZSettingsTile(
                icon: Icons.lock_rounded,
                iconColor: AppColors.categoryVitals,
                title: 'Privacy & Data',
                subtitle: 'AI memory, data export, analytics',
                onTap: () => openSection('Privacy & Data', RouteNames.settingsPrivacyPath),
              ),
            ],
          ),

          // ── Section 4: About ───────────────────────────────────────────
          const SettingsSectionLabel('About'),

          ZSettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.info_rounded,
                iconColor: AppColors.categoryBody,
                title: 'About ZuraLog',
                subtitle: 'Version, licenses, support',
                onTap: () => openSection('About ZuraLog', RouteNames.settingsAboutPath),
              ),
            ],
          ),

          // ── Developer Tools (debug builds only) ───────────────────────
          if (kDebugMode) ...[
            const SettingsSectionLabel('Developer'),

            ZSettingsGroup(
              tiles: [
                ZSettingsTile(
                  icon: Icons.grid_view_rounded,
                  iconColor: colors.primary,
                  title: 'Component Showcase',
                  subtitle: 'View every design system component',
                  onTap: () => context.push(RouteNames.componentShowcasePath),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppDimens.spaceXxl),
        ],
      ),
    );
  }
}
