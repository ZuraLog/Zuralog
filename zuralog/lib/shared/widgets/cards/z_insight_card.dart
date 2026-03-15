/// Zuralog Design System — AI Insight Card.
///
/// Displays a single AI-generated insight in the Today feed.
/// Category-colour glow on unread cards. Unread accent bar and dot.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/theme/category_colors.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/shared/widgets/buttons/spring_button.dart';
import 'package:zuralog/shared/widgets/indicators/z_icon_badge.dart';

/// A tappable card displaying a single [InsightCard] in the Today feed.
///
/// [onTap] is called when the card is tapped. The caller is responsible for
/// triggering analytics and navigation — this widget is a pure display component.
class ZInsightCard extends StatelessWidget {
  const ZInsightCard({
    super.key,
    required this.insight,
    required this.onTap,
  });

  final InsightCard insight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final categoryColor = categoryColorFromString(insight.category);
    final isUnread = !insight.isRead;

    return ZuralogSpringButton(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        child: Stack(
          children: [
            // Category-colour radial glow (unread only).
            if (isUnread)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.9, -0.9),
                        radius: 0.7,
                        colors: [
                          categoryColor.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Card body.
            Container(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                border: Border.all(
                  color: isUnread
                      ? categoryColor.withValues(alpha: 0.20)
                      : colors.border,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isUnread)
                      Container(
                        width: 3,
                        height: double.infinity,
                        constraints: const BoxConstraints(minHeight: 60),
                        margin: const EdgeInsets.only(right: AppDimens.spaceSm),
                        decoration: BoxDecoration(
                          color: categoryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ZIconBadge(
                      icon: _insightIcon(insight.type),
                      color: categoryColor,
                      size: 40,
                      iconSize: AppDimens.iconMd,
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isUnread) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: categoryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppDimens.spaceXs),
                              ],
                              Expanded(
                                child: Text(
                                  insight.title,
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimens.spaceXs),
                          Text(
                            insight.summary,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: colors.textSecondary,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppDimens.spaceSm),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusChip,
                                  ),
                                ),
                                child: Text(
                                  insight.category,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: categoryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (insight.createdAt != null)
                                Text(
                                  _relativeTime(insight.createdAt!),
                                   style: AppTextStyles.labelSmall.copyWith(
                                     color: colors.textTertiary,
                                   ),
                                ),
                              const SizedBox(width: AppDimens.spaceXs),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: AppDimens.iconSm,
                                color: colors.primary.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

IconData _insightIcon(InsightType type) {
  return switch (type) {
    InsightType.anomaly => Icons.warning_amber_rounded,
    InsightType.correlation => Icons.compare_arrows_rounded,
    InsightType.trend => Icons.trending_up_rounded,
    InsightType.recommendation => Icons.lightbulb_outline_rounded,
    InsightType.achievement => Icons.emoji_events_rounded,
    InsightType.unknown => Icons.insights_rounded,
  };
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays}d ago';
}
