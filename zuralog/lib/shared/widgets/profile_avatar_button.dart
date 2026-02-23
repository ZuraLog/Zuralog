/// Zuralog — Profile Avatar Button.
///
/// A reusable [ConsumerWidget] that renders the current user's profile initial
/// inside a circular avatar matching the side panel header avatar.  Tapping
/// opens the [ProfileSidePanelWidget] via [sidePanelOpenProvider].
///
/// Use this widget in every screen's app bar to give the user a consistent,
/// identifiable shortcut to their profile and the side panel — regardless of
/// which tab they are on.
///
/// The avatar renders the first character of `userProfileProvider.aiName`
/// (falling back to the first character of the user's email, then `'?'`) so
/// it is always identical to the avatar shown inside the side panel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/state/side_panel_provider.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';

// ── ProfileAvatarButton ───────────────────────────────────────────────────────

/// A circular avatar button that opens the profile side panel on tap.
///
/// The avatar displays the first letter of the signed-in user's display name,
/// using the same colour and size as the avatar inside [ProfileSidePanelWidget],
/// so the two always look identical to the user.
///
/// Typically placed in a screen's `AppBar` [actions] list:
/// ```dart
/// appBar: AppBar(
///   actions: const [
///     Padding(
///       padding: EdgeInsets.only(right: AppDimens.spaceMd),
///       child: ProfileAvatarButton(),
///     ),
///   ],
/// )
/// ```
class ProfileAvatarButton extends ConsumerWidget {
  /// Creates a [ProfileAvatarButton].
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(userEmailProvider);
    final profile = ref.watch(userProfileProvider);

    final displayName = profile?.aiName ?? (email.isNotEmpty ? email : '—');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => ref.read(sidePanelOpenProvider.notifier).state = true,
      child: CircleAvatar(
        radius: AppDimens.avatarMd / 2,
        backgroundColor: AppColors.primary.withValues(alpha: 0.85),
        child: Text(
          initial,
          style: AppTextStyles.body.copyWith(
            color: AppColors.primaryButtonText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
