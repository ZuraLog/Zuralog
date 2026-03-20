/// Zuralog — TileGrid sliver widget (Phase 8).
///
/// Renders the masonry grid of metric tiles inside a [CustomScrollView].
///
/// Layout modes:
/// - Normal mode: masonry layout using [SliverMasonryGrid.count] interleaved
///   with full-width bands for wide (2×1) tiles. Only visible tiles shown.
/// - Edit mode: falls back to a [SliverReorderableList] (vertical list) for
///   drag-reorder support. All tiles shown (hidden tiles appear dimmed via
///   [TileEditOverlay] with isVisible=false).
library;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/presentation/widgets/metric_tile.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_edit_overlay.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_expanded_view.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_visualizations.dart';
import 'package:zuralog/features/data/domain/category_color.dart';

// ── TileGrid ──────────────────────────────────────────────────────────────────

/// Sliver widget that renders the masonry grid of metric tiles.
///
/// In normal mode it interleaves masonry sections with full-width bands for
/// wide tiles. In edit mode it renders a reorderable vertical list.
class TileGrid extends StatelessWidget {
  const TileGrid({
    super.key,
    required this.orderedTileIds,
    required this.tiles,
    required this.layout,
    required this.isEditMode,
    required this.expandedTileId,
    required this.onTileTap,
    required this.onViewDetails,
    required this.onAskCoach,
    required this.onSizeChanged,
    required this.onVisibilityToggled,
    required this.onColorPick,
    required this.onReorder,
  });

  /// Ordered list of tile IDs from [tileOrderingProvider].
  final List<TileId> orderedTileIds;

  /// Map of [TileId] → [TileData] for O(1) lookup.
  final Map<TileId, TileData> tiles;

  /// Dashboard layout for sizes, visibility, and color overrides.
  final DashboardLayout layout;

  /// Whether the dashboard is in edit (customise) mode.
  final bool isEditMode;

  /// Which tile is currently inline-expanded (`null` = none).
  final TileId? expandedTileId;

  /// Called when a tile is tapped (toggle expand).
  final void Function(TileId) onTileTap;

  /// Called when "View Details ›" is tapped in an expanded tile.
  final void Function(TileId) onViewDetails;

  /// Called when "Ask Coach" is tapped in an expanded tile.
  final void Function(TileId, String primaryValue) onAskCoach;

  /// Called when the size badge is tapped in edit mode.
  final void Function(TileId, TileSize) onSizeChanged;

  /// Called when the eye button is tapped in edit mode.
  final void Function(TileId) onVisibilityToggled;

  /// Called when the palette button is tapped in edit mode.
  final void Function(TileId) onColorPick;

  /// Called when a tile is reordered in edit mode.
  final void Function(int oldIndex, int newIndex) onReorder;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  TileSize _effectiveSize(TileId id) {
    final sizeOverride = layout.tileSizes[id.name];
    return sizeOverride ?? id.defaultSize;
  }

  bool _isVisible(TileId id) => layout.tileVisibility[id.name] != false;

  int? _colorOverride(TileId id) => layout.tileColorOverrides[id.name];

