/// Zuralog — Profile Avatar Button.
///
/// A reusable [ConsumerWidget] that renders the current user's profile initial
/// inside a circular avatar. Tapping navigates to the Settings hub.
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
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';

// ── ProfileAvatarButton ───────────────────────────────────────────────────────

/// A circular avatar button that navigates to the Settings hub on tap.
///
/// The avatar displays the first letter of the signed-in user's display name.
///
/// Typically used via [ZuralogAppBar], which appends this widget
/// automatically as the last action on every screen:
/// ```dart
/// appBar: ZuralogAppBar(title: 'My Screen')
/// ```
/// Only use this widget directly if you are not using [ZuralogAppBar].
class ProfileAvatarButton extends ConsumerWidget {
  /// Creates a [ProfileAvatarButton].
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final email = ref.watch(userEmailProvider);
    final profile = ref.watch(userProfileProvider);

    final displayName = profile?.aiName ?? (email.isNotEmpty ? email : '');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '';

    return GestureDetector(
      onTap: () => context.pushNamed(RouteNames.settings),
      // opaque so the full avatar hit-box registers taps even when the
      // CircleAvatar child has transparent pixels around its edges.
      behavior: HitTestBehavior.opaque,
      child: CircleAvatar(
        radius: AppDimens.avatarMd / 2,
        backgroundColor: colors.primary.withValues(alpha: 0.85),
        child: initial.isNotEmpty
            ? Text(
                initial,
                style: AppTextStyles.body.copyWith(
                  color: colors.textOnSage,
                  fontWeight: FontWeight.w700,
                ),
              )
            : Icon(
                Icons.person_rounded,
                size: 18,
                color: colors.textOnSage,
              ),
      ),
    );
  }
}
