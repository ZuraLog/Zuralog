/// Zuralog Settings — User Header Widget.
///
/// Displays the authenticated user's avatar (initials), email address,
/// and membership date at the top of the Settings screen. Tapping the
/// avatar shows a "Profile photo coming soon" SnackBar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';

/// Size of the circular avatar in the user header.
const double _kAvatarSize = 72;

/// Header widget that displays the current user's identity information.
///
/// Renders a circular avatar using the first letter of the user's email
/// on a Sage Green background, the full email address, and a dynamic
/// "Member since" date derived from the user's [UserProfile.createdAt].
///
/// Tapping the avatar shows a [SnackBar] informing the user that profile
/// photo customisation is coming in a future update.
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
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    final colorScheme = Theme.of(context).colorScheme;

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
          _AvatarCircle(initial: initial),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email.isNotEmpty ? email : '—',
                  style: AppTextStyles.h3.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimens.spaceXs),
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

/// Circular avatar that shows the user's initials on a sage-green background.
///
/// Tapping triggers a [SnackBar] informing the user that profile photo
/// upload is not yet available.
class _AvatarCircle extends StatelessWidget {
  /// The single character initial to display inside the avatar.
  final String initial;

  /// Creates an [_AvatarCircle].
  const _AvatarCircle({required this.initial});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo coming soon'),
          ),
        );
      },
      child: SizedBox(
        width: _kAvatarSize,
        height: _kAvatarSize,
        child: CircleAvatar(
          radius: _kAvatarSize / 2,
          backgroundColor: AppColors.primary,
          child: Text(
            initial,
            style: AppTextStyles.h1.copyWith(
              color: AppColors.primaryButtonText,
              fontSize: 28,
            ),
          ),
        ),
      ),
    );
  }
}
