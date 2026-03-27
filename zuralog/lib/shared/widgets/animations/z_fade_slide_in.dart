/// Zuralog Design System — Fade + Slide Entrance Animation.
library;

import 'dart:async';

import 'package:flutter/material.dart';

/// Animates its child from a slight downward offset to its natural position
/// while fading in from transparent to opaque.
///
/// Acceptable StatefulWidget exception: requires [TickerProviderStateMixin]
/// for [AnimationController].
///
/// Example:
/// ```dart
/// ZFadeSlideIn(
///   delay: Duration(milliseconds: 200),
///   child: MyCard(),
/// )
/// ```
class ZFadeSlideIn extends StatefulWidget {
  const ZFadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 12.0,
    this.duration = const Duration(milliseconds: 400),
  });

  /// The widget to animate.
  final Widget child;

  /// Delay before the animation starts.
  final Duration delay;

  /// Initial vertical offset in logical pixels (positive = starts below).
  final double offset;

  /// Duration of the fade + slide animation.
  final Duration duration;

  @override
  State<ZFadeSlideIn> createState() => _ZFadeSlideInState();
}

class _ZFadeSlideInState extends State<ZFadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _slide;
  Timer? _delayTimer;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<double>(begin: widget.offset, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.of(context).disableAnimations;

    // Skip animation entirely when the user requests reduced motion.
    if (_reducedMotion) {
      _delayTimer?.cancel();
      _controller.value = 1.0;
      return;
    }

    // Start animation (only once — controller already completed is a no-op).
    if (!_controller.isAnimating && !_controller.isCompleted) {
      if (widget.delay == Duration.zero) {
        _controller.forward();
      } else {
        _delayTimer ??= Timer(widget.delay, () {
          if (mounted) _controller.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When reduced motion is enabled, render the child directly — no wrappers.
    if (_reducedMotion) return widget.child;

    // FadeTransition is a ListenableBuilder internally and avoids the extra
    // per-frame Opacity widget rebuild. AnimatedBuilder handles the translate
    // and passes the already-fading subtree as its pre-built child.
    return AnimatedBuilder(
      animation: _slide,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _slide.value),
        child: child,
      ),
      child: FadeTransition(
        opacity: _opacity,
        child: widget.child,
      ),
    );
  }
}
