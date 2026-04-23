/// Zuralog Design System — Segmented Progress Pill.
///
/// Renders N thin pill segments side-by-side. Segments at or before
/// [currentStep] are filled in Sage; later segments are muted.
///
/// Used on every screen of the Act 3 personalization flow and anywhere
/// else a short multi-step progress is communicated.
///
/// ## Usage
///
/// ```dart
/// ZProgressPill(totalSteps: 3, currentStep: 0) // first step of three
/// ZProgressPill(totalSteps: 5, currentStep: 4) // last step (all filled)
/// ```
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';

/// A segmented horizontal progress indicator.
class ZProgressPill extends StatelessWidget {
  const ZProgressPill({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.height = 3,
    this.gap = 6,
  })  : assert(totalSteps > 0),
        assert(currentStep >= 0),
        assert(currentStep < totalSteps, 'currentStep must be < totalSteps');

  /// Total number of segments.
  final int totalSteps;

  /// Zero-indexed current step. All segments at or before this index are filled.
  final int currentStep;

  /// Height of each segment in logical pixels. Defaults to 3.
  final double height;

  /// Gap between segments in logical pixels. Defaults to 6.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final children = <Widget>[];
    for (var i = 0; i < totalSteps; i++) {
      final isActive = i <= currentStep;
      children.add(Expanded(
        child: AnimatedContainer(
          key: ValueKey('z_progress_segment_$i'),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          height: height,
          decoration: BoxDecoration(
            color: isActive ? colors.primary : colors.surfaceRaised,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ));
      if (i < totalSteps - 1) children.add(SizedBox(width: gap));
    }
    return Row(children: children);
  }
}
