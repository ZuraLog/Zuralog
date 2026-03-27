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
class ZuralogCard extends StatelessWidget {
  /// The content widget rendered inside the card.
  final Widget child;

  /// Inner padding around [child].
  ///
  /// When null, defaults based on variant:
  /// - data/plain: 16px
  /// - feature/hero: 20px
  final EdgeInsetsGeometry? padding;

  /// Optional tap callback.
  final VoidCallback? onTap;

  /// Card visual style variant. Defaults to [ZCardVariant.plain].
  final ZCardVariant variant;

  /// Optional health category color for pattern tinting on feature cards.
  ///
  /// When provided on a [ZCardVariant.feature] card, the pattern overlay
  /// uses the matching category color variant via [patternForCategory].
  final Color? category;

  /// Creates a [ZuralogCard].
  const ZuralogCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.variant = ZCardVariant.plain,
    this.category,
  });

  double get _radius {
    switch (variant) {
      case ZCardVariant.data:
        return AppDimens.shapeMd; // 16px
      case ZCardVariant.feature:
      case ZCardVariant.hero:
      case ZCardVariant.plain:
        return AppDimens.shapeLg; // 20px
    }
  }

  EdgeInsetsGeometry get _defaultPadding {
    switch (variant) {
      case ZCardVariant.data:
      case ZCardVariant.plain:
        return const EdgeInsets.all(AppDimens.spaceMd); // 16px
      case ZCardVariant.feature:
      case ZCardVariant.hero:
        return const EdgeInsets.all(AppDimens.spaceMdPlus); // 20px
    }
  }

  bool get _hasPattern =>
      variant == ZCardVariant.feature || variant == ZCardVariant.hero;

  double get _patternOpacity =>
      variant == ZCardVariant.hero ? 0.10 : 0.07;

  ZPatternVariant get _patternVariant {
    if (variant == ZCardVariant.feature && category != null) {
      return patternForCategory(category!);
    }
    return ZPatternVariant.original;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(_radius);
    final effectivePadding = padding ?? _defaultPadding;

    // Build the card body with optional pattern overlay
    Widget body;
    if (_hasPattern) {
      body = Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: borderRadius,
              ),
            ),
          ),
          // Pattern overlay
          ClipRRect(
            borderRadius: borderRadius,
            child: ZPatternOverlay(
              variant: _patternVariant,
              opacity: _patternOpacity,
              blendMode: BlendMode.screen,
            ),
          ),
          // Content
          Padding(padding: effectivePadding, child: child),
        ],
      );
    } else {
      body = Container(
        padding: effectivePadding,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : theme.colorScheme.surface,
          borderRadius: borderRadius,
          // Light mode only: soft shadow
          boxShadow: isDark ? null : AppDimens.cardShadowLight,
        ),
        child: child,
      );
    }

    // Wrap in InkWell for tap support
    if (onTap != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          color: _hasPattern
              ? AppColors.surface
              : (isDark ? AppColors.surface : theme.colorScheme.surface),
          child: InkWell(
            onTap: onTap,
            child: _hasPattern
                ? body
                : Padding(
                    padding: effectivePadding,
                    child: child,
                  ),
          ),
        ),
      );
    }

    return body;
  }
}
