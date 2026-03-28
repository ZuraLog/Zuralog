library;

import 'chart_mode.dart';

/// Rendering hints passed from the mode shell to chart renderers.
///
/// Renderers never import [ChartMode] directly — all mode-specific
/// decisions are encoded here by the shell.
class ChartRenderContext {
  const ChartRenderContext({
    this.showAxes = false,
    this.showGrid = false,
    this.showDots = false,
    this.showTooltip = false,
    this.isCurved = false,
    this.preventCurveOverShooting = false,
    this.strokeWidth = 1.5,
    this.maxBars,
    this.isComparisonSecondary = false,
    this.comparisonOpacity = 0.4,
    this.minY,
    this.maxY,
    this.animationProgress = 1.0,
  });

  final bool showAxes;
  final bool showGrid;
  final bool showDots;
  final bool showTooltip;
  final bool isCurved;
  final bool preventCurveOverShooting;
  final double strokeWidth;
  final int? maxBars;
  final bool isComparisonSecondary;
  final double comparisonOpacity;
  final double? minY;
  final double? maxY;
  final double animationProgress;

  /// Returns [Duration.zero] during entrance animation (to disable fl_chart's
  /// built-in tween), or 350ms after entrance completes for smooth data updates.
  Duration get flChartDuration => animationProgress < 1.0
      ? Duration.zero
      : const Duration(milliseconds: 350);

  /// Builds the appropriate render context for a given [ChartMode].
  factory ChartRenderContext.fromMode(
    ChartMode mode, {
    double animationProgress = 1.0,
  }) {
    return switch (mode) {
      ChartMode.square => ChartRenderContext(
          showDots: true,
          maxBars: 5,
          animationProgress: animationProgress,
        ),
      ChartMode.wide => ChartRenderContext(
          showAxes: true,
          showDots: true,
          animationProgress: animationProgress,
        ),
      ChartMode.tall => ChartRenderContext(
          showDots: true,
          animationProgress: animationProgress,
        ),
      ChartMode.full => ChartRenderContext(
          showAxes: true,
          showGrid: true,
          showDots: true,
          showTooltip: true,
          isCurved: true,
          preventCurveOverShooting: true,
          strokeWidth: 2.5,
          animationProgress: animationProgress,
        ),
      ChartMode.sparkline => ChartRenderContext(
          strokeWidth: 1.0,
          animationProgress: animationProgress,
        ),
      ChartMode.widget => ChartRenderContext(
          showDots: true,
          strokeWidth: 2.0,
          maxBars: 5,
          animationProgress: animationProgress,
        ),
      ChartMode.comparison => ChartRenderContext(
          showAxes: true,
          showGrid: true,
          showDots: true,
          showTooltip: true,
          isCurved: true,
          preventCurveOverShooting: true,
          strokeWidth: 2.5,
          animationProgress: animationProgress,
        ),
      ChartMode.mini => ChartRenderContext(
          strokeWidth: 1.0,
          animationProgress: animationProgress,
        ),
    };
  }

  ChartRenderContext copyWith({
    bool? showAxes,
    bool? showGrid,
    bool? showDots,
    bool? showTooltip,
    bool? isCurved,
    bool? preventCurveOverShooting,
    double? strokeWidth,
    int? maxBars,
    bool? isComparisonSecondary,
    double? comparisonOpacity,
    double? minY,
    double? maxY,
    double? animationProgress,
  }) {
    return ChartRenderContext(
      showAxes: showAxes ?? this.showAxes,
      showGrid: showGrid ?? this.showGrid,
      showDots: showDots ?? this.showDots,
      showTooltip: showTooltip ?? this.showTooltip,
      isCurved: isCurved ?? this.isCurved,
      preventCurveOverShooting: preventCurveOverShooting ?? this.preventCurveOverShooting,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      maxBars: maxBars ?? this.maxBars,
      isComparisonSecondary: isComparisonSecondary ?? this.isComparisonSecondary,
      comparisonOpacity: comparisonOpacity ?? this.comparisonOpacity,
      minY: minY ?? this.minY,
      maxY: maxY ?? this.maxY,
      animationProgress: animationProgress ?? this.animationProgress,
    );
  }
}
