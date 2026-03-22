/// Zuralog — TileGrid sliver widget (Phase 8).
///
/// Renders the masonry grid of metric tiles inside a [CustomScrollView].
///
/// Layout modes:
/// - Normal mode: explicit 2-column layout interleaved with full-width bands
///   for wide (2×1) tiles. Only visible tiles shown.
/// - Edit mode: same WYSIWYG band layout with [TileEditOverlay] wrappers and
///   [LongPressDraggable] + [DragTarget] per slot for drag-to-reorder.
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
/// full-width bands for wide tiles. In edit mode it renders the identical
/// WYSIWYG grid with [TileEditOverlay] wrappers and drag-to-reorder support.
class TileGrid extends StatefulWidget {
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

  @override
  State<TileGrid> createState() => _TileGridState();
}

class _TileGridState extends State<TileGrid> {
  /// The tile currently being dragged, or null.
  TileId? _draggedId;

  /// The tile slot currently being hovered over during a drag, or null.
  TileId? _hoverTargetId;

  @override
  void didUpdateWidget(TileGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset drag state whenever the ordering or layout changes externally
    // (e.g. after onReorder propagates back through the provider).
    if (oldWidget.orderedTileIds != widget.orderedTileIds ||
        oldWidget.layout != widget.layout) {
      _draggedId = null;
      _hoverTargetId = null;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  TileSize _effectiveSize(TileId id) {
    final sizeOverride = widget.layout.tileSizes[id.name];
    return sizeOverride ?? id.defaultSize;
  }

  bool _isVisible(TileId id) => widget.layout.tileVisibility[id.name] != false;

  int? _colorOverride(TileId id) => widget.layout.tileColorOverrides[id.name];

  Widget _buildTileContent(BuildContext context, TileId id) {
    final tileData = widget.tiles[id];
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
      onTap: () => widget.onTileTap(id),
      child: _buildTileContent(context, id),
    );
  }

  // ── Masonry band algorithm ──────────────────────────────────────────────────

  /// Breaks [ids] into alternating "non-wide" and "wide" bands.
  List<Band> _buildBands(List<TileId> ids) => buildBands(ids, _effectiveSize);

  // ── Normal-mode band rendering ──────────────────────────────────────────────

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
  Widget _buildBandSliver(BuildContext context, Band band) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final colWidth =
                (constraints.maxWidth - AppDimens.spaceSm) / 2;

            final ids = band.ids;

            List<TileId?> leftIds;
            List<TileId?> rightIds;

            final firstId = ids.isNotEmpty ? ids[0] : null;
            final firstIsTall = firstId != null &&
                _effectiveSize(firstId) == TileSize.tall;

            if (firstIsTall) {
              leftIds = [ids[0]];
              rightIds = ids.length > 1 ? ids.sublist(1) : [];
            } else {
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

  /// Builds one column of a normal-mode band as a [Column] of sized tile slots.
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
          ? 2 * colWidth + AppDimens.spaceSm
          : colWidth;

      if (id == null) {
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

  // ── Edit-mode band rendering ─────────────────────────────────────────────────

  /// Edit-mode variant of [_buildBandSliver]: same layout, draggable slots.
  Widget _buildEditBandSliver(BuildContext context, Band band) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final colWidth =
                (constraints.maxWidth - AppDimens.spaceSm) / 2;

            final ids = band.ids;

            List<TileId?> leftIds;
            List<TileId?> rightIds;

            final firstId = ids.isNotEmpty ? ids[0] : null;
            final firstIsTall = firstId != null &&
                _effectiveSize(firstId) == TileSize.tall;

            if (firstIsTall) {
              leftIds = [ids[0]];
              rightIds = ids.length > 1 ? ids.sublist(1) : [];
            } else {
              leftIds = [for (int i = 0; i < ids.length; i += 2) ids[i]];
              rightIds = [for (int i = 1; i < ids.length; i += 2) ids[i]];
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEditColumn(context, leftIds, colWidth, firstIsTall),
                const SizedBox(width: AppDimens.spaceSm),
                _buildEditColumn(context, rightIds, colWidth, false),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds one column of an edit-mode band as a [Column] of draggable slots.
  Widget _buildEditColumn(
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
          ? 2 * colWidth + AppDimens.spaceSm
          : colWidth;

      if (id == null) {
        children.add(SizedBox(width: colWidth, height: tileHeight));
      } else {
        children.add(
          _buildDraggableSlot(context, id, colWidth, tileHeight),
        );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// Edit-mode variant of wide-band rendering.
  Widget _buildEditWideBandSliver(BuildContext context, TileId id) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = width / 2; // AspectRatio 2:1
            return _buildDraggableSlot(context, id, width, height);
          },
        ),
      ),
    );
  }

  /// Builds a single tile slot with [LongPressDraggable] and [DragTarget].
  ///
  /// While dragging, the original slot shows at reduced opacity so the user can
  /// see the gap. On hover, a primary-colour border highlights the drop target.
  Widget _buildDraggableSlot(
    BuildContext context,
    TileId id,
    double width,
    double height,
  ) {
    final colors = AppColorsOf(context);
    final isBeingDragged = _draggedId == id;
    final isHoverTarget = _hoverTargetId == id;

    return DragTarget<TileId>(
      onWillAcceptWithDetails: (details) {
        if (details.data != id) {
          setState(() => _hoverTargetId = id);
        }
        return details.data != id;
      },
      onLeave: (_) {
        if (_hoverTargetId == id) {
          setState(() => _hoverTargetId = null);
        }
      },
      onAcceptWithDetails: (details) {
        final draggedId = details.data;
        setState(() {
          _hoverTargetId = null;
          _draggedId = null;
        });
        final oldIndex = widget.orderedTileIds.indexOf(draggedId);
        final newIndex = widget.orderedTileIds.indexOf(id);
        if (oldIndex != -1 && newIndex != -1 && oldIndex != newIndex) {
          widget.onReorder(oldIndex, newIndex);
        }
      },
      builder: (context, candidateData, rejectedData) {
        Widget slot = SizedBox(
          width: width,
          height: height,
          child: AnimatedOpacity(
            opacity: isBeingDragged ? 0.3 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: _buildEditTileContent(context, id),
          ),
        );

        if (isHoverTarget) {
          slot = Stack(
            children: [
              slot,
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.primary, width: 2.5),
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusCard),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return LongPressDraggable<TileId>(
          data: id,
          delay: const Duration(milliseconds: 350),
          onDragStarted: () => setState(() {
            _draggedId = id;
            _hoverTargetId = null;
          }),
          onDragEnd: (_) => setState(() => _draggedId = null),
          onDraggableCanceled: (_, _) => setState(() => _draggedId = null),
          feedback: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimens.radiusCard),
            elevation: 8,
            child: SizedBox(
              width: width,
              height: height,
              child: _buildEditTileContent(context, id),
            ),
          ),
          child: slot,
        );
      },
    );
  }

