/// Zuralog — Tone Sample Card.
///
/// Dropped into the chat right after the user picks a coach tone.
/// Shows what a real coach message will sound like in their chosen
/// voice — makes the abstract "Warm" or "Direct" pick land concretely.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

class OnboardingToneSampleCard extends StatelessWidget {
  const OnboardingToneSampleCard({
    super.key,
    required this.toneId,
  });

  final String toneId;

  static const double _cardRadius = 20;
  static const double _quoteFontSize = 17;
  static const double _labelLetterSpacing = 1.6;

  @override
  Widget build(BuildContext context) {
    final quote = _sampleForTone(toneId);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      padding: const EdgeInsets.all(AppDimens.spaceMdPlus),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Vertical sage accent line — visual cue this is a preview quote.
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                'HOW I\'LL TALK TO YOU',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                  letterSpacing: _labelLetterSpacing,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            quote,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.warmWhite,
              fontSize: _quoteFontSize,
              height: 1.45,
              letterSpacing: -0.2,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  static String _sampleForTone(String toneId) {
    switch (toneId) {
      case 'direct':
        return "You slept 47 minutes less than usual. Your evening workout shifted your sleep onset by 22 minutes.";
      case 'warm':
        return "Hey — tough night last night. Your body took a little longer to wind down. We've got you.";
      case 'minimal':
        return "Sleep dipped. Check in if you want.";
      case 'thorough':
        return "Your total sleep was 6h 32m vs a 7h 30m average. Evening training raised core temperature and delayed sleep onset by ~22 min. Morning heart rate is up 6 bpm.";
      default:
        return "I've got you.";
    }
  }
}
