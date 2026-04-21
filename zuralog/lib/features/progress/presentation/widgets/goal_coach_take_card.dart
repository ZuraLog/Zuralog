/// Coach Take card — AI insight for the Goal Detail page.
///
/// Wraps `goal.aiCommentary` in a Sage [ZFeatureCard] with a sparkle icon,
/// a structured body, and an optional recommendation pill split off the
/// first "→ Next milestone:" line. Free users see [ZLockedOverlay].
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';
import 'package:zuralog/shared/widgets/cards/z_locked_overlay.dart';
import 'package:zuralog/shared/widgets/indicators/z_category_icon_tile.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

class GoalCoachTakeCard extends StatelessWidget {
  const GoalCoachTakeCard({
    super.key,
    required this.commentary,
    required this.isPremium,
    this.updatedLabel = 'Updated recently',
  });

  final String? commentary;
  final bool isPremium;
  final String updatedLabel;

  @override
  Widget build(BuildContext context) {
    final text = commentary?.trim();
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    final split = _splitRecommendation(text);
    final body = split.body;
    final recommendation = split.recommendation;

    final card = ZFeatureCard(
      variant: ZPatternVariant.sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ZCategoryIconTile(
                color: AppColors.primary,
                icon: Icons.auto_awesome_rounded,
                size: 32,
                iconSize: 16,
                iconColor: AppColors.textOnSage,
                borderRadius: 9,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coach',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      updatedLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimaryDark,
              height: 1.55,
            ),
          ),
          if (recommendation != null) ...[
            const SizedBox(height: AppDimens.spaceSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '→',
                    style: TextStyle(fontSize: 14, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (isPremium) return card;

    return ZLockedOverlay(
      headline: 'AI insights for this goal',
      body: "Upgrade to see your coach's personalized take on every goal.",
      child: card,
    );
  }

  static _Split _splitRecommendation(String text) {
    final marker = RegExp(
      r'\s*(?:→|->)\s*Next milestone[:\s]',
      caseSensitive: false,
    );
    final match = marker.firstMatch(text);
    if (match == null) return _Split(body: text, recommendation: null);
    final body = text.substring(0, match.start).trim();
    final tail = text.substring(match.end).trim();
    return _Split(
      body: body.isEmpty ? text : body,
      recommendation: tail.isEmpty ? null : 'Next milestone: $tail',
    );
  }
}

class _Split {
  const _Split({required this.body, required this.recommendation});
  final String body;
  final String? recommendation;
}
