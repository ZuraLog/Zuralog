/// Zuralog — Onboarding User Message Bubble.
///
/// Right-aligned warm-white bubble — intentionally the INVERSE of the
/// coach bubble so the two voices are visually distinct at a glance.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class OnboardingUserBubble extends StatelessWidget {
  const OnboardingUserBubble({
    super.key,
    required this.text,
  });

  final String text;

  // Same max-width as the coach bubble so both voices feel balanced.
  static const double _bubbleMaxWidthFraction = 0.78;
  static const double _bubbleCornerRadius = 18;
  static const double _bubbleTailRadius = 6;

  // Dark foreground on the warm-white bubble uses the brand's
  // "Text On Warm White" token — same contrast as the active segmented
  // control pill per the brand bible.
  static const Color _textOnWarmWhite = Color(0xFF161618);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final colors = AppColorsOf(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: AppDimens.spaceXxl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: media.width * _bubbleMaxWidthFraction,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.textPrimary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(_bubbleCornerRadius),
                    topRight: Radius.circular(_bubbleTailRadius),
                    bottomLeft: Radius.circular(_bubbleCornerRadius),
                    bottomRight: Radius.circular(_bubbleCornerRadius),
                  ),
                ),
                child: Text(
                  text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _textOnWarmWhite,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
