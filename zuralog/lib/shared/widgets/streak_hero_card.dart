/// Zuralog — Streak Hero Card widget.
///
/// Displays the user's current logging streak as a hero card.
/// Two visual states:
///   - Zero / inviting: ghost flame at low opacity with an encouraging label.
///   - Active: full-colour flame, large streak number, contextual subtitle.
///
/// Used in the Today tab hero row as the right-hand card alongside the
/// Health Score hero.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

// ── StreakHeroCard ────────────────────────────────────────────────────────────

/// Hero card showing the user's current streak.
///
/// Pass [streakDays] = 0 to show the inviting zero state.
/// Pass [isPersonalBest] = true to show the "Personal best 🏆" subtitle.
class StreakHeroCard extends StatelessWidget {
  /// Creates a [StreakHeroCard].
  const StreakHeroCard({
    super.key,
    required this.streakDays,
    this.isPersonalBest = false,
    this.isFrozen = false,
  });

  /// The user's current streak in days. 0 shows the inviting zero state.
  final int streakDays;

  /// Whether [streakDays] equals the user's all-time best. When true, the
  /// subtitle reads "Personal best 🏆" instead of "Keep it up!".
  /// Ignored when [streakDays] is 0.
  final bool isPersonalBest;

  /// Whether the streak is currently frozen (streak freeze active).
  /// When true, shows a shield indicator. Ignored when [streakDays] is 0.
  final bool isFrozen;

  @override
  Widget build(BuildContext context) {
    return ZuralogCard(
      variant: ZCardVariant.feature,
      padding: const EdgeInsets.symmetric(
        vertical: AppDimens.spaceLg,
        horizontal: AppDimens.spaceMd,
      ),
      child: streakDays == 0
          ? const _ZeroState()
          : _ActiveState(
              streakDays: streakDays,
              isPersonalBest: isPersonalBest,
              isFrozen: isFrozen,
            ),
    );
  }
}

// ── _ZeroState ────────────────────────────────────────────────────────────────

class _ZeroState extends StatelessWidget {
  const _ZeroState();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Ghost flame — greyscale, low opacity
        Opacity(
          opacity: AppDimens.ghostOpacity,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0,      0,      0,      1, 0,
            ]),
            child: Text('🔥', style: TextStyle(fontSize: AppDimens.emojiMd)),
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          'Start your streak today',
          style: AppTextStyles.labelMedium.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Text(
          'Log anything to begin',
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── _ActiveState ──────────────────────────────────────────────────────────────

class _ActiveState extends StatelessWidget {
  const _ActiveState({
    required this.streakDays,
    required this.isPersonalBest,
    required this.isFrozen,
  });

  final int streakDays;
  final bool isPersonalBest;
  final bool isFrozen;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final subtitle = isFrozen
        ? 'Streak frozen'
        : isPersonalBest
            ? 'Personal best 🏆'
            : 'Keep it up!';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Flame — frozen shows a shield overlay
        if (isFrozen)
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Text('🔥', style: TextStyle(fontSize: AppDimens.emojiMd)),
              Icon(
                Icons.shield_rounded,
                size: 14,
                color: colors.primary,
              ),
            ],
          )
        else
          Text('🔥', style: TextStyle(fontSize: AppDimens.emojiMd)),
        const SizedBox(height: AppDimens.spaceXs),
        // Large streak number
        Text(
          '$streakDays',
          style: AppTextStyles.displayLarge.copyWith(
            color: AppColors.healthScoreAmber,
          ),
        ),
        // Unit label
        Text(
          'day streak',
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        // Contextual subtitle
        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: isFrozen ? colors.primary : colors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
