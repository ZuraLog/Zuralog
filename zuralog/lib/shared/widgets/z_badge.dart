/// Zuralog Design System — Badge Widget.
///
/// Brand bible: 16px min diameter, pill shape, 2px canvas border,
/// Label Small Bold 700, white text.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// Badge color variants.
enum ZBadgeVariant {
  /// Red background — errors, unread counts.
  error,

  /// Sage background — positive status, active.
  sage,

  /// Surface raised background — neutral, informational.
  neutral,
}

/// A small pill-shaped label badge with a canvas border to lift it off
/// its parent surface.
///
/// Example:
/// ```dart
/// ZBadge(label: '3', variant: ZBadgeVariant.error)
/// ZBadge(label: 'New', variant: ZBadgeVariant.sage)
/// ZBadge(label: 'Draft', variant: ZBadgeVariant.neutral)
/// ```
class ZBadge extends StatelessWidget {
  const ZBadge({
    super.key,
    required this.label,
    this.variant = ZBadgeVariant.neutral,
    this.color,
    this.textColor,
  }) : assert(
          color == null || variant == ZBadgeVariant.neutral,
          'Custom color only applies to the neutral variant',
        );

  final String label;

  /// Visual variant. Defaults to [ZBadgeVariant.neutral].
  final ZBadgeVariant variant;

  /// Override background color. When set, takes priority over [variant].
  final Color? color;

  /// Override text color. When set, takes priority over the default white.
  final Color? textColor;

  Color _resolvedBg(AppColorsOf colors) {
    if (color != null) return color!;
    switch (variant) {
      case ZBadgeVariant.error:
        return AppColors.error;
      case ZBadgeVariant.sage:
        return colors.primary;
      case ZBadgeVariant.neutral:
        return colors.surfaceRaised;
    }
  }

  String get _semanticLabel => label.isNotEmpty ? label : 'notification badge';

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final fgColor = textColor ?? Colors.white;

    return Semantics(
      label: _semanticLabel,
      container: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 80),
        child: Container(
          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _resolvedBg(colors),
            borderRadius: BorderRadius.circular(AppDimens.shapePill),
            border: Border.all(
              color: colors.canvas,
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
