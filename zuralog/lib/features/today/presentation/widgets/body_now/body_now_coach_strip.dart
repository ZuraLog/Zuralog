// zuralog/lib/features/today/presentation/widgets/body_now/body_now_coach_strip.dart
/// The coach strip at the bottom of the hero — Zura avatar + message + CTA.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/body/domain/coach_message.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

class BodyNowCoachStrip extends StatelessWidget {
  const BodyNowCoachStrip({
    super.key,
    required this.message,
    required this.onCtaTap,
    required this.onAvatarTap,
  });

  final CoachMessage message;
  final VoidCallback onCtaTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.divider, width: 1)),
      ),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: ClipOval(
              child: SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(color: AppColors.primary),
                    // Avatar pattern drifts per brand-bible animation rule.
                    const ZPatternOverlay(
                      variant: ZPatternVariant.sage,
                      opacity: 0.18,
                      animate: true,
                    ),
                    Text(
                      'Z',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textOnSage,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    'ZURA',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '·',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Your coach',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(
                  message.text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: onCtaTap,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      message.ctaLabel,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 14, color: AppColors.primary),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
