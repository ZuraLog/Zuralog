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
      if (profile.birthday != null && profile.sex != null)
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
      // Any diet pick is meaningful — "no restrictions" is useful context too.
      if (profile.dietaryRestrictions.isNotEmpty ||
          _dietAnswered(profile))
        _ProfileRow(
          color: AppColors.categoryNutrition,
          label: 'Diet',
          value: profile.dietaryRestrictions.isEmpty
              ? 'No restrictions'
              : profile.dietaryRestrictions.map(_dietLabel).join(', '),
        ),
      if (profile.injuries.isNotEmpty || _limitsAnswered(profile))
        _ProfileRow(
          color: AppColors.categoryBody,
          label: 'Limits',
          value: profile.injuries.isEmpty
              ? 'None'
              : profile.injuries.map(_injuryLabel).join(', '),
        ),
      if (profile.trainingExperience != null)
        _ProfileRow(
          color: AppColors.categoryActivity,
          label: 'Training',
          value: _trainingLabel(profile.trainingExperience!),
        ),
      if (profile.sleepPattern != null)
        _ProfileRow(
          color: AppColors.categorySleep,
          label: 'Sleep',
          value: _sleepLabel(profile.sleepPattern!),
        ),
      if (profile.hasAnyIntegration)
        _ProfileRow(
          color: AppColors.categoryActivity,
          label: 'Data',
          value: _integrationSummary(profile.connectedIntegrations),
        ),
      if (profile.discoverySource != null)
        _ProfileRow(
          color: AppColors.categoryBody,
          label: 'Via',
          value: _sourceLabel(profile.discoverySource!),
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
    final age = p.birthday != null ? _ageFromBirthday(p.birthday!) : null;
    final agePart = age != null ? ' · $age yrs' : '';
    return '$sexShort$agePart · ${p.heightCm?.round()} cm · ${p.weightKg?.round()} kg';
  }

  static int _ageFromBirthday(DateTime birthday) {
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
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
        return 'Direct & data-driven';
      case 'warm':
        return 'Warm & encouraging';
      case 'minimal':
        return 'Minimal nudges';
      case 'thorough':
        return 'Thorough & detailed';
      default:
        return toneId;
    }
  }

  static String _integrationSummary(List<String> ids) {
    if (ids.isEmpty) return 'None';
    if (ids.length == 1) return _integrationName(ids.first);
    if (ids.length == 2) {
      return '${_integrationName(ids[0])} & ${_integrationName(ids[1])}';
    }
    return '${ids.length} apps connected';
  }

  static String _integrationName(String id) {
    switch (id) {
      case 'apple_health':
        return 'Apple Health';
      case 'oura':
        return 'Oura';
      case 'strava':
        return 'Strava';
      case 'fitbit':
        return 'Fitbit';
      default:
        return id;
    }
  }

  // Heuristic: treat "empty list" as "answered" only when it coexists with a
  // full onboarding (at least name + tone chosen). Otherwise a blank array
  // on a partially-completed profile shouldn't generate a row.
  static bool _dietAnswered(OnboardingProfile p) =>
      p.name != null && p.tone != null;
  static bool _limitsAnswered(OnboardingProfile p) =>
      p.name != null && p.tone != null;

  static String _dietLabel(String id) {
    switch (id) {
      case 'vegetarian':
        return 'Vegetarian';
      case 'vegan':
        return 'Vegan';
      case 'gluten_free':
        return 'Gluten-free';
      case 'keto':
        return 'Keto';
      case 'halal':
        return 'Halal';
      case 'kosher':
        return 'Kosher';
      case 'other':
        return 'Other';
      default:
        return id;
    }
  }

  static String _injuryLabel(String id) {
    switch (id) {
      case 'lower_back':
        return 'Lower back';
      case 'knees':
        return 'Knees';
      case 'shoulders':
        return 'Shoulders';
      case 'wrists':
        return 'Wrists';
      case 'other':
        return 'Other';
      default:
        return id;
    }
  }

  static String _trainingLabel(String id) {
    switch (id) {
      case 'beginner':
        return 'New to this';
      case 'active':
        return 'Consistently active';
      case 'athletic':
        return 'Highly trained';
      default:
        return id;
    }
  }

  static String _sleepLabel(String id) {
    switch (id) {
      case 'great':
        return 'Sleeps well';
      case 'hard_to_fall_asleep':
        return 'Hard to fall asleep';
      case 'wake_up_a_lot':
        return 'Wakes up often';
      case 'short_hours':
        return 'Short hours';
      default:
        return id;
    }
  }

  static String _sourceLabel(String id) {
    switch (id) {
      case 'friend':
        return 'Friend';
      case 'instagram':
        return 'Instagram';
      case 'tiktok':
        return 'TikTok';
      case 'podcast':
        return 'Podcast';
      case 'app_store':
        return 'App Store';
      case 'doctor':
        return 'Doctor';
      case 'other':
        return 'Somewhere else';
      default:
        return id;
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
