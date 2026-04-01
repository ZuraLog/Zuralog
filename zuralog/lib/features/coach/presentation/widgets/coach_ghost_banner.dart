/// Persistent banner shown below the app bar when ghost mode is active.
///
/// Informs the user that nothing is being saved and offers an Exit button.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class CoachGhostBanner extends StatelessWidget {
  const CoachGhostBanner({super.key, required this.onExit});

  /// Called when the user taps the "Exit" button.
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ColoredBox(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.visibility_off_rounded,
              color: colors.primary,
              size: AppDimens.iconSm,
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              child: Text(
                'Ghost Mode — your conversation won\'t be saved or logged.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.primary,
                ),
              ),
            ),
            TextButton(
              onPressed: onExit,
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceSm,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Exit',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
