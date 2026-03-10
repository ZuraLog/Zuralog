/// Zuralog Design System — Empty State Widget.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';

/// Displays an icon, title, optional message, and optional action button
/// when a screen has no content to show.
///
/// Example:
/// ```dart
/// ZEmptyState(
///   icon: Icons.bar_chart_outlined,
///   title: 'No data yet',
///   message: 'Connect a health app to get started.',
///   actionLabel: 'Connect App',
///   onAction: () => _navigateToConnections(),
/// )
/// ```
class ZEmptyState extends StatelessWidget {
  const ZEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                message!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppDimens.spaceLg),
              ZButton(
                label: actionLabel!,
                onPressed: onAction,
                isFullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
