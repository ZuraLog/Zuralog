/// Zuralog Design System — Category Color Resolver.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/data/domain/data_models.dart';

/// Returns the [AppColors.category*] token for [cat].
Color categoryColor(HealthCategory cat) {
  switch (cat) {
    case HealthCategory.activity:
      return AppColors.categoryActivity;
    case HealthCategory.sleep:
      return AppColors.categorySleep;
    case HealthCategory.body:
      return AppColors.categoryBody;
    case HealthCategory.heart:
      return AppColors.categoryHeart;
    case HealthCategory.vitals:
      return AppColors.categoryVitals;
    case HealthCategory.nutrition:
      return AppColors.categoryNutrition;
    case HealthCategory.cycle:
      return AppColors.categoryCycle;
    case HealthCategory.wellness:
      return AppColors.categoryWellness;
    case HealthCategory.mobility:
      return AppColors.categoryMobility;
    case HealthCategory.environment:
      return AppColors.categoryEnvironment;
  }
}

/// Returns the [AppColors.category*] token for a category name string.
/// Case-insensitive. Returns [fallback] (defaults to [AppColors.primary])
/// for unknown strings. Pass a theme-aware color when you have a BuildContext.
Color categoryColorFromString(String category, {Color? fallback}) {
  switch (category.toLowerCase()) {
    case 'activity':
      return AppColors.categoryActivity;
    case 'sleep':
      return AppColors.categorySleep;
    case 'body':
      return AppColors.categoryBody;
    case 'heart':
      return AppColors.categoryHeart;
    case 'vitals':
      return AppColors.categoryVitals;
    case 'nutrition':
      return AppColors.categoryNutrition;
    case 'cycle':
      return AppColors.categoryCycle;
    case 'wellness':
      return AppColors.categoryWellness;
    case 'mobility':
      return AppColors.categoryMobility;
    case 'environment':
      return AppColors.categoryEnvironment;
    default:
      return fallback ?? AppColors.primary;
  }
}