  Widget _buildTileContent(BuildContext context, TileId id) {
    final tileData = tiles[id];
    final size = _effectiveSize(id);
    final colorOverride = _colorOverride(id);
    final isExpanded = expandedTileId == id;

    // If the tile is expanded, render TileExpandedView.
    if (isExpanded && tileData != null && tileData.dataState == TileDataState.loaded) {
      final viz = tileData.visualization;
      // Extract primaryValue from the visualization for coach prefill and display.
      // Handles all viz subtypes — avoids sending "—" to the coach.
      final primaryValue = switch (viz) {
        ValueData(:final primaryValue) => primaryValue,
        RingData(:final value) => value.toStringAsFixed(0),
        CountBadgeData(:final count) => count.toString(),
        DualValueData(:final topValue, :final bottomValue) =>
          '$topValue/$bottomValue',
        GaugeData(:final label) => label ?? '—',
        _ => '—',
      };
      final effectiveColor = colorOverride != null
          ? Color(colorOverride)
          : categoryColor(id.category);

      return TileExpandedView(
        key: ValueKey('expanded_${id.name}'),
        tileId: id,
        size: size,
        visualization: viz != null
            ? buildTileVisualization(
                data: viz,
                categoryColor: effectiveColor,
              )
            : null,
        primaryValue: primaryValue,
        unit: viz is ValueData ? viz.secondaryLabel : null,
        colorOverride: colorOverride,
        avgValue: tileData.avgValue,
        bestValue: tileData.bestValue,
        worstValue: tileData.worstValue,
        changeValue: tileData.changeValue,
        onViewDetails: () => onViewDetails(id),
        onAskCoach: () => onAskCoach(id, primaryValue),
      );
    }

    // Otherwise render MetricTile.
    final viz = tileData?.visualization;
    final primaryValue = viz == null
        ? null
        : switch (viz) {
            ValueData(:final primaryValue) => primaryValue,
            RingData(:final value) => value.toStringAsFixed(0),
            CountBadgeData(:final count) => count.toString(),
            DualValueData(:final topValue, :final bottomValue) =>
              '$topValue/$bottomValue',
            GaugeData(:final label) => label,
            _ => null,
          };
    final unit = viz is ValueData ? viz.secondaryLabel : null;
    final effectiveColor = colorOverride != null
        ? Color(colorOverride)
        : categoryColor(id.category);

    return MetricTile(
      key: ValueKey('tile_${id.name}'),
      tileId: id,
      dataState: tileData?.dataState ?? TileDataState.noSource,
      size: size,
      visualization: viz != null
          ? buildTileVisualization(
              data: viz,
              categoryColor: effectiveColor,
            )
          : null,
      primaryValue: primaryValue,
      unit: unit,
      avgLabel: tileData?.avgLabel,
      deltaLabel: tileData?.deltaLabel,
      lastUpdated: tileData?.lastUpdated,
      colorOverride: colorOverride,
    );
  }

  Widget _buildTappableTile(BuildContext context, TileId id) {
    return GestureDetector(
      onTap: () => onTileTap(id),
      child: _buildTileContent(context, id),
    );
  }

