/// Maps an achievement icon key to its category color + pattern variant.
library;

import 'package:flutter/material.dart' show Color;

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// Resolves an achievement's category color + pattern variant from its
/// icon key. Streak-related achievements use Streak Warm; success-themed
/// unlocks (gem/crown/trophy) use Nutrition Amber; data unlocks use Body
/// Sky Blue; goal unlocks use Activity Green; everything else falls back
/// to Sage so the page doesn't drown in random colors.
({Color color, ZPatternVariant variant}) achievementCategoryFor(String iconKey) {
  switch (iconKey) {
    case 'flame':
      return (color: AppColors.streakWarm, variant: ZPatternVariant.amber);
    case 'zap':
    case 'gem':
    case 'crown':
    case 'trophy':
    case 'star':
      return (color: AppColors.categoryNutrition, variant: ZPatternVariant.amber);
    case 'bar_chart':
      return (color: AppColors.categoryBody, variant: ZPatternVariant.skyBlue);
    case 'flag':
      return (color: AppColors.categoryActivity, variant: ZPatternVariant.green);
    case 'link':
      return (color: AppColors.categoryWellness, variant: ZPatternVariant.purple);
    default:
      return (color: AppColors.primary, variant: ZPatternVariant.sage);
  }
}
