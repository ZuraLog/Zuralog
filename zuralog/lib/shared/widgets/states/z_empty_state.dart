/// Zuralog Design System — Empty State Widget.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/buttons/z_button.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// Displays an icon, title, optional message, and optional action button
/// when a screen has no content to show.
///
/// Uses a feature card treatment with a subtle pattern overlay, 36px icon,
/// and centered layout per brand bible.
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
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.shapeLg),
        child: Container(
          decoration: BoxDecoration(
            color: AppColorsOf(context).surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeLg),
          ),
          child: Stack(
            children: [
              // Pattern overlay (bottom layer).
              const Positioned.fill(
                child: IgnorePointer(
                  child: ZPatternOverlay(
                    opacity: 0.06,
                    blendMode: BlendMode.screen,
                  ),
                ),
              ),
              // Content (top layer).
              Padding(
                padding: const EdgeInsets.all(AppDimens.spaceXl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 36,
                      color: AppColorsOf(context).textSecondary,
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    Text(
                      title,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColorsOf(context).textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (message != null) ...[
                      const SizedBox(height: AppDimens.spaceSm),
                      Text(
                        message!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColorsOf(context).textSecondary,
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
            ],
          ),
        ),
      ),
    );
  }
}