  Widget _buildEditTile(BuildContext context, TileId id, int index) {
    final size = _effectiveSize(id);
    final isVisible = _isVisible(id);
    final colorOverride = _colorOverride(id);

    return ReorderableDragStartListener(
      key: ValueKey('reorder_${id.name}'),
      index: index,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceXs,
        ),
        child: TileEditOverlay(
          tileId: id,
          currentSize: size,
          isVisible: isVisible,
          currentColorOverride: colorOverride,
          onSizeChanged: (newSize) => onSizeChanged(id, newSize),
          onVisibilityToggled: () => onVisibilityToggled(id),
          onColorPick: () => onColorPick(id),
          child: _buildTileContent(context, id),
        ),
      ),
    );
  }

  // ── Masonry band algorithm ──────────────────────────────────────────────────

  /// Breaks [ids] into alternating "non-wide" and "wide" bands.
  ///
  /// Each band is either a list of non-wide tile IDs (for a masonry section)
  /// or a single wide tile ID (for a full-width band).
  List<_Band> _buildBands(List<TileId> ids) {
    final bands = <_Band>[];
    final pending = <TileId>[];

    for (final id in ids) {
      final size = _effectiveSize(id);
      if (size == TileSize.wide) {
        // Flush any pending non-wide tiles first.
        if (pending.isNotEmpty) {
          bands.add(_Band.masonry(List.from(pending)));
          pending.clear();
        }
        // Add the wide tile as a full-width band.
        bands.add(_Band.wide(id));
      } else {
        pending.add(id);
      }
    }

    // Flush remaining non-wide tiles.
    if (pending.isNotEmpty) {
      bands.add(_Band.masonry(List.from(pending)));
    }

    return bands;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (isEditMode) {
      return _buildEditMode(context);
    }
    return _buildNormalMode(context);
  }

  Widget _buildNormalMode(BuildContext context) {
    // Filter to visible tiles only.
    final visibleIds = orderedTileIds.where(_isVisible).toList();

    if (visibleIds.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final bands = _buildBands(visibleIds);

    return SliverMainAxisGroup(
      slivers: [
        for (final band in bands)
          if (band.isWide)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceXs,
                  AppDimens.spaceMd,
                  AppDimens.spaceXs,
                ),
                child: _buildTappableTile(context, band.singleId!),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: AppDimens.spaceSm,
                crossAxisSpacing: AppDimens.spaceSm,
                childCount: band.ids.length,
                itemBuilder: (context, i) {
                  final id = band.ids[i];
                  return _buildTappableTile(context, id);
                },
              ),
            ),
      ],
    );
  }

  Widget _buildEditHiddenTile(BuildContext context, TileId id) {
    final size = _effectiveSize(id);
    final colorOverride = _colorOverride(id);

    return Padding(
      key: ValueKey('hidden_${id.name}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      child: Opacity(
        opacity: AppDimens.disabledOpacity,
        child: TileEditOverlay(
          tileId: id,
          currentSize: size,
          isVisible: false,
          currentColorOverride: colorOverride,
          onSizeChanged: (newSize) => onSizeChanged(id, newSize),
          onVisibilityToggled: () => onVisibilityToggled(id),
          onColorPick: () => onColorPick(id),
          child: _buildTileContent(context, id),
        ),
      ),
    );
  }

  Widget _buildEditMode(BuildContext context) {
    // Split tiles into visible and hidden.
    final visibleIds =
        orderedTileIds.where(_isVisible).toList();
    final hiddenIds =
        orderedTileIds.where((id) => !_isVisible(id)).toList();

    if (visibleIds.isEmpty && hiddenIds.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // Map visible-list indices to full orderedTileIds indices for onReorder.
    void mappedOnReorder(int visibleOld, int visibleNew) {
      // Find the positions of visible tiles within the full ordered list.
      final visiblePositions = <int>[];
      for (var i = 0; i < orderedTileIds.length; i++) {
        if (_isVisible(orderedTileIds[i])) visiblePositions.add(i);
      }
      if (visibleOld >= visiblePositions.length ||
          visibleNew > visiblePositions.length) {
        return;
      }
      final fullOld = visiblePositions[visibleOld];
      // When newIndex equals visibleIds.length the item is dropped after the
      // last visible tile. In that case insert after the last visible position
      // (i.e. orderedTileIds.length - hiddenIds.length) rather than clamping
      // to second-to-last.
      final int fullNew;
      if (visibleNew >= visiblePositions.length) {
        fullNew = orderedTileIds.length - hiddenIds.length;
      } else {
        fullNew = visiblePositions[visibleNew];
      }
      onReorder(fullOld, fullNew);
    }

    return SliverMainAxisGroup(
      slivers: [
        // ── Visible tiles — reorderable ─────────────────────────────────
        SliverReorderableList(
          itemCount: visibleIds.length,
          onReorder: mappedOnReorder,
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, animChild) => Material(
                elevation: 4 * animation.value,
                borderRadius:
                    BorderRadius.circular(AppDimens.radiusCard),
                color: Colors.transparent,
                child: animChild,
              ),
              child: child,
            );
          },
          itemBuilder: (context, i) {
            final id = visibleIds[i];
            return _buildEditTile(context, id, i);
          },
        ),

        // ── "Hidden" section header ─────────────────────────────────────
        if (hiddenIds.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: Text(
                'Hidden',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

        // ── Hidden tiles — non-reorderable, dimmed ──────────────────────
        if (hiddenIds.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) =>
                  _buildEditHiddenTile(context, hiddenIds[i]),
              childCount: hiddenIds.length,
            ),
          ),

      ],
    );
  }
}

// ── _Band ─────────────────────────────────────────────────────────────────────

/// Represents one layout band in the masonry grid.
///
/// Either a list of non-wide tiles (masonry section) or a single wide tile
/// (full-width band).
class _Band {
  const _Band._({
    required this.ids,
    required this.isWide,
  });

  factory _Band.masonry(List<TileId> ids) =>
      _Band._(ids: ids, isWide: false);

  factory _Band.wide(TileId id) =>
      _Band._(ids: [id], isWide: true);

  /// All tile IDs in this band.
  final List<TileId> ids;

  /// Whether this is a full-width wide tile band.
  final bool isWide;

  /// The single tile ID for a wide band. Null for masonry bands.
  TileId? get singleId => isWide ? ids.first : null;
}
