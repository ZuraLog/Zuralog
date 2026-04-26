/// Zuralog Design System — Audio Visualizer.
///
/// Displays 5 animated vertical bars that react to microphone audio level.
/// Used during voice recording in the wellness panel.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';

/// Animated audio level visualizer showing 5 pulsing bars.
///
/// Pass [level] between 0.0 (silent) and 1.0 (loudest).  At 0.0 all bars sit
/// at their minimum height giving a flat-line appearance.  Above 0.0 each bar
/// pulses independently at a slightly different phase.
///
/// The widget is purely decorative and is excluded from the accessibility tree.
class ZAudioVisualizer extends StatefulWidget {
  /// Creates a [ZAudioVisualizer].
  const ZAudioVisualizer({super.key, required this.level});

  /// Current audio level from 0.0 (silent) to 1.0 (loudest).
  final double level;

  @override
  State<ZAudioVisualizer> createState() => _ZAudioVisualizerState();
}

class _ZAudioVisualizerState extends State<ZAudioVisualizer>
    with SingleTickerProviderStateMixin {
  // ── constants ─────────────────────────────────────────────────────────────

  static const int _barCount = 5;
  static const double _barWidth = 4.0;
  static const double _barSpacing = 6.0; // 3px each side
  static const double _maxBarHeight = 32.0;
  static const double _minBarHeight = 4.0;
  static const double _borderRadius = 2.0;

  /// Phase offsets keep each bar pulsing at a different point in the cycle.
  static const List<double> _phaseOffsets = [0.0, 0.4, 0.8, 0.2, 0.6];

  // ── animation ─────────────────────────────────────────────────────────────

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Returns a 0–1 pulse value for [barIndex] based on the controller's
  /// current progress and the bar's phase offset.
  double _pulse(int barIndex) {
    final progress = (_controller.value + _phaseOffsets[barIndex]) % 1.0;
    // sin maps [0, 2π] → [-1, 1]; shift + scale to [0, 1].
    return (math.sin(progress * 2 * math.pi) + 1.0) / 2.0;
  }

  double _barHeight(int barIndex) {
    final level = widget.level.clamp(0.0, 1.0);
    return _minBarHeight +
        (_maxBarHeight - _minBarHeight) * level * _pulse(barIndex);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_barCount, (i) {
              final height = _barHeight(i);
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _barSpacing / 2,
                ),
                child: Container(
                  width: _barWidth,
                  height: height,
                  decoration: BoxDecoration(
                    color: AppColors.categoryWellness,
                    borderRadius: BorderRadius.circular(_borderRadius),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