  /// Wraps [_buildTileContent] with a [TileEditOverlay] for edit controls.
  Widget _buildEditTileContent(BuildContext context, TileId id) {
    final isVisible = _isVisible(id);
    final size = _effectiveSize(id);
    final colorOverride = _colorOverride(id);

    return TileEditOverlay(
      tileId: id,
      currentSize: size,
      isVisible: isVisible,
      currentColorOverride: colorOverride,
      onSizeChanged: (newSize) => widget.onSizeChanged(id, newSize),
      onVisibilityToggled: () => widget.onVisibilityToggled(id),
      onColorPick: () => widget.onColorPick(id),
      child: _buildTileContent(context, id),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.isEditMode) {
      return _buildEditMode(context);
    }
    return _buildNormalMode(context);
  }

  Widget _buildNormalMode(BuildContext context) {
    final visibleIds = widget.orderedTileIds.where(_isVisible).toList();

    if (visibleIds.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final bands = _buildBands(visibleIds);

    return SliverMainAxisGroup(
      slivers: [
        for (int i = 0; i < bands.length; i++) ...[
          if (i > 0)
            const SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceSm)),
          if (bands[i].isWide)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd),
                child: AspectRatio(
                  aspectRatio: 2.0,
                  child: _buildTappableTile(context, bands[i].singleId!),
                ),
              ),
            )
          else
            _buildBandSliver(context, bands[i]),
        ],
      ],
    );
  }

  Widget _buildEditMode(BuildContext context) {
    final visibleIds =
        widget.orderedTileIds.where(_isVisible).toList();
    final hiddenIds =
        widget.orderedTileIds.where((id) => !_isVisible(id)).toList();

    if (visibleIds.isEmpty && hiddenIds.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final bands = _buildBands(visibleIds);

    return SliverMainAxisGroup(
      slivers: [
        // ── Visible tiles — WYSIWYG grid with drag-to-reorder ───────────
        for (int i = 0; i < bands.length; i++) ...[
          if (i > 0)
            const SliverToBoxAdapter(
                child: SizedBox(height: AppDimens.spaceSm)),
          if (bands[i].isWide)
            _buildEditWideBandSliver(context, bands[i].singleId!)
          else
            _buildEditBandSliver(context, bands[i]),
        ],

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

        // ── Hidden tiles — same grid layout, non-draggable ──────────────
        if (hiddenIds.isNotEmpty) ..._buildHiddenGrid(context, hiddenIds),
      ],
    );
  }

  /// Renders hidden tiles in the same band-grid layout as normal mode, but
  /// wrapped with [TileEditOverlay] (no drag). Returns a list of slivers.
  List<Widget> _buildHiddenGrid(
      BuildContext context, List<TileId> hiddenIds) {
    if (hiddenIds.isEmpty) return [];
    final bands = _buildBands(hiddenIds);
    final slivers = <Widget>[];
    for (int i = 0; i < bands.length; i++) {
      if (i > 0) {
        slivers.add(const SliverToBoxAdapter(
            child: SizedBox(height: AppDimens.spaceSm)));
      }
      if (bands[i].isWide) {
        slivers.add(_buildHiddenWideBandSliver(context, bands[i].singleId!));
      } else {
        slivers.add(_buildHiddenBandSliver(context, bands[i]));
      }
    }
    return slivers;
  }

  Widget _buildHiddenBandSliver(BuildContext context, Band band) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final colWidth =
                (constraints.maxWidth - AppDimens.spaceSm) / 2;
            final ids = band.ids;
            final firstId = ids.isNotEmpty ? ids[0] : null;
            final firstIsTall = firstId != null &&
                _effectiveSize(firstId) == TileSize.tall;
            final List<TileId?> leftIds;
            final List<TileId?> rightIds;
            if (firstIsTall) {
              leftIds = [ids[0]];
              rightIds = ids.length > 1 ? ids.sublist(1) : [];
            } else {
              leftIds = [for (int i = 0; i < ids.length; i += 2) ids[i]];
              rightIds = [for (int i = 1; i < ids.length; i += 2) ids[i]];
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHiddenColumn(context, leftIds, colWidth, firstIsTall),
                const SizedBox(width: AppDimens.spaceSm),
                _buildHiddenColumn(context, rightIds, colWidth, false),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHiddenColumn(
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
          ? 2 * colWidth + AppDimens.spaceSm
          : colWidth;
      if (id == null) {
        children.add(SizedBox(width: colWidth, height: tileHeight));
      } else {
        children.add(SizedBox(
          width: colWidth,
          height: tileHeight,
          child: _buildEditTileContent(context, id),
        ));
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildHiddenWideBandSliver(BuildContext context, TileId id) {
    return SliverToBoxAdapter(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        child: AspectRatio(
          aspectRatio: 2.0,
          child: _buildEditTileContent(context, id),
        ),
      ),
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
  flushPending(allowPullUp: true);

  return bands;
}
