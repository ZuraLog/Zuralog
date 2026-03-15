/// Zuralog Design System — Section Header Component.
///
/// A reusable heading row with an optional trailing widget and an optional
/// trailing action link. Used throughout the Today feed, Dashboard,
/// Integrations Hub, and other screens to delineate content sections.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// A section heading row with a left accent bar, an optional trailing
/// widget (e.g. a streak badge), and an optional trailing action link.
///
/// Example usage:
/// ```dart
/// SectionHeader(
///   title: 'Good morning, Alex',
///   trailing: StreakBadge.inline(count: 12, isFrozen: false),
/// )
/// SectionHeader(
///   title: 'AI Insights',
///   actionLabel: 'See All',
///   onAction: () => _navigateToInsights(),
/// )
/// ```
class SectionHeader extends StatelessWidget {
  /// The section title displayed on the left.
  final String title;

  /// Optional widget rendered after the title (e.g. a streak badge).
  ///
  /// Takes precedence over [actionLabel]/[onAction] — if both [trailing] and
  /// [actionLabel] are provided, [trailing] is shown and [actionLabel] is ignored.
  final Widget? trailing;

  /// Optional label for the trailing action link (e.g. "See All").
  ///
  /// Rendered as a caption in the theme's secondary colour.
  /// Has no effect if [onAction] is not provided, or if [trailing] is set.
  final String? actionLabel;

  /// Callback invoked when the trailing action is tapped.
  ///
  /// When `null`, no action widget is rendered, even if [actionLabel] is set.
  final VoidCallback? onAction;

  /// Creates a [SectionHeader].
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Editorial left accent bar — 3×18 px primary colour.
        Container(
          width: 3,
          height: 18,
          margin: const EdgeInsets.only(right: AppDimens.spaceSm),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        // Trailing widget takes priority over action label.
        if (trailing != null)
          trailing!
        else if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                actionLabel!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
