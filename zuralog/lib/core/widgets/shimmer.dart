/// Zuralog — Shared shimmer animation widgets.
///
/// [AppShimmer] wraps any child in a left-to-right shimmer sweep using
/// [ShaderMask] + [LinearGradient]. [ShimmerBox] is a plain white placeholder
/// shape — [AppShimmer] applies the animated gradient over it.
///
/// Usage:
/// ```dart
/// AppShimmer(
///   child: Column(children: [
///     ShimmerBox(height: 12, width: 80),
///     ShimmerBox(height: 24, widthFraction: 0.6),
///   ]),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';

// ── AppShimmer ─────────────────────────────────────────────────────────────────

/// Wraps [child] in an animated left-to-right shimmer sweep.
///
/// Uses [ShaderMask] + [LinearGradient] so all [ShimmerBox] descendants are
/// animated in perfect sync from a single [AnimationController].
///
/// Child shapes MUST use opaque fill (e.g. [Colors.white]) — [BlendMode.srcIn]
/// uses the child's alpha channel as the mask for the gradient.
///
/// Does NOT apply [ExcludeSemantics] internally — callers provide their own
/// [Semantics] wrapper with an appropriate label.
class AppShimmer extends StatefulWidget {
  const AppShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _animation.value; // 0.0 → 1.0, eased
        // Sweep gradient from left-off-screen (-2) to right-off-screen (+2)
        final begin = Alignment(-2.0 + 4.0 * t, 0);
        final end = Alignment(-1.0 + 4.0 * t, 0);
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: begin,
            end: end,
            colors: [
              colors.shimmerBase,
              colors.shimmerHighlight,
              colors.shimmerBase,
            ],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ── ShimmerBox ─────────────────────────────────────────────────────────────────

/// A stateless placeholder shape for use inside [AppShimmer].
///
/// Renders as a solid white [Container] (the [ShaderMask] replaces white with
/// the shimmer gradient). When [height] and [width] are both omitted, the
/// widget expands to fill its parent — use inside [Expanded] for chart-area
/// placeholders.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.height,
    this.width,
    this.widthFraction,
    this.borderRadius,
    this.isCircle = false,
  });

  /// Fixed height. Omit when inside [Expanded] (fills available space).
  final double? height;

  /// Fixed width. Omit to let parent constrain.
  final double? width;

  /// Fractional width 0–1. Uses [FractionallySizedBox] when provided.
  /// Mutually exclusive with [width].
  final double? widthFraction;

  /// Corner radius. Defaults to `BorderRadius.circular(4)`.
  /// Ignored when [isCircle] is true.
  final BorderRadius? borderRadius;

  /// Renders as a circle (`BoxShape.circle`). [height] is used as diameter.
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      height: height,
      width: widthFraction != null ? null : width,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle
            ? null
            : (borderRadius ?? BorderRadius.circular(4)),
      ),
    );

    if (widthFraction != null) {
      return FractionallySizedBox(
        widthFactor: widthFraction,
        alignment: Alignment.centerLeft,
        child: box,
      );
    }
    return box;
  }
}
