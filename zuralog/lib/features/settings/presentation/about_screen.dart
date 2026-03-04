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

// ── AboutScreen ───────────────────────────────────────────────────────────────

/// About screen — app identity, support links, legal pages, open-source licenses.
class AboutScreen extends StatelessWidget {
  /// Creates the [AboutScreen].
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
          // ── Large-title app bar ─────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.backgroundDark,
            expandedHeight: 100,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: AppDimens.spaceMd,
                bottom: 14,
              ),
              collapseMode: CollapseMode.parallax,
              title: Text(
                'About',
                style:
                    AppTextStyles.h2.copyWith(color: AppColors.textPrimaryDark),
              ),
            ),
          ),

          // ── App identity hero ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppDimens.spaceLg),
              child: const _AppIdentityHero(),
            ),
          ),

          // ── Blank spacer ────────────────────────────────────────────────────
          const SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceXl)),

          // ── SUPPORT section ─────────────────────────────────────────────────
          const SliverToBoxAdapter(child: _SectionHeader('SUPPORT')),
          SliverToBoxAdapter(
            child: _SettingsGroup(
              children: [
                _TapRow(
                  icon: Icons.help_rounded,
                  iconColor: AppColors.categoryBody,
                  title: 'Help Center',
                  subtitle: 'FAQs, guides, and tutorials',
                  onTap: (ctx) => _showSnackBar(ctx, 'Opening Help Center'),
                ),
                const _Divider(),
                _TapRow(
                  icon: Icons.mail_rounded,
                  iconColor: AppColors.primary,
                  title: 'Contact Support',
                  subtitle: 'support@zuralog.com',
                  onTap: (ctx) => _showSnackBar(ctx, 'Opening email…'),
                ),
                const _Divider(),
                _TapRow(
                  icon: Icons.people_rounded,
                  iconColor: AppColors.categorySleep,
                  title: 'Community',
                  subtitle: 'Join the Zuralog community',
                  onTap: (ctx) => _showSnackBar(ctx, 'Opening community…'),
                ),
              ],
            ),
          ),

          // ── LEGAL section ───────────────────────────────────────────────────
          const SliverToBoxAdapter(child: _SectionHeader('LEGAL')),
          SliverToBoxAdapter(
            child: _SettingsGroup(
              children: [
                _TapRow(
                  icon: Icons.policy_rounded,
                  iconColor: AppColors.categoryVitals,
                  title: 'Privacy Policy',
                  onTap: (ctx) => ctx.pushNamed(RouteNames.settingsPrivacyPolicy),
                ),
                const _Divider(),
                _TapRow(
                  icon: Icons.description_rounded,
                  iconColor: AppColors.categoryWellness,
                  title: 'Terms of Service',
                  onTap: (ctx) => ctx.pushNamed(RouteNames.settingsTerms),
                ),
                const _Divider(),
                _TapRow(
                  icon: Icons.gavel_rounded,
                  iconColor: AppColors.textTertiary,
                  title: 'Open-Source Licenses',
                  onTap: (ctx) => showLicensePage(
                    context: ctx,
                    applicationName: 'Zuralog',
                    applicationVersion: '1.0.0',
                  ),
                ),
              ],
            ),
          ),

          // ── Footer ──────────────────────────────────────────────────────────
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceXl,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Made with ❤️ for your health journey',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                  Text(
                    '© 2026 Zuralog. All rights reserved.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App icon placeholder
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.monitor_heart_rounded,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // App name
          Text(
            'Zuralog',
            style: AppTextStyles.h1.copyWith(color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: AppDimens.spaceXs),

          // Version string
          Text(
            'Version 1.0.0 (Build 42)',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
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

class _WhatsNewChip extends StatefulWidget {
  const _WhatsNewChip();

  @override
  State<_WhatsNewChip> createState() => _WhatsNewChipState();
}

class _WhatsNewChipState extends State<_WhatsNewChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        _showSnackBar(context, "What's New in 1.0.0");
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 13,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppDimens.spaceXs),
            Text(
              "What's New",
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceXs,
      ),
      child: Text(
        label,
        style: AppTextStyles.labelXs.copyWith(
          color: AppColors.textTertiary,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
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
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Container(
        height: 1,
        color: AppColors.borderDark.withValues(alpha: 0.5),
      ),
    );
  }
}

// ── _TapRow ────────────────────────────────────────────────────────────────────

class _TapRow extends StatefulWidget {
  const _TapRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final void Function(BuildContext context) onTap;

  @override
  State<_TapRow> createState() => _TapRowState();
}

class _TapRowState extends State<_TapRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap(context);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.borderDark.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Icon(widget.icon, size: 20, color: widget.iconColor),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
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

// ── Helpers ────────────────────────────────────────────────────────────────────

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimaryDark,
        ),
      ),
      backgroundColor: AppColors.surfaceDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}
