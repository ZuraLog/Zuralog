/// Zuralog Design System — Answer Origin Badge Component.
///
/// Violet pill that signals a food item was derived from an answer the user
/// gave to a clarifying follow-up question (rather than from the original
/// meal description). Mirrors the amber "N rules applied" pill structure
/// from the meal review screen but uses the Sleep category violet
/// ([AppColors.categorySleep], `#5E5CE6`) as its accent.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A tappable pill badge reading "From your answer".
///
/// Used in meal review / meal detail lists to mark food items whose
/// attributes (portion, cooking method, etc.) came from the user's reply
/// to a follow-up question. Tapping the badge opens a sheet or detail view
/// that explains which answer was applied.
///
/// Structure, padding, radius, and alpha ramp match the existing
/// "rules applied" pill in `meal_review_screen.dart`:
///   - background: violet at 12 % alpha
///   - border: violet at 30 % alpha, 1 px
///   - radius: [AppDimens.shapeSm]
///   - padding: [AppDimens.spaceSm] horizontal, [AppDimens.spaceXs] vertical
///
/// Example:
/// ```dart
/// ZAnswerOriginBadge(onTap: () => _showAnswerOriginSheet(context, item))
/// ```
class ZAnswerOriginBadge extends StatelessWidget {
  /// Creates a [ZAnswerOriginBadge].
  const ZAnswerOriginBadge({super.key, required this.onTap});

  /// Called when the badge is tapped. Typically opens a sheet explaining
  /// which follow-up answer this food item came from.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.categorySleep;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceSm,
          vertical: AppDimens.spaceXs,
        ),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.shapeSm),
          border: Border.all(
            color: accent.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.question_answer_outlined,
              size: AppDimens.iconSm,
              color: accent,
            ),
            const SizedBox(width: AppDimens.spaceXs),
            Text(
              'From your answer',
              style: AppTextStyles.labelSmall.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppDimens.spaceXs),
            const Icon(
              Icons.chevron_right,
              size: AppDimens.iconSm,
              color: accent,
            ),
          ],
        ),
      ),
    );
  }
}
