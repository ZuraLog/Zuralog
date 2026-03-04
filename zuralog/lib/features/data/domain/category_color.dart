/// Zuralog — Category Color Resolver.
///
/// Provides a single top-level function [categoryColor] that maps a
/// [HealthCategory] enum value to its design-system colour token.
///
/// Previously duplicated as a private `_categoryColor` helper in three
/// screens; extracted here so all Data-tab screens share one source of truth.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/data/domain/data_models.dart';

/// Returns the [AppColors.category*] token for [cat].
///
/// All 10 categories are handled; the switch is exhaustive so adding a new
/// category will surface a compile error here.
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
