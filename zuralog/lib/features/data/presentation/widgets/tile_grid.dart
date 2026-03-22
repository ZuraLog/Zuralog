/// Zuralog — TileGrid sliver widget (Phase 8).
///
/// Renders the masonry grid of metric tiles inside a [CustomScrollView].
///
/// Layout modes:
/// - Normal mode: explicit 2-column layout interleaved with full-width bands
///   for wide (2×1) tiles. Only visible tiles shown.
/// - Edit mode: falls back to a [SliverReorderableList] (vertical list) for
///   drag-reorder support. All tiles shown (hidden tiles appear dimmed via
///   [TileEditOverlay] with isVisible=false).
library;

import 'package:flutter/material.dart';

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
/// In normal mode it interleaves explicit 2-column band sections with
/// full-width bands for wide tiles. In edit mode it renders a reorderable
/// vertical list.
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

  Widget _buildTileContent(BuildContext context, TileId id) {
    final tileData = tiles[id];
    final size = _effectiveSize(id);
    final colorOverride = _colorOverride(id);

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

  /// Builds a tappable tile. Sizing is handled by the parent band renderer via
  /// explicit [SizedBox] constraints — this method only adds the tap gesture.
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
  List<Band> _buildBands(List<TileId> ids) => buildBands(ids, _effectiveSize);

  // ── Band rendering ──────────────────────────────────────────────────────────

  /// Renders a non-wide [Band] as a [SliverToBoxAdapter] with an explicit
  /// 2-column layout.
  ///
  /// All tile heights are derived from the actual column width obtained via
  /// [LayoutBuilder], ensuring pixel-perfect alignment regardless of tile order:
  ///
  /// - Square / null spacer → height = colWidth
  /// - Tall tile            → height = 2 × colWidth + [AppDimens.spaceSm]
  ///
  /// The tall tile formula exactly matches the right column's height when two
  /// square companions are stacked with one gap between them
  /// (colWidth + spaceSm + colWidth = 2×colWidth + spaceSm), so both column
  /// bottom edges are always flush.
  ///
  /// Column assignment follows the same deterministic rule as [buildBands]:
  /// - If [Band.ids[0]] is a tall tile → left col gets [ids[0]], right col
  ///   gets [ids[1]] and [ids[2]].
  /// - Otherwise (all-square band) → left col gets even-index items
  ///   (0, 2, …), right col gets odd-index items (1, 3, …).
  Widget _buildBandSliver(BuildContext context, Band band) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final colWidth =
                (constraints.maxWidth - AppDimens.spaceSm) / 2;

            final ids = band.ids;

            // Determine column contents.
            List<TileId?> leftIds;
            List<TileId?> rightIds;

            final firstId = ids.isNotEmpty ? ids[0] : null;
            final firstIsTall = firstId != null &&
                _effectiveSize(firstId) == TileSize.tall;

            if (firstIsTall) {
              // Tall band: left = [tall], right = [companion1, companion2]
              leftIds = [ids[0]];
              rightIds = ids.length > 1 ? ids.sublist(1) : [];
            } else {
              // Square band: interleave even→left, odd→right
              leftIds = [for (int i = 0; i < ids.length; i += 2) ids[i]];
              rightIds = [for (int i = 1; i < ids.length; i += 2) ids[i]];
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildColumn(context, leftIds, colWidth, firstIsTall),
                const SizedBox(width: AppDimens.spaceSm),
                _buildColumn(context, rightIds, colWidth, false),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds one column of a band as a [Column] of sized tile slots.
  ///
  /// [isTallColumn] is true only for the left column when it holds a single
  /// tall tile — in that case the tile receives the corrected tall height.
  Widget _buildColumn(
    BuildContext context,
    List<TileId?> ids,
    double colWidth,
    bool isTallColumn,
  ) {
    final children = <Widget>[];

    for (int i = 0; i < ids.length; i++) {
      if (i > 0) children.add(const SizedBox(height: AppDimens.spaceSm));

      final id = ids[i];
      final tileHeight = isTallColumn
          ? 2 * colWidth + AppDimens.spaceSm // tall: spans 2 squares + 1 gap
          : colWidth;                        // square / null spacer

      if (id == null) {
        // Transparent spacer — occupies the same footprint as a square tile
        // so the companion column aligns correctly.
        children.add(SizedBox(width: colWidth, height: tileHeight));
      } else {
        children.add(SizedBox(
          width: colWidth,
          height: tileHeight,
          child: _buildTappableTile(context, id),
        ));
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
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
        for (int i = 0; i < bands.length; i++) ...[
          // Consistent gap between every pair of consecutive bands.
          if (i > 0)
            const SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceSm)),
          if (bands[i].isWide)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
                child: _buildTappableTile(context, bands[i].singleId!),
              ),
            )
          else
            _buildBandSliver(context, bands[i]),
        ],
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
      final visiblePositions = <int>[];
      for (var i = 0; i < orderedTileIds.length; i++) {
        if (_isVisible(orderedTileIds[i])) visiblePositions.add(i);
      }
      if (visibleOld >= visiblePositions.length ||
          visibleNew > visiblePositions.length) {
        return;
      }
      final fullOld = visiblePositions[visibleOld];
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

  /// Flushes [pending] as a masonry band, padding to even count if needed.
  ///
  /// When [allowPullUp] is true (before a wide tile), the next square tile from
  /// [remaining] is pulled into the band to fill the odd slot. When false
  /// (before a tall tile), a null spacer is always used so that tall-band
  /// companions are not consumed prematurely.
  void flushPending({bool allowPullUp = true}) {
    if (pending.isEmpty) return;
    if (pending.length.isOdd) {
      if (allowPullUp) {
        final nextSqIdx = remaining.indexWhere(
          (r) => sizeOf(r) == TileSize.square,
        );
        if (nextSqIdx != -1) {
          pending.add(remaining.removeAt(nextSqIdx));
        } else {
          pending.add(null); // transparent spacer
        }
      } else {
        pending.add(null); // transparent spacer — keep companions for tall band
      }
    }
    bands.add(Band.masonry(List.from(pending)));
    pending.clear();
  }

  while (remaining.isNotEmpty) {
    final id = remaining.removeAt(0);
    final size = sizeOf(id);

    if (size == TileSize.wide) {
      flushPending();
      bands.add(Band.wide(id));
    } else if (size == TileSize.tall) {
      // If pending has an odd count, pop the last square and use it as the
      // first companion of the tall band. This keeps the pre-tall flush even
      // (no null spacer needed) and avoids an empty slot in the grid.
      TileId? poppedCompanion;
      if (pending.isNotEmpty && pending.length.isOdd) {
        poppedCompanion = pending.removeLast();
      }

      // Flush any remaining accumulated square tiles (now always even).
      flushPending(allowPullUp: false);

      // Build companion list: popped square first (if any), then pull from remaining.
      final companions = <TileId?>[];
      if (poppedCompanion != null) companions.add(poppedCompanion);
      while (companions.length < 2) {
        final idx = remaining.indexWhere((r) => sizeOf(r) == TileSize.square);
        companions.add(idx != -1 ? remaining.removeAt(idx) : null);
      }

      bands.add(Band.masonry([id, ...companions]));
    } else {
      pending.add(id);
    }
  }

  // Flush remaining non-wide, non-tall tiles.
  // Use allowPullUp:true; remaining is empty at this point so a null spacer
  // will be used if pending has an odd count, keeping the masonry grid even.
  flushPending(allowPullUp: true);

  return bands;
}
