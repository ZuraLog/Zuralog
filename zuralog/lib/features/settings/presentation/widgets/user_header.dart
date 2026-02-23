/// Zuralog Settings — User Header Widget.
///
/// Displays the authenticated user's profile photo (or initials fallback),
/// display name, email address, and membership date at the top of the
/// Settings screen.
///
/// The avatar is tappable to trigger a profile-photo change flow (currently
/// a "coming soon" placeholder). The display name is resolved via
/// [UserProfile.aiName] — the same resolution order used by the Dashboard
/// greeting — so the name is always consistent across screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';

/// Diameter of the circular profile avatar in the user header.
const double _kAvatarSize = 80.0;

/// Size of the camera-overlay badge on the avatar.
const double _kBadgeSize = 28.0;

/// Header widget that displays the current user's identity information.
///
/// Renders a circular avatar (profile photo or initials on sage-green), the
/// user's display name (resolved via [UserProfile.aiName]), their email
/// address, and a dynamic "Member since" date.
///
/// The avatar is tappable; tapping it presents a SnackBar placeholder until
/// photo-upload functionality is implemented.
///
/// Example usage:
/// ```dart
/// const UserHeader()
/// ```
class UserHeader extends ConsumerWidget {
  /// Creates a [UserHeader].
  const UserHeader({super.key});

  /// Formats a [DateTime] as "Month YYYY" (e.g. "March 2025").
  ///
  /// Returns the month name and four-digit year separated by a space.
  String _formatDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(userEmailProvider);
    final profile = ref.watch(userProfileProvider);

    // Use aiName (nickname → displayName → email-prefix) — identical to the
    // dashboard greeting resolution — so the name is consistent everywhere.
    final displayName = profile?.aiName ?? (email.isNotEmpty ? email : '—');

    // Derive a single-character initial for the avatar fallback.
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    final memberSince = profile?.createdAt != null
        ? 'Member since ${_formatDate(profile!.createdAt!)}'
        : 'Member since —';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceLg,
      ),
      child: Row(
        children: [
          // ── Avatar with camera badge ────────────────────────────────────
          _AvatarWithBadge(initial: initial),
          const SizedBox(width: AppDimens.spaceMd),
          // ── Name, email, member-since ───────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Display name (primary identity)
                Text(
                  displayName,
                  style: AppTextStyles.h3.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Email (secondary identity)
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: AppDimens.spaceXs),
                // Membership date
                Text(
                  memberSince,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar With Badge ─────────────────────────────────────────────────────────

/// Circular avatar with a small camera-icon badge overlay.
///
/// Shows the user's profile photo when available; falls back to a sage-green
/// circle with the user's initial. The camera badge signals that the photo
/// is changeable. Tapping the avatar triggers [_onChangePhoto].
class _AvatarWithBadge extends StatelessWidget {
  /// The single upper-case character used as the fallback initial.
  final String initial;

  /// Creates an [_AvatarWithBadge].
  const _AvatarWithBadge({required this.initial});

  /// Called when the user taps the avatar to change their profile photo.
  ///
  /// Currently shows a placeholder SnackBar. Replace this with an
  /// [ImagePicker] call when photo-upload is implemented.
  void _onChangePhoto(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile photo — coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeBackground =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return GestureDetector(
      onTap: () => _onChangePhoto(context),
      child: SizedBox(
        width: _kAvatarSize,
        height: _kAvatarSize,
        child: Stack(
          children: [
            // ── Main avatar circle ──────────────────────────────────────
            CircleAvatar(
              radius: _kAvatarSize / 2,
              backgroundColor: AppColors.primary.withValues(alpha: 0.85),
              child: Text(
                initial,
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.primaryButtonText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            // ── Camera badge (bottom-right) ─────────────────────────────
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: _kBadgeSize,
                height: _kBadgeSize,
                decoration: BoxDecoration(
                  color: badgeBackground,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: badgeBackground,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: _kBadgeSize * 0.55,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
