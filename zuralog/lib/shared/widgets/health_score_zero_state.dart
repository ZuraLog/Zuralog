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
/// Shows a sad face emoji, a "Health Score" label, and a "Log to unlock"
/// subtitle. Does **not** mention errors or network connectivity.
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('😔', style: TextStyle(fontSize: 32)),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Health Score',
            style: AppTextStyles.labelMedium.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'Log to unlock',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
