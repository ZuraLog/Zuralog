/// Today Tab — Journal Prompt Card.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

class JournalPromptCard extends StatelessWidget {
  const JournalPromptCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    const wellnessColor = AppColors.categoryWellness;

    return ZuralogCard(
      variant: ZCardVariant.plain,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: AppDimens.iconContainerSm,
            height: AppDimens.iconContainerSm,
            decoration: BoxDecoration(
              color: wellnessColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimens.shapeSm),
            ),
            child: const Center(
              child: Icon(
                Icons.edit_note_rounded,
                size: AppDimens.iconMd,
                color: wellnessColor,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "How's your day going?",
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXxs),
                Text(
                  'Write a journal entry',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: AppDimens.iconMd,
            color: colors.textTertiary,
          ),
        ],
      ),
    );
  }
}
