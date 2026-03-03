/// Zuralog — StreakBadge widget.
///
/// Displays a flame icon + streak count and an optional shield icon when a
/// streak freeze is active. Two variants:
///
/// - **inline**: tight, used inside card headers and list rows.
/// - **standalone**: larger, used as a hero element on Progress Home.
///
/// ## Design spec
/// - Flame icon: `Icons.local_fire_department_rounded` in amber.
/// - Shield icon: `Icons.shield_rounded` in sage-green (freeze active).
/// - Count text: `AppTextStyles.h3` (standalone) / `AppTextStyles.caption` (inline).
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── StreakBadge ───────────────────────────────────────────────────────────────

/// A compact flame + count badge for streak display.
class StreakBadge extends StatelessWidget {
  // ── Constructors ───────────────────────────────────────────────────────────

  /// Inline variant — small, used in card headers and rows.
  const StreakBadge.inline({
    super.key,
    required this.count,
    this.isFrozen = false,
  }) : _standalone = false;

  /// Standalone variant — larger, used on Progress Home as a hero element.
  const StreakBadge.standalone({
    super.key,
    required this.count,
    this.isFrozen = false,
  }) : _standalone = true;

  // ── Properties ─────────────────────────────────────────────────────────────

  /// The current streak count.
  final int count;

  /// When `true` the shield icon is shown (freeze active).
  final bool isFrozen;

  final bool _standalone;

  @override
  Widget build(BuildContext context) {
    final double iconSize = _standalone ? 28 : 16;
    final TextStyle countStyle = _standalone
        ? AppTextStyles.h2.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          )
        : AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.local_fire_department_rounded,
          size: iconSize,
          color: AppColors.healthScoreAmber,
        ),
        const SizedBox(width: 2),
        Text('$count', style: countStyle),
        if (isFrozen) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.shield_rounded,
            size: iconSize * 0.85,
            color: AppColors.primary,
          ),
        ],
      ],
    );
  }
}
