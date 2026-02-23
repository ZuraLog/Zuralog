/// Zuralog — Profile Side Panel Widget.
///
/// A right-side slide-in overlay that appears when the user taps the profile
/// avatar in the Dashboard header. It provides quick access to profile-related
/// navigation destinations without pushing a full-screen route.
///
/// The panel slides in from the right over a semi-transparent dark scrim.
/// Tapping the scrim or pressing the back button dismisses the panel.
///
/// Navigation destinations exposed by the panel:
///   1. Profile / Edit Profile  — taps navigate to Settings screen.
///   2. Settings                — navigates to Settings screen.
///   3. Sign Out                — logs out the user.
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

/// Width of the side panel in logical pixels.
const double _kPanelWidth = 288.0;

/// Diameter of the avatar shown in the panel header.
const double _kPanelAvatarSize = 64.0;

/// Corner radius on the left edge of the panel.
const double _kPanelRadius = 24.0;

/// Duration of the slide animation.
const Duration _kAnimDuration = Duration(milliseconds: 280);

/// Scrim opacity at full expansion.
const double _kScrimOpacity = 0.45;

// ── ProfileSidePanel ──────────────────────────────────────────────────────────

/// Right-side slide-in profile panel.
///
/// Displays the user's avatar, name, and email at the top, followed by
/// navigation links (Profile, Settings) and a Sign Out action at the bottom.
///
/// Usage — call the static [show] helper from any widget:
/// ```dart
/// ProfileSidePanel.show(context, ref);
/// ```
class ProfileSidePanel extends ConsumerStatefulWidget {
  /// Creates a [ProfileSidePanel].
  const ProfileSidePanel({super.key});

  /// Slides the panel into view as an [OverlayEntry] above the current route.
  ///
  /// The panel and its scrim are inserted directly into the [Overlay] so
  /// that the bottom navigation bar and existing routes remain behind it.
  ///
  /// Parameters:
  ///   context: Build context — used to access [Overlay] and [GoRouter].
  static void show(BuildContext context) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ProfileSidePanelOverlay(
        onDismiss: () => entry.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
  }

  @override
  ConsumerState<ProfileSidePanel> createState() => _ProfileSidePanelState();
}

class _ProfileSidePanelState extends ConsumerState<ProfileSidePanel> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ── Overlay Wrapper ───────────────────────────────────────────────────────────

/// Full-screen overlay that owns the scrim + animated panel.
///
/// Manages the slide-in / slide-out animation and calls [onDismiss] when the
/// panel is fully hidden so the [OverlayEntry] can be removed.
class _ProfileSidePanelOverlay extends StatefulWidget {
  /// Callback invoked after the exit animation completes.
  final VoidCallback onDismiss;

  /// Creates a [_ProfileSidePanelOverlay].
  const _ProfileSidePanelOverlay({required this.onDismiss});

  @override
  State<_ProfileSidePanelOverlay> createState() =>
      _ProfileSidePanelOverlayState();
}

class _ProfileSidePanelOverlayState extends State<_ProfileSidePanelOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _kAnimDuration);
    _slideAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Triggers the slide-out animation and calls [widget.onDismiss] when done.
  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Scrim ───────────────────────────────────────────────────────
        FadeTransition(
          opacity: _fadeAnim.drive(
            Tween<double>(begin: 0, end: _kScrimOpacity),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: const ColoredBox(color: Colors.black, child: SizedBox.expand()),
          ),
        ),

        // ── Panel ───────────────────────────────────────────────────────
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: _kPanelWidth,
          child: SlideTransition(
            position: _slideAnim.drive(
              Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ),
            ),
            child: _PanelContent(onDismiss: _dismiss),
          ),
        ),
      ],
    );
  }
}

// ── Panel Content ─────────────────────────────────────────────────────────────

/// The actual panel surface with user info and navigation links.
///
/// Uses [colorScheme.surface] for the background (not scaffold background),
/// which gives the correct card-like appearance in both light and dark modes.
class _PanelContent extends ConsumerWidget {
  /// Callback to close the panel.
  final VoidCallback onDismiss;

  /// Creates a [_PanelContent].
  const _PanelContent({required this.onDismiss});

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
              // ── Panel Header: avatar + name + email ─────────────────
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
                    // Avatar
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
                    // Email
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

              // ── Divider ─────────────────────────────────────────────
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),

              const SizedBox(height: AppDimens.spaceSm),

              // ── Navigation Links ─────────────────────────────────────
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                onTap: () {
                  onDismiss();
                  context.push(RouteNames.settingsPath);
                },
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {
                  onDismiss();
                  context.push(RouteNames.settingsPath);
                },
              ),

              const Spacer(),

              // ── Divider ─────────────────────────────────────────────
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),

              // ── Sign Out ─────────────────────────────────────────────
              _NavItem(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                color: isDark ? AppColors.accentDark : AppColors.accentLight,
                onTap: () async {
                  onDismiss();
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

/// A single navigation list tile used inside [_PanelContent].
///
/// Renders an icon, label, and optional trailing chevron.
/// The [color] parameter can override both the icon and label colour.
class _NavItem extends StatelessWidget {
  /// The icon glyph.
  final IconData icon;

  /// The label text.
  final String label;

  /// Optional colour override (used for destructive items like Sign Out).
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
