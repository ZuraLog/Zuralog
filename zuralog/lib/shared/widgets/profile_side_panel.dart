/// Zuralog — Profile Side Panel Widget.
///
/// A right-side slide-in panel rendered directly inside the [AppShell] Stack
/// as part of the push-reveal interaction.  The shell is responsible for
/// positioning and animating [ProfileSidePanelWidget] — this file only owns
/// the panel *content*.
///
/// The old `OverlayEntry`-based implementation has been removed.  Use
/// [sidePanelOpenProvider] to open/close the panel from anywhere:
/// ```dart
/// ref.read(sidePanelOpenProvider.notifier).state = true;
/// ```
///
/// Navigation destinations exposed by the panel:
///   1. Account          — navigates to Account Settings.
///   2. Notifications    — navigates to Notification Settings.
///   3. Appearance       — navigates to Appearance Settings.
///   4. Coach            — navigates to Coach Settings.
///   5. Integrations     — navigates to Integrations screen.
///   6. Privacy & Data   — navigates to Privacy & Data screen.
///   7. Subscription     — navigates to Subscription screen.
///   8. About            — navigates to About screen.
///   9. Sign Out         — logs out the current user.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Diameter of the avatar shown in the panel header.
const double _kPanelAvatarSize = 64.0;

// ── ProfileSidePanelWidget ────────────────────────────────────────────────────

/// The profile side panel surface with user info and navigation links.
///
/// This is a plain stateless widget — positioning and animation are handled
/// by [AppShell].  Pass [onClose] so the panel can request dismissal when a
/// navigation item is tapped.
///
/// The panel uses [colorScheme.surface] for its background, giving the correct
/// card-like appearance in both light and dark modes per the design system.
class ProfileSidePanelWidget extends ConsumerWidget {
  /// Callback invoked when the panel should close (e.g. after navigation).
  final VoidCallback onClose;

  /// Creates a [ProfileSidePanelWidget].
  const ProfileSidePanelWidget({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final email = ref.watch(userEmailProvider);
    final profile = ref.watch(userProfileProvider);

    final displayName = profile?.aiName ?? (email.isNotEmpty ? email : '—');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Material(
      color: cs.surface,
      elevation: 0,
      child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Panel Header: avatar + name + email ─────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceLg,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar circle
                    CircleAvatar(
                      radius: _kPanelAvatarSize / 2,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.85),
                      child: Text(
                        initial,
                        style: AppTextStyles.displaySmall.copyWith(
                          color: AppColors.primaryButtonText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    // Display name
                    Text(
                      displayName,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Email (shown only when available)
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // ── Divider ──────────────────────────────────────────────────
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),

              const SizedBox(height: AppDimens.spaceSm),

              // ── Navigation Links ─────────────────────────────────────────
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: 'Account',
                onTap: () {
                  ref.read(hapticServiceProvider).light();
                  onClose();
                  context.push(RouteNames.settingsAccountPath);
                },
              ),
              _NavItem(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                onTap: () {
                  ref.read(hapticServiceProvider).light();
                  onClose();
                  context.push(RouteNames.settingsNotificationsPath);
                },
              ),
              _NavItem(
                icon: Icons.palette_outlined,
                label: 'Appearance',
                onTap: () {
                  ref.read(hapticServiceProvider).light();
                  onClose();
                  context.push(RouteNames.settingsAppearancePath);
                },
              ),
              _NavItem(
                icon: Icons.psychology_outlined,
                label: 'Coach',
                onTap: () {
                  ref.read(hapticServiceProvider).light();
                  onClose();
                  context.push(RouteNames.settingsCoachPath);
                },
              ),
              _NavItem(
                icon: Icons.link_rounded,
                label: 'Integrations',
                onTap: () {
                  ref.read(hapticServiceProvider).light();
                  onClose();
                  context.push(RouteNames.settingsIntegrationsPath);
                },
              ),
              _NavItem(
                icon: Icons.shield_outlined,
                label: 'Privacy & Data',
                onTap: () {
                  ref.read(hapticServiceProvider).light();
                  onClose();
                  context.push(RouteNames.settingsPrivacyPath);
                },
              ),
              _NavItem(
                icon: Icons.star_outline_rounded,
                label: 'Subscription',
                onTap: () {
                  ref.read(hapticServiceProvider).light();
                  onClose();
                  context.push(RouteNames.settingsSubscriptionPath);
                },
              ),
              _NavItem(
                icon: Icons.info_outline_rounded,
                label: 'About',
                onTap: () {
                  ref.read(hapticServiceProvider).light();
                  onClose();
                  context.push(RouteNames.settingsAboutPath);
                },
              ),

              const Spacer(),

              // ── Divider ──────────────────────────────────────────────────
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),

              // ── Sign Out ─────────────────────────────────────────────────
              _NavItem(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                color: isDark ? AppColors.accentDark : AppColors.accentLight,
                onTap: () async {
                  ref.read(hapticServiceProvider).light();
                  onClose();
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) {
                    context.go(RouteNames.welcomePath);
                  }
                },
              ),

              const SizedBox(height: AppDimens.spaceMd),
            ],
          ),
        ),
      );
  }
}

// ── Nav Item ──────────────────────────────────────────────────────────────────

/// A single navigation list tile used inside [ProfileSidePanelWidget].
///
/// Renders an icon, label, and optional trailing chevron.
/// The [color] parameter can override both the icon and label colour — used
/// for destructive items like Sign Out.
class _NavItem extends StatelessWidget {
  /// The icon glyph.
  final IconData icon;

  /// The label text.
  final String label;

  /// Optional colour override for destructive items (e.g. Sign Out).
  final Color? color;

  /// Callback invoked on tap.
  final VoidCallback onTap;

  /// Creates a [_NavItem].
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.onSurface;

    return ListTile(
      leading: Icon(icon, color: effectiveColor, size: AppDimens.iconMd),
      title: Text(
        label,
        style: AppTextStyles.bodyLarge.copyWith(color: effectiveColor),
      ),
      trailing: color == null
          ? Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: AppDimens.iconSm,
            )
          : null,
      onTap: onTap,
      minLeadingWidth: AppDimens.iconMd,
    );
  }
}
