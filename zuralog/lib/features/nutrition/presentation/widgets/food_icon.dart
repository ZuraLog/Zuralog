/// A 32×32 tinted tile showing a food-specific icon.
///
/// Used in both the meal review parsed-food list and the meal detail foods
/// list. Pass [confidence] on the review path to colour the tile green /
/// amber / red based on the AI parser's confidence. Omit [confidence] on
/// post-save surfaces (meal detail) to get the neutral brand colour.
library;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/nutrition/domain/food_icon.dart';

class FoodIcon extends StatelessWidget {
  const FoodIcon({
    super.key,
    required this.foodName,
    this.confidence,
  });

  final String foodName;

  /// Parser confidence score (0.0–1.0). When provided, drives the tile
  /// colour. When null, the tile uses the neutral brand colour.
  final double? confidence;

  Color _colorForConfidence(double c) {
    if (c >= 0.8) return AppColors.success;
    if (c >= 0.5) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final color = confidence == null
        ? AppColors.categoryNutrition
        : _colorForConfidence(confidence!);
    final icon = iconForFood(foodName);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.shapeSm),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Center(
        child: FaIcon(icon, size: 14, color: color),
      ),
    );
  }
}
