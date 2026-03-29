/// Zuralog Design System — Password Requirements Checklist Widget.
///
/// Displays a live checklist of password requirements below a password field.
/// Collapses entirely once all requirements are satisfied.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// Animated checklist that shows which password requirements have been met.
///
/// Renders one row per requirement. Each row transitions its icon smoothly
/// via [AnimatedSwitcher] when its requirement flips from unmet to met.
///
/// The entire widget collapses to nothing (via [AnimatedSize]) once all three
/// requirements are satisfied, keeping the screen uncluttered after the user
/// has typed a valid password.
///
/// Requirements checked:
/// - At least 8 characters
/// - At least one number (0–9)
/// - At least one symbol (any character that is not a letter or digit)
class ZPasswordRequirements extends StatelessWidget {
  /// Creates a [ZPasswordRequirements] widget.
  ///
  /// [password] is the current value of the password field and must not be
  /// null. Pass an empty string when the field is empty.
  const ZPasswordRequirements({super.key, required this.password});

  /// The current password string to evaluate against the requirements.
  final String password;

  // ── Requirement checks ──────────────────────────────────────────────────

  bool get _hasLength => password.length >= 8;
  bool get _hasDigit => password.contains(RegExp(r'[0-9]'));
  bool get _hasSymbol => password.contains(RegExp(r'[^a-zA-Z0-9]'));

  bool get _allMet => _hasLength && _hasDigit && _hasSymbol;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: _allMet
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: AppDimens.spaceSm),
                _RequirementRow(
                  label: 'At least 8 characters',
                  isMet: _hasLength,
                  colors: colors,
                ),
                SizedBox(height: AppDimens.spaceXs),
                _RequirementRow(
                  label: 'At least one number',
                  isMet: _hasDigit,
                  colors: colors,
                ),
                SizedBox(height: AppDimens.spaceXs),
                _RequirementRow(
                  label: 'At least one symbol',
                  isMet: _hasSymbol,
                  colors: colors,
                ),
              ],
            ),
    );
  }
}

/// A single requirement row with an animated icon and a label.
class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.label,
    required this.isMet,
    required this.colors,
  });

  final String label;
  final bool isMet;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: isMet
              ? Icon(
                  Icons.check_circle_rounded,
                  key: const ValueKey(true),
                  size: 16,
                  color: AppColors.statusConnected,
                )
              : Icon(
                  Icons.circle_outlined,
                  key: const ValueKey(false),
                  size: 16,
                  color: colors.textSecondary,
                ),
        ),
        SizedBox(width: AppDimens.spaceSm),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
