library;

import 'package:zuralog/features/data/domain/data_models.dart';

/// Display modes for chart visualizations.
///
/// Controls layout, touch behavior, and supplementary UI.
enum ChartMode {
  /// 1x1 square tile (~160x160px). Compact, no axes, tap = navigate.
  square,
  /// 2x1 wide tile (~330x160px). Bottom axis labels, tap = navigate.
  wide,
  /// 1x2 tall tile (~160x330px). Stats row below chart, tap = navigate.
  tall,
  /// Fullscreen hero (~screen width, ~200px). Touch interactive.
  full,
  /// Inline sparkline (~60x16px). No chrome, non-interactive.
  sparkline,
  /// Home screen widget (~150x150 or ~300x150). Higher contrast.
  widget,
  /// Comparison overlay (~screen width, ~200px). Two datasets overlaid.
  comparison,
  /// Mini progress badge (24-32px). Decorative ring or bar.
  mini,
}

extension TileSizeToChartMode on TileSize {
  ChartMode toChartMode() => switch (this) {
    TileSize.square => ChartMode.square,
    TileSize.wide => ChartMode.wide,
    TileSize.tall => ChartMode.tall,
  };
}
