library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/presentation/widgets/pressable_card.dart';
import 'package:zuralog/shared/widgets/cards/z_feature_card.dart';
import 'package:zuralog/shared/widgets/indicators/z_category_icon_tile.dart';

class JournalPromptCta extends StatelessWidget {
  const JournalPromptCta({
    super.key,
    required this.onTap,
    this.lastEntryDate,
    this.journalledToday = false,
  });

  final VoidCallback onTap;
  final String? lastEntryDate;
  final bool journalledToday;

  static const _prompts = [
    'How did this week feel to you?',
    'What are you proud of this week?',
    'What would you do differently?',
    'What energized you most?',
  ];

  String _buildPrompt() {
    if (lastEntryDate == null) return 'Start your journal — how are you feeling?';
    final week = DateTime.now().weekOfYear;
    return _prompts[week % _prompts.length];
  }

  String _buildSubLabel() {
    if (lastEntryDate == null) return 'First entry';
    final last = DateTime.tryParse(lastEntryDate!);
    if (last == null) return 'Log today';
    final diff = DateTime.now().difference(last).inDays;
    if (diff == 0) return 'Log today';
    if (diff == 1) return 'Yesterday';
    return '$diff days ago';
  }

  @override
  Widget build(BuildContext context) {
    if (journalledToday) return const SizedBox.shrink();

    final colors = AppColorsOf(context);

    return PressableCard(
      onTap: onTap,
      borderRadius: AppDimens.shapeLg,
      child: ZFeatureCard(
        child: Row(
          children: [
            const ZCategoryIconTile(
              color: AppColors.primary, // Sage
              icon: Icons.edit_rounded,
              size: AppDimens.avatarMd, // 36
              iconSize: 18,
              iconColor: AppColors.textOnSage,
              borderRadius: 10,
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"${_buildPrompt()}"',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.progressTextPrimary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _buildSubLabel(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.progressTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            // Tertiary text button per bible — Sage SemiBold, no fill, no border.
            Text(
              'Write',
              style: AppTextStyles.labelMedium.copyWith(
                color: colors.progressTextSecondary, // Sage in dark mode
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on DateTime {
  int get weekOfYear {
    final firstDayOfYear = DateTime(year, 1, 1);
    final diff = difference(firstDayOfYear).inDays;
    return ((diff + firstDayOfYear.weekday - 1) / 7).floor() + 1;
  }
}
