library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/analytics/analytics_events.dart';
import 'package:zuralog/core/analytics/analytics_service.dart';
import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';

SnackBar _styledSnackBar(String message) {
  return SnackBar(
    content: Text(message),
    backgroundColor: AppColors.progressSurfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(20),
  );
}

Future<void> showStreakFreezeDialog(
  BuildContext context,
  WidgetRef ref,
  UserStreak streak,
) async {
  // freeze_count is tokens *available* (0–2), not tokens used.
  final freezesLeft = streak.freezeCount;

  if (freezesLeft <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      _styledSnackBar("You've used all your streak freezes."),
    );
    return;
  }
  if (streak.isFrozen) {
    ScaffoldMessenger.of(context).showSnackBar(
      _styledSnackBar('Streak is already frozen.'),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.progressSurfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      title: Text('Use a Streak Freeze?', style: AppTextStyles.titleMedium),
      content: Text(
        'This will protect your streak if you miss today. '
        'You have ${freezesLeft - 1} freeze(s) remaining after this.',
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.progressTextMuted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            'Cancel',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.progressTextMuted,
            ),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.progressSage,
            foregroundColor: AppColors.primaryOnLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusButton),
            ),
          ),
          child: const Text('Use Freeze'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(progressRepositoryProvider).applyStreakFreeze(streak.type);
    ref.read(hapticServiceProvider).medium();
    ref.read(analyticsServiceProvider).capture(
      event: AnalyticsEvents.streakFreezeUsed,
      properties: {
        'streak_type': streak.type.apiSlug,
        'freeze_count_remaining': (freezesLeft - 1).clamp(0, 2),
      },
    );
    ref.invalidate(progressHomeProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        _styledSnackBar('Streak freeze applied! Your streak is protected.'),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        _styledSnackBar('Failed to apply freeze. Please try again.'),
      );
    }
  }
}
