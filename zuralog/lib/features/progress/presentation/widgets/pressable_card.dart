library;

import 'package:flutter/material.dart';

class PressableCard extends StatefulWidget {
  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 16.0,
    this.semanticsLabel,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  /// Optional label announced by screen readers when this card is focused.
  final String? semanticsLabel;

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final detector = GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _scale = 0.97) : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _scale = 1.0);
              widget.onTap!();
            }
          : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _scale = 1.0) : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );

    if (widget.semanticsLabel != null) {
      return Semantics(
        label: widget.semanticsLabel,
        button: widget.onTap != null,
        child: detector,
      );
    }
    return detector;
  }
}
