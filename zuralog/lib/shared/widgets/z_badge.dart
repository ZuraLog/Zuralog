/// Zuralog Design System — Badge / Chip Widget.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// A small pill-shaped label badge.
///
/// Example:
/// ```dart
/// ZBadge(label: 'Activity', color: AppColors.categoryActivity)
/// ZBadge(label: 'New')  // uses theme primary
/// ```
class ZBadge extends StatelessWidget {
  const ZBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
  });

  final String label;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = color ?? colorScheme.primaryContainer;
    final fgColor = textColor ?? colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimens.shapePill),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: fgColor),
      ),
    );
  }
}
