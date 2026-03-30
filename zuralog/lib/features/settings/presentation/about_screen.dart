/// About Screen.
///
/// App version, support links, community, legal pages, open-source licenses.
/// Full implementation: Phase 8, Task 8.9.
library;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/settings/presentation/widgets/settings_section_label.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── AboutScreen ───────────────────────────────────────────────────────────────

/// About screen — app identity, support links, legal pages, open-source licenses.
class AboutScreen extends StatefulWidget {
  /// Creates the [AboutScreen].
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '...';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          _version = 'Version ${info.version} (Build ${info.buildNumber})';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogScaffold(
      appBar: const ZuralogAppBar(title: 'About ZuraLog', showProfileAvatar: false),
      body: ListView(
        children: [
          const SizedBox(height: AppDimens.spaceLg),
          _AppIdentityHero(version: _version),
          const SizedBox(height: AppDimens.spaceXl),

          const SettingsSectionLabel('SUPPORT'),
          ZSettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.help_rounded,
                iconColor: AppColors.categoryBody,
                title: 'Help Center',
                subtitle: 'FAQs, guides, and tutorials',
                onTap: () => _showSnackBar(context, 'Opening Help Center'),
              ),
              ZSettingsTile(
                icon: Icons.mail_rounded,
                iconColor: colors.primary,
                title: 'Contact Support',
                subtitle: 'support@zuralog.com',
                onTap: () => _showSnackBar(context, 'Opening email\u2026'),
              ),
              ZSettingsTile(
                icon: Icons.people_rounded,
                iconColor: AppColors.categorySleep,
                title: 'Community',
                subtitle: 'Join the ZuraLog community',
                onTap: () => _showSnackBar(context, 'Opening community\u2026'),
              ),
            ],
          ),

          const SettingsSectionLabel('LEGAL'),
          ZSettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.policy_rounded,
                iconColor: AppColors.categoryVitals,
                title: 'Privacy Policy',
                onTap: () => launchUrl(Uri.parse('https://www.zuralog.com/privacy-policy'), mode: LaunchMode.externalApplication),
              ),
              ZSettingsTile(
                icon: Icons.description_rounded,
                iconColor: AppColors.categoryWellness,
                title: 'Terms of Service',
                onTap: () => launchUrl(Uri.parse('https://www.zuralog.com/terms-of-service'), mode: LaunchMode.externalApplication),
              ),
              ZSettingsTile(
                icon: Icons.gavel_rounded,
                iconColor: colors.textTertiary,
                title: 'Open-Source Licenses',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'ZuraLog',
                  applicationVersion: _version,
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
  const _AppIdentityHero({required this.version});

  final String version;

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

          // Version string — loaded from PackageInfo.fromPlatform(); shows '...' until ready
          Text(
            version,
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
        // 14×6 — intentional tight chip padding; no AppDimens token matches these values
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

// ── Helpers ────────────────────────────────────────────────────────────────────

// Called synchronously from onTap — context is always valid here.
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
