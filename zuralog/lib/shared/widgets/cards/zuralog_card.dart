/// Zuralog Design System — Card Component.
///
/// A theme-aware card with variant support for different visual treatments:
/// - `data`: compact data display, no pattern
/// - `feature`: mid-level cards with subtle pattern
/// - `hero`: prominent cards with stronger pattern
/// - `plain`: backwards-compatible default, no pattern
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// Card visual style variants.
enum ZCardVariant {
  /// Compact data display: 16px radius, 16px padding, no pattern, no border.
  data,

  /// Mid-level feature card: 20px radius, 20px padding, subtle pattern (0.07).
  feature,

  /// Prominent hero card: 20px radius, 20px padding, stronger pattern (0.10).
  hero,

  /// Backwards-compatible plain card: 20px radius, 16px padding, no pattern.
  plain,
}

/// Theme-aware card component for the Zuralog design system.
///
/// Example usage:
/// ```dart
/// ZuralogCard(
///   variant: ZCardVariant.feature,
///   category: AppColors.categoryActivity,
///   onTap: () => _handleTap(),
///   child: Text('Card content'),
/// )
/// ```
class ZuralogCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final ZCardVariant variant;
  final Color? category;

  const ZuralogCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.variant = ZCardVariant.plain,
    this.category,
  });

  @override
  State<ZuralogCard> createState() => _ZuralogCardState();
}

class _ZuralogCardState extends State<ZuralogCard> {
  bool _isPressed = false;

  double get _radius {
    switch (widget.variant) {
      case ZCardVariant.data:
        return AppDimens.shapeMd;
      case ZCardVariant.feature:
      case ZCardVariant.hero:
      case ZCardVariant.plain:
        return AppDimens.shapeLg;
    }
  }

  EdgeInsetsGeometry get _defaultPadding {
    switch (widget.variant) {
      case ZCardVariant.data:
      case ZCardVariant.plain:
        return const EdgeInsets.all(AppDimens.spaceMd);
      case ZCardVariant.feature:
      case ZCardVariant.hero:
        return const EdgeInsets.all(AppDimens.spaceMdPlus);
    }
  }

  bool get _hasPattern =>
      widget.variant == ZCardVariant.feature || widget.variant == ZCardVariant.hero;

  double get _patternOpacity => widget.variant == ZCardVariant.hero ? 0.10 : 0.07;

  bool get _patternAnimated => widget.variant == ZCardVariant.hero;

  ZPatternVariant get _patternVariant {
    if (widget.variant == ZCardVariant.feature && widget.category != null) {
      return patternForCategory(widget.category!);
    }
    return ZPatternVariant.original;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColorsOf(context);
    final borderRadius = BorderRadius.circular(_radius);
    final effectivePadding = widget.padding ?? _defaultPadding;

    Widget body;
    if (_hasPattern) {
      body = ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: borderRadius,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ZPatternOverlay(
                  variant: _patternVariant,
                  opacity: _patternOpacity,
                  animate: _patternAnimated,
                ),
              ),
              Padding(padding: effectivePadding, child: widget.child),
            ],
          ),
        ),
      );
    } else {
      body = Container(
        padding: effectivePadding,
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: borderRadius,
          boxShadow: isDark ? null : AppDimens.cardShadowLight,
        ),
        child: widget.child,
      );
    }

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: borderRadius,
              child: ClipRRect(borderRadius: borderRadius, child: body),
            ),
          ),
        ),
      );
    }

    return body;
  }
}
