library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

class HeartAiSummaryCard extends StatelessWidget {
  const HeartAiSummaryCard({
    super.key,
    required this.aiSummary,
    this.generatedAt,
  });

  final String? aiSummary;
  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: AppColors.categoryHeart,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: AppDimens.iconSm,
                  color: AppColors.categoryHeart,
                ),
                const SizedBox(width: AppDimens.spaceXs),
                Text(
                  'AI Summary',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.categoryHeart),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),
            aiSummary != null
                ? Text(
                    aiSummary!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      height: 1.55,
                    ),
                  )
                : const _SkeletonText(),
            if (generatedAt != null) ...[
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                'Generated ${_relativeTime(generatedAt!)}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: colors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _SkeletonText extends StatelessWidget {
  const _SkeletonText();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final width in [1.0, 0.85, 0.72])
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.spaceXs),
            child: Container(
              height: 13,
              width: MediaQuery.of(context).size.width * width,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.shapeXs),
              ),
            ),
          ),
      ],
    );
  }
}
