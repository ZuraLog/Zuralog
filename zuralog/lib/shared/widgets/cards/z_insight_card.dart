/// Zuralog Design System — AI Insight Card.
///
/// Editorial card for a single AI-generated insight in the Today feed.
/// Each card is category-aware: the left gradient strip, the emblem,
/// the icon, and the category · type chip all pick up the matching
/// health-category color so the feed has strong visual variety.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/theme/category_colors.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/shared/widgets/buttons/spring_button.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

/// A tappable card displaying a single [InsightCard] in the Today feed.
///
/// [onTap] is called when the card is tapped. The caller is responsible
/// for triggering analytics and navigation — this widget is a pure
/// display component.
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
    final categoryColor = categoryColorFromString(
      insight.category,
      fallback: colors.primary,
    );
    final isUnread = !insight.isRead;
    final categoryIcon = _categoryIcon(insight.category, insight.type);

    return ZuralogSpringButton(
      onTap: onTap,
      child: ZuralogCard(
        variant: ZCardVariant.feature,
        category: categoryColor,
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          AppDimens.spaceMd,
          AppDimens.spaceMd,
          AppDimens.spaceMd,
        ),
        child: Stack(
          children: [
            // Category-colour radial glow (unread only). Softer than before
            // so it reads as a halo rather than a flashlight.
            if (isUnread)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.8, -0.8),
                        radius: 1.1,
                        colors: [
                          categoryColor.withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Card content.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gradient category strip — 4pt wide, tapered to transparent
                  // at top and bottom so it reads like a bookmark ribbon.
                  Container(
                    width: 4,
                    margin: const EdgeInsets.only(right: AppDimens.spaceMd),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          categoryColor.withValues(
                            alpha: isUnread ? 0.0 : 0.0,
                          ),
                          categoryColor.withValues(
                            alpha: isUnread ? 1.0 : 0.5,
                          ),
                          categoryColor.withValues(
                            alpha: isUnread ? 0.0 : 0.0,
                          ),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Category emblem — 48pt circle with tinted fill, subtle
                  // ring, and the category's domain icon.
                  _CategoryEmblem(
                    icon: categoryIcon,
                    color: categoryColor,
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row — title + unread dot inline.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                insight.title,
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isUnread) ...[
                              const SizedBox(width: AppDimens.spaceSm),
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: categoryColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: categoryColor.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppDimens.spaceXs),
                        Text(
                          insight.summary,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: colors.textSecondary,
                            height: 1.45,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppDimens.spaceSm),
                        // Footer — category · type chip, time ago, chevron.
                        Row(
                          children: [
                            _CategoryTypeChip(
                              category: insight.category,
                              type: insight.type,
                              color: categoryColor,
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
                              color: isUnread
                                  ? categoryColor
                                  : colors.textTertiary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category emblem ──────────────────────────────────────────────────────────

class _CategoryEmblem extends StatelessWidget {
  const _CategoryEmblem({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
        border: Border.all(
          color: color.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: 22,
      ),
    );
  }
}

// ── Category · type chip ─────────────────────────────────────────────────────

class _CategoryTypeChip extends StatelessWidget {
  const _CategoryTypeChip({
    required this.category,
    required this.type,
    required this.color,
  });

  final String category;
  final InsightType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = '${_categoryLabel(category)} · ${_typeLabel(type)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Picks the right domain icon for a category, falling back to an
/// insight-type icon when the category is generic.
IconData _categoryIcon(String category, InsightType type) {
  switch (category.toLowerCase()) {
    case 'sleep':
      return Icons.bedtime_rounded;
    case 'heart':
      return Icons.favorite_rounded;
    case 'activity':
      return Icons.directions_walk_rounded;
    case 'nutrition':
      return Icons.local_fire_department_rounded;
    case 'body':
      return Icons.water_drop_rounded;
    case 'vitals':
      return Icons.monitor_heart_rounded;
    case 'wellness':
      return Icons.self_improvement_rounded;
    case 'mobility':
      return Icons.accessibility_new_rounded;
    case 'cycle':
      return Icons.loop_rounded;
    case 'environment':
      return Icons.wb_sunny_rounded;
    case 'streak':
    case 'engagement':
      return Icons.local_fire_department_rounded;
  }
  return _typeIcon(type);
}

IconData _typeIcon(InsightType type) {
  return switch (type) {
    InsightType.anomaly => Icons.warning_amber_rounded,
    InsightType.correlation => Icons.compare_arrows_rounded,
    InsightType.trend => Icons.trending_up_rounded,
    InsightType.recommendation => Icons.lightbulb_outline_rounded,
    InsightType.achievement => Icons.emoji_events_rounded,
    InsightType.unknown => Icons.insights_rounded,
  };
}

String _categoryLabel(String category) {
  if (category.isEmpty) return 'Health';
  final c = category.toLowerCase();
  switch (c) {
    case 'engagement':
      return 'Streak';
    case 'general':
      return 'Health';
  }
  return c[0].toUpperCase() + c.substring(1);
}

String _typeLabel(InsightType type) {
  return switch (type) {
    InsightType.anomaly => 'Anomaly',
    InsightType.correlation => 'Correlation',
    InsightType.trend => 'Trend',
    InsightType.recommendation => 'Tip',
    InsightType.achievement => 'Achievement',
    InsightType.unknown => 'Insight',
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
