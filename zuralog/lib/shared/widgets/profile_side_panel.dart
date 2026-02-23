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
///   1. Profile — navigates to the Settings screen.
///   2. Settings — navigates to the Settings screen.
///   3. Sign Out — logs out the current user.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Diameter of the avatar shown in the panel header.
const double _kPanelAvatarSize = 64.0;

/// Corner radius on the left edge of the panel.
const double _kPanelRadius = 24.0;

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

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(_kPanelRadius),
        bottomLeft: Radius.circular(_kPanelRadius),
      ),
      child: Material(
        color: cs.surface,
        elevation: 8,
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
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.primaryButtonText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    // Display name
                    Text(
                      displayName,
                      style: AppTextStyles.h3.copyWith(
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
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
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
                label: 'Profile',
                onTap: () {
                  onClose();
                  context.push(RouteNames.settingsPath);
                },
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {
                  onClose();
                  context.push(RouteNames.settingsPath);
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
        style: AppTextStyles.body.copyWith(color: effectiveColor),
      ),
      trailing: color == null
          ? Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant,
              size: AppDimens.iconSm,
            )
          : null,
      onTap: onTap,
      minLeadingWidth: AppDimens.iconMd,
    );
  }
}
