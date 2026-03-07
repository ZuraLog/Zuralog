/// Zuralog — DataMaturityBanner widget.
///
/// Displayed during the first 7 days of data collection to show the user
/// how close they are to unlocking full AI insights.
///
/// Modes:
/// - [DataMaturityMode.progress]: Normal progress bar — "X of 7 days"
/// - [DataMaturityMode.stillBuilding]: Account is > 7 days old but data
///   is still insufficient. Shows a different message with a "Don't show
///   again" option instead of the standard dismiss.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── DataMaturityMode ──────────────────────────────────────────────────────────

/// Controls which variant of the [DataMaturityBanner] is rendered.
enum DataMaturityMode {
  /// Normal progress banner — "Data maturity: X of 7 days".
  progress,

  /// Shown after 7 calendar days when data is still insufficient.
  stillBuilding,
}

// ── DataMaturityBanner ────────────────────────────────────────────────────────

/// Progress banner shown during the first 7 days of data collection.
class DataMaturityBanner extends StatelessWidget {
  /// Creates a [DataMaturityBanner].
  const DataMaturityBanner({
    super.key,
    required this.daysWithData,
    this.targetDays = 7,
    this.mode = DataMaturityMode.progress,
    this.onDismiss,
    this.onPermanentDismiss,
  });

  /// Current days with health data recorded.
  final int daysWithData;

  /// Target milestone (default: 7 days).
  final int targetDays;

  /// Which variant to display.
  final DataMaturityMode mode;

  /// Called when the user taps the session-dismiss (×) button.
  /// In [DataMaturityMode.stillBuilding] this hides for the session only.
  final VoidCallback? onDismiss;

  /// Called when the user taps "Don't show again" (permanent dismissal).
  /// Only used in [DataMaturityMode.stillBuilding].
  final VoidCallback? onPermanentDismiss;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardBackgroundDark : AppColors.surfaceLight;
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final trackColor =
        isDark ? const Color(0xFF3A3A3C) : AppColors.borderLight;

    if (mode == DataMaturityMode.stillBuilding) {
      return _StillBuildingBanner(
        bg: bg,
        textColor: textColor,
        secondaryColor: secondaryColor,
        onDismiss: onDismiss,
        onPermanentDismiss: onPermanentDismiss,
      );
    }

    final progress = (daysWithData / targetDays).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Data maturity: $daysWithData of $targetDays days',
                  style: AppTextStyles.caption.copyWith(color: textColor),
                ),
              ),
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppDimens.spaceSm),
                    child: Icon(
                      Icons.close_rounded,
                      size: AppDimens.iconSm,
                      color: secondaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: trackColor,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            progress >= 1.0
                ? 'AI insights fully unlocked!'
                : 'Keep logging to unlock deeper AI insights.',
            style: AppTextStyles.caption
                .copyWith(color: secondaryColor, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── _StillBuildingBanner ──────────────────────────────────────────────────────

class _StillBuildingBanner extends StatelessWidget {
  const _StillBuildingBanner({
    required this.bg,
    required this.textColor,
    required this.secondaryColor,
    this.onDismiss,
    this.onPermanentDismiss,
  });

  final Color bg;
  final Color textColor;
  final Color secondaryColor;
  final VoidCallback? onDismiss;
  final VoidCallback? onPermanentDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your data is still building',
                      style:
                          AppTextStyles.caption.copyWith(color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Connect more integrations or keep logging to unlock '
                      'deeper AI insights.',
                      style: AppTextStyles.caption
                          .copyWith(color: secondaryColor, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppDimens.spaceSm),
                    child: Icon(
                      Icons.close_rounded,
                      size: AppDimens.iconSm,
                      color: secondaryColor,
                    ),
                  ),
                ),
            ],
          ),
          if (onPermanentDismiss != null) ...[
            const SizedBox(height: AppDimens.spaceSm),
            GestureDetector(
              onTap: onPermanentDismiss,
              child: Text(
                "Don't show again",
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontSize: 10,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
