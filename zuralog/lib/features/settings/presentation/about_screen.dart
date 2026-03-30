/// About Screen.
///
/// App version, support links, community, legal pages, open-source licenses.
/// Full implementation: Phase 8, Task 8.9.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── AboutScreen ───────────────────────────────────────────────────────────────

/// About screen — app identity, support links, legal pages, open-source licenses.
class AboutScreen extends StatelessWidget {
  /// Creates the [AboutScreen].
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogScaffold(
      appBar: const ZuralogAppBar(title: 'About ZuraLog', showProfileAvatar: false),
      body: ListView(
        children: [
          const SizedBox(height: AppDimens.spaceLg),
          const _AppIdentityHero(),
          const SizedBox(height: AppDimens.spaceXl),

          const _SectionHeader('SUPPORT'),
          _SettingsGroup(
            children: [
              ZSettingsTile(
                icon: Icons.help_rounded,
                iconColor: AppColors.categoryBody,
                title: 'Help Center',
                subtitle: 'FAQs, guides, and tutorials',
                onTap: () => _showSnackBar(context, 'Opening Help Center'),
              ),
              const _Divider(),
              ZSettingsTile(
                icon: Icons.mail_rounded,
                iconColor: colors.primary,
                title: 'Contact Support',
                subtitle: 'support@zuralog.com',
                onTap: () => _showSnackBar(context, 'Opening email\u2026'),
              ),
              const _Divider(),
              ZSettingsTile(
                icon: Icons.people_rounded,
                iconColor: AppColors.categorySleep,
                title: 'Community',
                subtitle: 'Join the ZuraLog community',
                onTap: () => _showSnackBar(context, 'Opening community\u2026'),
              ),
            ],
          ),

          const _SectionHeader('LEGAL'),
          _SettingsGroup(
            children: [
              ZSettingsTile(
                icon: Icons.policy_rounded,
                iconColor: AppColors.categoryVitals,
                title: 'Privacy Policy',
                onTap: () => context.pushNamed(RouteNames.settingsPrivacyPolicy),
              ),
              const _Divider(),
              ZSettingsTile(
                icon: Icons.description_rounded,
                iconColor: AppColors.categoryWellness,
                title: 'Terms of Service',
                onTap: () => context.pushNamed(RouteNames.settingsTerms),
              ),
              const _Divider(),
              ZSettingsTile(
                icon: Icons.gavel_rounded,
                iconColor: colors.textTertiary,
                title: 'Open-Source Licenses',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'ZuraLog',
                  applicationVersion: '1.0.0',
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceXl,
            ),
            child: Column(
              children: [
                Text(
                  'Made with \u2764\ufe0f for your health journey',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  '\u00a9 2026 ZuraLog. All rights reserved.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _AppIdentityHero ───────────────────────────────────────────────────────────

class _AppIdentityHero extends StatelessWidget {
  const _AppIdentityHero();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App icon placeholder
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.monitor_heart_rounded,
              size: 44,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // App name
          Text(
            'ZuraLog',
            style: AppTextStyles.displayLarge.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppDimens.spaceXs),

          // Version string
          Text(
            'Version 1.0.0 (Build 42)',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // What's New chip
          const _WhatsNewChip(),
        ],
      ),
    );
  }
}

// ── _WhatsNewChip ──────────────────────────────────────────────────────────────

class _WhatsNewChip extends StatelessWidget {
  const _WhatsNewChip();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogSpringButton(
      onTap: () => _showSnackBar(context, "What's New in 1.0.0"),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 13,
              color: colors.primary,
            ),
            const SizedBox(width: AppDimens.spaceXs),
            Text(
              "What's New",
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _SectionHeader ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceXs,
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: colors.textTertiary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── _SettingsGroup ─────────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(children: children),
      ),
    );
  }
}

// ── _Divider ───────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Container(
        height: 1,
        color: colors.border.withValues(alpha: 0.5),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

void _showSnackBar(BuildContext context, String message) {
  final colors = AppColorsOf(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
          color: colors.textPrimary,
        ),
      ),
      backgroundColor: colors.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}
