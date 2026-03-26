/// Settings Hub Screen — top-level settings navigation menu.
///
/// Entry point for all settings: Account, Notifications, Appearance, Coach,
/// Integrations, Privacy & Data, Subscription, About. Pushed from gear icon
/// in Profile or screen header.
///
/// Full implementation: Phase 8, Task 8.1.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Settings Hub — the top-level settings navigation screen.
///
/// Provides a grouped list of all setting categories. Each row uses a
/// category-color icon badge, title, subtitle, and trailing chevron.
///
/// Design: editorial / premium Apple-Settings-caliber layout with
/// section groupings and a frosted-glass header area.
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
      body: CustomScrollView(
        slivers: [
          // ── Large-title app bar ──────────────────────────────────────────
          SliverAppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            pinned: true,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: AppDimens.spaceMd,
                bottom: 16,
              ),
              title: Text(
                'Settings',
                style: AppTextStyles.displaySmall.copyWith(
                  color: colors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              collapseMode: CollapseMode.parallax,
            ),
          ),

          // ── Section 1: Account & Profile ─────────────────────────────────
          _SectionHeader(title: 'Account'),

          SliverToBoxAdapter(
            child: _SettingsGroup(
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
          ),

          // ── Section 2: Experience ────────────────────────────────────────
          _SectionHeader(title: 'Experience'),

          SliverToBoxAdapter(
            child: _SettingsGroup(
              tiles: [
                ZSettingsTile(
                  icon: Icons.notifications_rounded,
                  iconColor: AppColors.categoryHeart,
                  title: 'Notifications',
                  subtitle: 'Reminders, briefings, quiet hours',
                  onTap: () =>
                      openSection('Notifications', RouteNames.settingsNotificationsPath),
                ),
                ZSettingsTile(
                  icon: Icons.palette_rounded,
                  iconColor: colors.isDark ? AppColors.primaryDark : AppColors.primaryOnLight,
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
          ),

          // ── Section 3: Data & Integrations ───────────────────────────────
          _SectionHeader(title: 'Data & Privacy'),

          SliverToBoxAdapter(
            child: _SettingsGroup(
              tiles: [
                ZSettingsTile(
                  icon: Icons.extension_rounded,
                  iconColor: AppColors.categoryActivity,
                  title: 'Integrations',
                  subtitle: 'Connected apps and services',
                  onTap: () =>
                      openSection('Integrations', RouteNames.settingsIntegrationsPath),
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
          ),

          // ── Section 4: About ─────────────────────────────────────────────
          _SectionHeader(title: 'About'),

          SliverToBoxAdapter(
            child: _SettingsGroup(
              tiles: [
                ZSettingsTile(
                  icon: Icons.info_rounded,
                  iconColor: AppColors.categoryBody,
                  title: 'About Zuralog',
                  subtitle: 'Version, licenses, support',
                  onTap: () => openSection('About Zuralog', RouteNames.settingsAboutPath),
                ),
              ],
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimens.spaceXxl),
          ),
        ],
      ),
    );
  }
}

// ── _SectionHeader ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          AppDimens.spaceLg,
          AppDimens.spaceMd,
          AppDimens.spaceXs,
        ),
        child: Text(
          title.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── _SettingsGroup ────────────────────────────────────────────────────────────

/// Grouped container for a set of settings tiles — rounded card, no shadow.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.tiles});

  final List<ZSettingsTile> tiles;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i < tiles.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 68),
                  child: Container(
                    height: 1,
                    color: colors.border.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}


