/// Zuralog Design System — Section Header Component.
///
/// A reusable heading row with an optional trailing action link.
/// Used throughout the Dashboard, Integrations Hub, and other screens
/// to delineate content sections consistently.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_text_styles.dart';

/// A section heading row with an optional trailing action.
///
/// Renders the [title] in H3 (Headline, 17pt SemiBold) style and,
/// when provided, a [actionLabel] on the right as a tappable caption.
///
/// Example usage:
/// ```dart
/// SectionHeader(
///   title: 'Health Metrics',
///   actionLabel: 'See All',
///   onAction: () => _navigateToMetrics(),
/// )
/// ```
class SectionHeader extends StatelessWidget {
  /// The section title displayed on the left.
  final String title;

  /// Optional label for the trailing action link (e.g., "See All").
  ///
  /// Rendered as a caption in the theme's secondary color.
  /// Has no effect if [onAction] is not provided.
  final String? actionLabel;

  /// Callback invoked when the trailing action is tapped.
  ///
  /// When `null`, no action widget is rendered, even if [actionLabel] is set.
  final VoidCallback? onAction;

  /// Creates a [SectionHeader].
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: AppTextStyles.h3.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              // Extra padding for a comfortable touch target.
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                actionLabel!,
                style: AppTextStyles.caption.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
