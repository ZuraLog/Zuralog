/// Zuralog — DataMaturityBanner widget.
///
/// Displayed for the first 30 days of data collection to show the user how
/// close they are to unlocking full AI insights. Dismissable.
///
/// ## Design spec
/// - Progress bar: sage-green fill on a surface-600 track.
/// - Label: "Data maturity: X of 7 days" — updated dynamically.
/// - Dismiss button (×) hides the banner for the session.
/// - Height: 56px total (bar + labels + padding).
///
/// ## Usage
/// ```dart
/// DataMaturityBanner(
///   daysWithData: 4,
///   targetDays: 7,
///   onDismiss: () { /* persist dismissal */ },
/// )
/// ```
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── DataMaturityBanner ────────────────────────────────────────────────────────

/// Progress banner shown during the first 30 days of data collection.
class DataMaturityBanner extends StatelessWidget {
  /// Creates a [DataMaturityBanner].
  ///
  /// [daysWithData] — number of days with recorded data.
  /// [targetDays] — milestone day count (typically 7, 14, or 30).
  /// [onDismiss] — called when the user taps the dismiss button.
  const DataMaturityBanner({
    super.key,
    required this.daysWithData,
    this.targetDays = 7,
    this.onDismiss,
  });

  /// Current days with health data recorded.
  final int daysWithData;

  /// Target milestone (default: 7 days for first milestone).
  final int targetDays;

  /// Optional dismiss callback.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final progress = (daysWithData / targetDays).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardBackgroundDark : AppColors.surfaceLight;
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final trackColor = isDark ? const Color(0xFF3A3A3C) : AppColors.borderLight;

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
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: trackColor,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
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
