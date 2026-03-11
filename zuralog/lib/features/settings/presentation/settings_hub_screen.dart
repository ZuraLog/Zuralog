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
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';

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
                  color: AppColors.textPrimaryDark,
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
                _SettingsTile(
                  icon: Icons.person_rounded,
                  iconColor: AppColors.categoryWellness,
                  title: 'Account',
                  subtitle: 'Email, password, linked accounts',
                  onTap: () => openSection('Account', RouteNames.settingsAccountPath),
                ),
                _SettingsTile(
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
                _SettingsTile(
                  icon: Icons.notifications_rounded,
                  iconColor: AppColors.categoryHeart,
                  title: 'Notifications',
                  subtitle: 'Reminders, briefings, quiet hours',
                  onTap: () =>
                      openSection('Notifications', RouteNames.settingsNotificationsPath),
                ),
                _SettingsTile(
                  icon: Icons.palette_rounded,
                  iconColor: AppColors.primaryDark,
                  title: 'Appearance',
                  subtitle: 'Theme, haptics, tooltips',
                  onTap: () => openSection('Appearance', RouteNames.settingsAppearancePath),
                ),
                _SettingsTile(
                  icon: Icons.psychology_rounded,
                  iconColor: AppColors.categorySleep,
                  title: 'Coach',
                  subtitle: 'AI persona, proactivity level',
                  onTap: () => openSection('Coach', RouteNames.settingsCoachPath),
                ),
              ],
            ),
          ),

          // ── Section 3: Data & Integrations ───────────────────────────────
          _SectionHeader(title: 'Data & Privacy'),

          SliverToBoxAdapter(
            child: _SettingsGroup(
              tiles: [
                _SettingsTile(
                  icon: Icons.extension_rounded,
                  iconColor: AppColors.categoryActivity,
                  title: 'Integrations',
                  subtitle: 'Connected apps and services',
                  onTap: () =>
                      openSection('Integrations', RouteNames.settingsIntegrationsPath),
                ),
                _SettingsTile(
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
                _SettingsTile(
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

  final List<_SettingsTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
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
                    color: AppColors.borderDark.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── _SettingsTile ─────────────────────────────────────────────────────────────

/// Premium settings tile — icon badge, title, subtitle, tap animation, chevron.
class _SettingsTile extends StatefulWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _pressed
            ? AppColors.borderDark.withValues(alpha: 0.3)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: 14,
        ),
        child: Row(
          children: [
            // Color icon badge.
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Icon(
                widget.icon,
                size: 20,
                color: widget.iconColor,
              ),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            // Title + subtitle.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Trailing chevron.
            Icon(
              Icons.chevron_right_rounded,
              size: AppDimens.iconMd,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
