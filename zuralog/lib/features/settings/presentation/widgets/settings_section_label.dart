/// Shared settings section label widget.
///
/// ALL_CAPS label with tertiary text color, used as section headers throughout
/// the settings screens. Extracted to avoid duplication across 6+ files.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Section label for settings groups — renders [label] in ALL_CAPS with the
/// design-system section header style.
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceXs,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelXs.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
