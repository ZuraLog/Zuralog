/// Zuralog Design System — Spring Press Button Wrapper.
///
/// A reusable wrapper that adds M3 Expressive spring press animation to any
/// child widget. Scale compress to [scaleTarget] on press-down and spring
/// back on release using [AppMotion.fastSpatial].
library;

import 'package:flutter/physics.dart';
import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_motion.dart';

/// Wraps any widget with a spring-physics press animation.
///
/// On press-down, the child scales to [scaleTarget] (default 0.97x) using a
/// [SpringSimulation] driven by [AppMotion.fastSpatial]. On release, it
/// springs back to 1.0 with natural overshoot — giving buttons a satisfying
/// tactile feel.
///
/// Usage:
/// ```dart
/// ZuralogSpringButton(
///   onTap: () => _handleTap(),
///   child: FilledButton(onPressed: null, child: Text('Tap me')),
/// )
/// ```
///
/// Note: [onTap] and [child.onPressed] can both be set. The spring animation
/// is driven by the [GestureDetector] in this wrapper, while the actual action
/// is called via [onTap]. Pass `null` for [onTap] when the child manages its
/// own callback (e.g., a [TextButton] with [onPressed]).
class ZuralogSpringButton extends StatefulWidget {
  /// Creates a [ZuralogSpringButton].
  const ZuralogSpringButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleTarget = 0.97,
    this.disabled = false,
  });

  /// The widget to wrap with the spring animation.
  final Widget child;

  /// Optional tap callback. Called on tap-up after animation spring-back begins.
  final VoidCallback? onTap;

  /// The scale factor applied on press-down (default 0.97).
  final double scaleTarget;

  /// When true, the press animation and [onTap] are disabled.
  final bool disabled;

  @override
  State<ZuralogSpringButton> createState() => _ZuralogSpringButtonState();
}

class _ZuralogSpringButtonState extends State<ZuralogSpringButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  /// Current velocity of the spring simulation — used to preserve momentum
  /// when changing direction (e.g., quick tap-down + release).
  double _velocity = 0;

  @override
  void initState() {
    super.initState();
    // upperBound 1.2 gives overshoot headroom on release bounce-back.
    _controller = AnimationController(
      vsync: this,
      value: 1.0,
      lowerBound: 0,
      upperBound: 1.2,
    );
    _scaleAnim = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target, SpringDescription spring) {
    _velocity = _controller.velocity;
    final sim = SpringSimulation(spring, _controller.value, target, _velocity);
    _controller.animateWith(sim);
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.disabled) return;
    _animateTo(widget.scaleTarget, AppMotion.fastSpatial);
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.disabled) return;
    _animateTo(1.0, AppMotion.fastSpatial);
    widget.onTap?.call();
  }

  void _onTapCancel() {
    if (widget.disabled) return;
    _animateTo(1.0, AppMotion.fastSpatial);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
