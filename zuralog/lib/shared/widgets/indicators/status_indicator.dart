/// Zuralog Design System — Status Indicator Component.
///
/// A small colored dot with an accompanying text label.
/// Used for sync status, connection state, and the chat "Online" indicator.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// A small colored status dot with a text label.
///
/// Renders an 8px circle in [color] alongside a [label] in caption style.
/// The [pulsing] flag is accepted for API compatibility but the animation
/// is deferred to Phase 2.3.2 (Animations & Transitions).
///
/// Common usage patterns:
/// - Chat online indicator: `StatusIndicator(color: AppColors.primary, label: 'Online', pulsing: true)`
/// - Sync status: `StatusIndicator(color: Colors.green, label: 'Synced 2m ago')`
/// - Disconnected: `StatusIndicator(color: AppColors.textSecondary, label: 'Not connected')`
///
/// Example usage:
/// ```dart
/// StatusIndicator(
///   color: AppColors.primary,
///   label: 'Online',
///   pulsing: true,
/// )
/// ```
class StatusIndicator extends StatelessWidget {
  /// The color of the status dot.
  final Color color;

  /// The text label displayed next to the dot.
  final String label;

  /// Whether the dot should pulse with an animation.
  ///
  /// Currently accepted for API compatibility only.
  /// Pulse animation will be implemented in Phase 2.3.2.
  final bool pulsing;

  /// Creates a [StatusIndicator].
  const StatusIndicator({
    super.key,
    required this.color,
    required this.label,
    this.pulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Status dot — fixed 8px circle.
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
