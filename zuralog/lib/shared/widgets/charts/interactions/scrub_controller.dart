library;

import 'package:flutter/material.dart';

/// Immutable snapshot of the current scrub position on a line or area chart.
///
/// [spotIndex] is the fl_chart data point index snapped to.
/// [value] is the data value at that point.
/// [date] is the timestamp at that point.
/// [pixelX] is the local horizontal pixel offset within the chart widget —
/// used to position the ZChartTooltip horizontally.
class ScrubState {
  const ScrubState({
    required this.spotIndex,
    required this.value,
    required this.date,
    required this.pixelX,
    this.comparisonValue,
  });

  final int spotIndex;
  final double value;
  final DateTime date;
  final double pixelX;

  /// Present in comparison mode — the previous-period value at this spot.
  final double? comparisonValue;

  @override
  bool operator ==(Object other) =>
      other is ScrubState && other.spotIndex == spotIndex;

  @override
  int get hashCode => spotIndex.hashCode;
}

/// Owned by the shell that hosts a line or area chart in full mode.
///
/// Renderers write to this notifier on touch events.
/// FullChartShell listens and renders the ZChartTooltip overlay.
///
/// Set to null when the touch ends (triggers fade-out).
class ScrubController extends ValueNotifier<ScrubState?> {
  ScrubController() : super(null);
}
