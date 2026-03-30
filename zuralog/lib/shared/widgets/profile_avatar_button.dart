/// Zuralog — Profile Avatar Button.
///
/// A 36 px circular avatar shown in the app bar on every tab. Tapping it
/// navigates to the full-screen Settings hub ([SettingsHubScreen]) by
/// pushing `/settings` over the current shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';

class ProfileAvatarButton extends ConsumerWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final initial = (profile?.aiName ?? '?').substring(0, 1).toUpperCase();

    return GestureDetector(
      onTap: () => context.push(RouteNames.settingsPath),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.primary,
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.userBubbleText,
          ),
        ),
      ),
    );
  }
}
