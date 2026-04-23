/// Zuralog — Onboarding Coach Message Bubble.
///
/// Left-aligned bubble paired with the small [CoachBlob] avatar. Matches
/// the Coach tab's visual language so the onboarding chat reads as
/// *the same coach*, not a parallel surface.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_blob.dart';

class OnboardingCoachBubble extends StatelessWidget {
  const OnboardingCoachBubble({
    super.key,
    required this.text,
    this.showAvatar = true,
  });

  /// The coach's message content (plain text, no markdown for onboarding).
  final String text;

  /// When false, the avatar is still laid out but invisible — keeps bubbles
  /// in consecutive coach messages left-aligned to the same column.
  final bool showAvatar;

  // Bubble's maximum width as a fraction of the chat column. 78% matches
  // Apple Messages and keeps the text one-column readable.
  static const double _bubbleMaxWidthFraction = 0.78;

  // Tight top-left corner to visually tail the avatar, same as Coach tab.
  static const double _bubbleCornerRadius = 18;
  static const double _bubbleTailRadius = 6;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final media = MediaQuery.sizeOf(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Opacity(
            opacity: showAvatar ? 1.0 : 0.0,
            child: const CoachBlob(state: BlobState.idle, size: 22),
          ),
          const SizedBox(width: AppDimens.spaceSm),
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
                  color: colors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(_bubbleTailRadius),
                    topRight: Radius.circular(_bubbleCornerRadius),
                    bottomLeft: Radius.circular(_bubbleCornerRadius),
                    bottomRight: Radius.circular(_bubbleCornerRadius),
                  ),
                ),
                child: Text(
                  text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.textPrimary,
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
