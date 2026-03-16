/// Zuralog Design System — Section Label.
///
/// A row with a bold section heading and an optional "(optional)" suffix.
/// Used by all full-screen log forms to label form sections.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// A section heading with an optional "(optional)" suffix.
class ZSectionLabel extends StatelessWidget {
  const ZSectionLabel({
    super.key,
    required this.label,
    this.isOptional = false,
  });

  final String label;
  final bool isOptional;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        if (isOptional) ...[
          const SizedBox(width: 6),
          Text(
            '(optional)',
            style: AppTextStyles.caption.copyWith(color: colors.textTertiary),
          ),
        ],
      ],
    );
  }
}
