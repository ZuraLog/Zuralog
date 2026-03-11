/// Zuralog — HealthScoreZeroState widget.
///
/// Shared empty-state widget displayed inside the Health Score hero card
/// whenever the user has no health score data yet (new account, no
/// integrations connected, score == 0 with dataDays == 0).
///
/// Used by:
///   - [TodayFeedScreen] — inside [_HealthScoreHero]
///   - [ScoreTrendHero]  — inside the compact ring area
///
/// The widget is **not** an error state. It is the correct, welcoming
/// zero-data state. It never communicates a connection failure.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── HealthScoreZeroState ──────────────────────────────────────────────────────

/// Welcoming zero-data placeholder for the Health Score hero.
///
/// Shows a muted ring with a heart icon, a short headline, and a one-line
/// nudge to start logging or connect an app. Does **not** mention errors or
/// network connectivity.
class HealthScoreZeroState extends StatelessWidget {
  /// Creates a [HealthScoreZeroState].
  const HealthScoreZeroState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Muted ring — same visual language as the real score ring but
          // at low opacity so it reads as "pending", not "broken".
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                width: 6,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.favorite_border_rounded,
                size: 28,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Your health score awaits',
            style: AppTextStyles.titleMedium.copyWith(
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'Log your first data point or connect an\napp to see your daily score.',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
