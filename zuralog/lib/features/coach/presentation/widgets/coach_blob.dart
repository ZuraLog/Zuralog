/// Zuralog Coach — Animated Blob Mascot.
///
/// An organic morphing shape that visualizes Zura's current activity:
/// - [BlobState.idle]     — slow 6 s breathing cycle, sage glow shadow
/// - [BlobState.thinking] — fast 0.8 s erratic cycle, no shadow
/// - [BlobState.talking]  — medium 1.2 s smooth cycle, no shadow
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';

/// Describes what Zura is currently doing — drives blob animation speed/feel.
enum BlobState {
  /// Waiting for user input. Slow breathing morph, sage glow.
  idle,

  /// AI is generating — no tokens yet (or a tool is running).
  /// Fast, erratic morph.
  thinking,

  /// Tokens are streaming in. Smooth medium-speed morph.
  talking,
}

/// Animated organic blob that represents Zura's presence.
///
/// Pass [state] to switch animation modes. Pass [size] (80 for idle hero,
/// 28 for the conversation footer).
class CoachBlob extends StatefulWidget {
  const CoachBlob({super.key, required this.state, required this.size});

  final BlobState state;
  final double size;

  @override
  State<CoachBlob> createState() => _CoachBlobState();
}

class _CoachBlobState extends State<CoachBlob>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late final Animation<BorderRadius?> _borderRadiusAnim;

  // Four organic border-radius keyframes scaled relative to widget size so
  // the shape stays visually organic at every size (28 px footer or 80 px hero).
  List<BorderRadius> _computeShapes(double size) {
    return [
      BorderRadius.only(
        topLeft: Radius.circular(size * 0.75),
        topRight: Radius.circular(size * 0.47),
        bottomLeft: Radius.circular(size * 0.60),
        bottomRight: Radius.circular(size * 0.70),
      ),
      BorderRadius.only(
        topLeft: Radius.circular(size * 0.55),
        topRight: Radius.circular(size * 0.77),
        bottomLeft: Radius.circular(size * 0.70),
        bottomRight: Radius.circular(size * 0.45),
      ),
      BorderRadius.only(
        topLeft: Radius.circular(size * 0.67),
        topRight: Radius.circular(size * 0.55),
        bottomLeft: Radius.circular(size * 0.47),
        bottomRight: Radius.circular(size * 0.77),
      ),
      BorderRadius.only(
        topLeft: Radius.circular(size * 0.50),
        topRight: Radius.circular(size * 0.70),
        bottomLeft: Radius.circular(size * 0.75),
        bottomRight: Radius.circular(size * 0.52),
      ),
    ];
  }

  Duration get _duration {
    return switch (widget.state) {
      BlobState.idle => const Duration(seconds: 6),
      BlobState.thinking => const Duration(milliseconds: 800),
      BlobState.talking => const Duration(milliseconds: 1200),
    };
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    final shapes = _computeShapes(widget.size);
    _borderRadiusAnim = TweenSequence<BorderRadius?>([
      TweenSequenceItem(
        tween: BorderRadiusTween(begin: shapes[0], end: shapes[1]),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: BorderRadiusTween(begin: shapes[1], end: shapes[2]),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: BorderRadiusTween(begin: shapes[2], end: shapes[3]),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: BorderRadiusTween(begin: shapes[3], end: shapes[0]),
        weight: 1,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat();
  }

  @override
  void didUpdateWidget(CoachBlob oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _controller.duration = _duration;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showShadow = widget.state == BlobState.idle;
    return AnimatedBuilder(
      animation: _borderRadiusAnim,
      builder: (context, _) {
        final radius = _borderRadiusAnim.value ?? _computeShapes(widget.size)[0];
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: radius,
            border: Border.all(
              color: AppColors.primary,
              width: 1.5,
            ),
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.20),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
