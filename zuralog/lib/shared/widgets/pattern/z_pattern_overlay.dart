/// Zuralog Design System — Pattern Overlay Component.
///
/// The single source of truth for applying the brand topographic contour-line
/// pattern to any surface. Uses a stretched cover approach (matching the website)
/// with an optional slow diagonal drift animation.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';

/// Which pre-colored pattern variant to use.
///
/// Each maps to a PNG in `assets/brand/pattern/`.
enum ZPatternVariant {
  original('Original.PNG'),
  sage('Sage.PNG'),
  crimson('Crimson.PNG'),
  green('Green.PNG'),
  periwinkle('Periwinkle.PNG'),
  rose('Rose.PNG'),
  amber('Amber.PNG'),
  skyBlue('Sky Blue.PNG'),
  teal('Teal.PNG'),
  purple('Purple.PNG'),
  yellow('Yellow.PNG'),
  mint('Mint.PNG');

  const ZPatternVariant(this.filename);
  final String filename;
  String get assetPath => 'assets/brand/pattern/$filename';
}

/// Returns the effective [ZPatternVariant] for the current theme.
///
/// In light mode, [ZPatternVariant.sage] is swapped for [ZPatternVariant.original]
/// to match the CSS rule: `--ds-pattern-sage: url('/patterns/original.png')`.
ZPatternVariant effectivePatternVariant(ZPatternVariant requested, bool isLight) {
  if (isLight && requested == ZPatternVariant.sage) return ZPatternVariant.original;
  return requested;
}

/// Returns the effective opacity for the current theme.
///
/// In light mode, opacity is multiplied by 1.6 (capped at 1.0) to compensate
/// for the lack of CSS `mix-blend-mode: color-burn` on light surfaces.
double effectivePatternOpacity(double opacity, bool isLight) {
  return isLight ? (opacity * 1.6).clamp(0.0, 1.0) : opacity;
}

/// Returns the correct pattern variant for a health category color.
ZPatternVariant patternForCategory(Color category) {
  if (category == AppColors.categoryActivity) return ZPatternVariant.green;
  if (category == AppColors.categorySleep) return ZPatternVariant.periwinkle;
  if (category == AppColors.categoryHeart) return ZPatternVariant.rose;
  if (category == AppColors.categoryNutrition) return ZPatternVariant.amber;
  if (category == AppColors.categoryBody) return ZPatternVariant.skyBlue;
  if (category == AppColors.categoryVitals) return ZPatternVariant.teal;
  if (category == AppColors.categoryWellness) return ZPatternVariant.purple;
  if (category == AppColors.categoryCycle) return ZPatternVariant.rose;
  if (category == AppColors.categoryMobility) return ZPatternVariant.yellow;
  if (category == AppColors.categoryEnvironment) return ZPatternVariant.teal;
  return ZPatternVariant.original;
}

/// Applies the brand topographic contour-line pattern over its parent.
///
/// This is a decorative overlay — it sits on top of content and is
/// marked non-interactive ([IgnorePointer]) and non-accessible
/// ([ExcludeSemantics]).
///
/// The pattern PNG is stretched to cover the entire surface (matching the
/// website implementation) instead of being tiled in a grid.
///
/// When [animate] is true, the pattern drifts slowly on a diagonal — the
/// same effect the website uses on buttons and hero sections.
///
/// ## Usage
///
/// ```dart
/// Stack(
///   children: [
///     Container(color: AppColors.surface),
///     ZPatternOverlay(
///       variant: ZPatternVariant.original,
///       opacity: 0.07,
///       animate: true,
///     ),
///     Padding(padding: ..., child: ...),
///   ],
/// )
/// ```
class ZPatternOverlay extends StatefulWidget {
  const ZPatternOverlay({
    super.key,
    this.variant = ZPatternVariant.original,
    this.opacity = 0.07,
    this.blendMode = BlendMode.screen,
    this.animate = false,
  });

  /// Which pre-colored pattern PNG to use.
  final ZPatternVariant variant;

  /// Pattern opacity (0.0 – 1.0). Recommended values in dark mode:
  /// - Hero cards: 0.10
  /// - Feature cards: 0.07
  /// - Buttons (primary/destructive): 0.60
  /// - FAB: 0.50
  /// - Empty states: 0.06
  /// - Search bar: 0.05
  /// - Tab track: 0.04
  ///
  /// In light mode, this value is automatically multiplied by 1.6 (capped at 1.0)
  /// to compensate for the absence of CSS `mix-blend-mode: color-burn`.
  final double opacity;

  /// Kept for API compatibility but no longer used for rendering.
  /// The pre-colored PNGs combined with opacity produce the correct
  /// look on both light and dark surfaces without blend modes.
  final BlendMode blendMode;

  /// When true, the pattern drifts slowly on a diagonal (20-second loop).
  /// Respects the system reduced-motion setting — if the user has asked
  /// for less motion, the pattern stays static.
  final bool animate;

  @override
  State<ZPatternOverlay> createState() => _ZPatternOverlayState();
}

class _ZPatternOverlayState extends State<ZPatternOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  static const _start = Alignment(-0.5, -0.5);
  static const _end = Alignment(0.5, 0.5);

  @override
  void initState() {
    super.initState();
    _maybeStartAnimation();
  }

  @override
  void didUpdateWidget(ZPatternOverlay old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate) {
      if (widget.animate) {
        _maybeStartAnimation();
      } else {
        _disposeAnimation();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-evaluate animation when reduced-motion setting changes.
    if (widget.animate) {
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      if (reduceMotion && _controller != null) {
        _disposeAnimation();
      } else if (!reduceMotion && _controller == null) {
        _maybeStartAnimation();
      }
    }
  }

  void _maybeStartAnimation() {
    if (!widget.animate) return;
    // Defer the reduced-motion check — MediaQuery is not available in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      if (reduceMotion) return;
      _controller ??= AnimationController(
        vsync: this,
        duration: const Duration(seconds: 20),
      )..repeat(reverse: true);
      if (mounted) setState(() {});
    });
  }

  void _disposeAnimation() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeAnimation();
    super.dispose();
  }

  Alignment get _currentAlignment {
    if (_controller == null) return Alignment.center;
    return Alignment.lerp(_start, _end, _controller!.value)!;
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final resolvedOpacity = effectivePatternOpacity(widget.opacity, isLight);
    final resolvedVariant = effectivePatternVariant(widget.variant, isLight);

    final alignment = _controller != null
        ? AnimatedBuilder(
            animation: _controller!,
            builder: (context, child) =>
                _buildContainer(_currentAlignment, resolvedVariant),
          )
        : _buildContainer(Alignment.center, resolvedVariant);

    return ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(
          opacity: resolvedOpacity,
          child: alignment,
        ),
      ),
    );
  }

  Widget _buildContainer(Alignment alignment, ZPatternVariant variant) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(variant.assetPath),
          fit: BoxFit.cover,
          alignment: alignment,
        ),
      ),
    );
  }
}
