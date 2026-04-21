/// Share Progress action tile for the Goal Detail page.
///
/// Phase 1: Shows a "coming soon" snackbar on tap. Phase 2 (separate spec)
/// implements the actual ShareProgressSheet that generates a screenshot
/// card.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class GoalShareAction extends StatelessWidget {
  const GoalShareAction({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Share card coming soon')),
          );
        },
        borderRadius: BorderRadius.circular(AppDimens.shapeMd),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                ),
                child: const Icon(
                  Icons.ios_share_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share progress',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Generate a beautiful screenshot card',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
