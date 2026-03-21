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
    required this.onTileTap,
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

  /// Called when a tile is tapped.
  final void Function(TileId) onTileTap;

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

  double _tileAspectRatio(TileSize size) => switch (size) {
    TileSize.square => 1.0,
    TileSize.tall   => 0.5,   // height = 2 × column width
    TileSize.wide   => 2.0,   // height = full-row-width ÷ 2
  };

  Widget _buildTileContent(BuildContext context, TileId id) {
    final tileData = tiles[id];
    final size = _effectiveSize(id);
    final colorOverride = _colorOverride(id);

    // Render MetricTile.
    return MetricTile(
      key: ValueKey('tile_${id.name}'),
      tileId: id,
      dataState: tileData?.dataState ?? TileDataState.noSource,
      size: size,
      vizConfig: tileData?.vizConfig,
      primaryValue: tileData?.primaryValue,
      avgLabel: tileData?.avgLabel,
      deltaLabel: tileData?.deltaLabel,
      lastUpdated: tileData?.lastUpdated,
      colorOverride: colorOverride,
    );
  }

  Widget _buildTappableTile(BuildContext context, TileId id) {
    final size = _effectiveSize(id);
    return GestureDetector(
      onTap: () => onTileTap(id),
      child: AspectRatio(
        aspectRatio: _tileAspectRatio(size),
        child: _buildTileContent(context, id),
      ),
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
  List<Band> _buildBands(List<TileId> ids) => buildBands(ids, _effectiveSize);

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
                  if (id == null) return const SizedBox.shrink();
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

// ── Band ──────────────────────────────────────────────────────────────────────

/// Represents one layout band in the masonry grid.
///
/// Either a list of non-wide tiles (masonry section) or a single wide tile
/// (full-width band). A null entry in [ids] represents a transparent spacer
/// used to fill an odd column gap before a wide tile.
class Band {
  const Band._({
    required this.ids,
    required this.isWide,
  });

  factory Band.masonry(List<TileId?> ids) =>
      Band._(ids: ids, isWide: false);

  factory Band.wide(TileId id) =>
      Band._(ids: [id], isWide: true);

  /// All tile IDs in this band. A null entry is a transparent spacer.
  final List<TileId?> ids;

  /// Whether this is a full-width wide tile band.
  final bool isWide;

  /// The single tile ID for a wide band. Null for masonry bands.
  TileId? get singleId => isWide ? ids.first : null;
}

// ── buildBands ────────────────────────────────────────────────────────────────

/// Extracted for testability.
///
/// Breaks [ids] into alternating masonry and wide [Band]s.
/// When a wide tile is encountered and the pending non-wide count is odd,
/// the next non-wide tile is pulled up (or a null spacer inserted) so the
/// masonry grid always has an even count and avoids an empty column gap.
@visibleForTesting
List<Band> buildBands(List<TileId> ids, TileSize Function(TileId) sizeOf) {
  final bands = <Band>[];
  final remaining = ids.toList();
  final pending = <TileId?>[];

  while (remaining.isNotEmpty) {
    final id = remaining.removeAt(0);
    final size = sizeOf(id);

    if (size == TileSize.wide) {
      if (pending.length.isOdd) {
        final nextNonWideIdx =
            remaining.indexWhere((r) => sizeOf(r) != TileSize.wide);
        if (nextNonWideIdx != -1) {
          pending.add(remaining.removeAt(nextNonWideIdx));
        } else {
          pending.add(null); // transparent spacer
        }
      }
      if (pending.isNotEmpty) {
        bands.add(Band.masonry(List.from(pending)));
        pending.clear();
      }
      bands.add(Band.wide(id));
    } else {
      pending.add(id);
    }
  }

  // Flush remaining non-wide tiles.
  if (pending.isNotEmpty) {
    bands.add(Band.masonry(List.from(pending)));
  }

  return bands;
}
