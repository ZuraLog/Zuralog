/// Zuralog — Onboarding Profile Finale Card.
///
/// Rich card the coach drops into the chat at the end of the flow. Lists
/// the key facts the coach now knows about the user with brand-colored
/// dots per category. Designed to be screenshot-worthy.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/onboarding/presentation/chat/domain/chat_types.dart';

class OnboardingProfileCard extends StatelessWidget {
  const OnboardingProfileCard({
    super.key,
    required this.profile,
  });

  final OnboardingProfile profile;

  static const double _cardRadius = 22;
  static const double _dotSize = 7;
  static const double _rowVerticalPadding = 10;
  static const double _labelLetterSpacing = 1.6;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    final rows = <_ProfileRow>[
      if (profile.name != null)
        _ProfileRow(
          color: colors.primary,
          label: 'Name',
          value: profile.name!,
        ),
      if (profile.age != null && profile.sex != null)
        _ProfileRow(
          color: AppColors.categoryHeart,
          label: 'Basics',
          value: _formatBasics(profile),
        ),
      if (profile.focus != null)
        _ProfileRow(
          color: _focusColor(profile.focus!),
          label: 'Focus',
          value: _focusLabel(profile.focus!),
        ),
      if (profile.goal != null && profile.goal!.isNotEmpty)
        _ProfileRow(
          color: AppColors.categoryNutrition,
          label: 'Goal',
          value: profile.goal!,
        ),
      if (profile.tone != null)
        _ProfileRow(
          color: AppColors.warmWhite,
          label: 'Tone',
          value: _toneLabel(profile.tone!),
        ),
      if (profile.healthConnected)
        _ProfileRow(
          color: AppColors.categoryActivity,
          label: 'Data',
          value: 'Health data connected',
        ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMdPlus,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR COACH KNOWS',
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.primary,
              letterSpacing: _labelLetterSpacing,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          ...List.generate(rows.length, (i) {
            final row = rows[i];
            final isLast = i == rows.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(
                vertical: _rowVerticalPadding,
              ),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: colors.textPrimary.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
              ),
              child: Row(
                children: [
                  Container(
                    width: _dotSize,
                    height: _dotSize,
                    decoration: BoxDecoration(
                      color: row.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  SizedBox(
                    width: 64,
                    child: Text(
                      row.label.toUpperCase(),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: colors.textSecondary,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _formatBasics(OnboardingProfile p) {
    final sexShort =
        p.sex == 'female' ? 'F' : (p.sex == 'male' ? 'M' : '—');
    return '$sexShort · ${p.age} yrs · ${p.heightCm?.round()} cm · ${p.weightKg?.round()} kg';
  }

  static String _focusLabel(String focusId) {
    switch (focusId) {
      case 'sleep':
        return 'Sleep';
      case 'activity':
        return 'Activity';
      case 'nutrition':
        return 'Nutrition';
      case 'overall':
        return 'Overall wellness';
      default:
        return focusId;
    }
  }

  static Color _focusColor(String focusId) {
    switch (focusId) {
      case 'sleep':
        return AppColors.categorySleep;
      case 'activity':
        return AppColors.categoryActivity;
      case 'nutrition':
        return AppColors.categoryNutrition;
      case 'overall':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  static String _toneLabel(String toneId) {
    switch (toneId) {
      case 'direct':
        return 'Direct &amp; data-driven';
      case 'warm':
        return 'Warm &amp; encouraging';
      case 'minimal':
        return 'Minimal nudges';
      case 'thorough':
        return 'Thorough &amp; detailed';
      default:
        return toneId;
    }
  }
}

class _ProfileRow {
  const _ProfileRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;
}
