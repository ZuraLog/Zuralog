// zuralog/lib/features/today/presentation/widgets/body_now/body_now_coach_strip.dart
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/body/domain/coach_message.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_blob.dart';

class BodyNowCoachStrip extends StatelessWidget {
  const BodyNowCoachStrip({
    super.key,
    required this.message,
    required this.onCtaTap,
  });

  final CoachMessage message;
  final VoidCallback onCtaTap;

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
          const CoachBlob(state: BlobState.idle, size: 40),
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
                if (message.isCheckIn)
                  _CheckInButton(label: message.ctaLabel, onTap: onCtaTap)
                else
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

class _CheckInButton extends StatelessWidget {
  const _CheckInButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
