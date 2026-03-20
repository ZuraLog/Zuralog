/// Zuralog — Metric Grid widget.
///
/// Adaptive grid of [MetricTile] widgets. Tile count determines layout:
///   1  → 1×1   2 → 1×2   3 → 1×3   4 → 2×2
///   5  → 3+2   6 → 2×3   7 → 3+2+2  8 → 3+3+2   9 → 3×3
///   10+→ 3×3 visible, vertically scrollable for the remainder
///
/// Long-pressing the grid enters edit mode: tiles show a remove ✕ badge
/// and an add (+) tile appears at the end.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/domain/metric_grid_models.dart';
import 'package:zuralog/shared/widgets/metric_grid/metric_tile.dart';

// ── Layout helper (exported for testing) ─────────────────────────────────────

/// Returns an ordered list of column counts per row for [n] tiles.
///
/// Maximum 3 rows. Beyond 9 tiles the grid is capped at 3×3 and scrolls.
List<int> computeGridLayout(int n) {
  return switch (n) {
    0      => [],
    1      => [1],
    2      => [2],
    3      => [3],
    4      => [2, 2],
    5      => [3, 2],
    6      => [3, 3],
    7      => [3, 2, 2],
    8      => [3, 3, 2],
    _      => [3, 3, 3], // 9 and 10+ — capped; extras scroll
  };
}

// ── MetricGrid ────────────────────────────────────────────────────────────────

/// Adaptive metric tile grid for the Today tab.
///
/// [tiles]     — ordered list of pinned metric tiles to display.
/// [onAddTap]  — called when the user taps the add (+) tile or the header action.
/// [onRemove]  — called with the [MetricTileData] the user tapped ✕ on.
class MetricGrid extends StatefulWidget {
  const MetricGrid({
    super.key,
    required this.tiles,
    required this.onAddTap,
    this.onRemove,
    this.onTileTap,
  });

  final List<MetricTileData> tiles;
  final VoidCallback onAddTap;
  final ValueChanged<MetricTileData>? onRemove;

  /// Called when the user taps a tile in normal (non-edit) mode.
  /// Receives the tapped [MetricTileData] so the caller can open the
  /// appropriate log panel for that metric type.
  final ValueChanged<MetricTileData>? onTileTap;

  @override
  State<MetricGrid> createState() => _MetricGridState();
}

class _MetricGridState extends State<MetricGrid> {
  bool _editMode = false;

  void _enterEditMode() => setState(() => _editMode = true);
  void _exitEditMode()  => setState(() => _editMode = false);

  @override
  Widget build(BuildContext context) {
    final tiles = widget.tiles;
    final colors = AppColorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
          child: Row(
            children: [
              Text(
                'MY METRICS',
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5, // inline — no design token for section caps
                ),
              ),
              const Spacer(),
              if (_editMode)
                Semantics(
                  button: true,
                  label: 'Done editing metrics',
                  child: GestureDetector(
                    onTap: _exitEditMode,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      'Done',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
                )
              else if (tiles.isEmpty)
                Semantics(
                  button: true,
                  label: 'Add a metric to your grid',
                  child: GestureDetector(
                    onTap: widget.onAddTap,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      '+ Add metric',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
                )
              else
                Text(
                  'Hold to edit',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
            ],
          ),
        ),

        // ── Grid ───────────────────────────────────────────────────────────
        if (tiles.isEmpty)
          _AddPromptTile(onTap: widget.onAddTap)
        else
          Semantics(
            hint: _editMode ? null : 'Long press to edit metrics',
            child: GestureDetector(
              onLongPress: _editMode ? null : _enterEditMode,
              child: _GridLayout(
                tiles: tiles,
                editMode: _editMode,
                onRemove: (tile) {
                  widget.onRemove?.call(tile);
                  if (widget.tiles.length == 1) _exitEditMode();
                },
                onAddTap: widget.onAddTap,
                onTileTap: widget.onTileTap,
              ),
            ),
          ),
      ],
    );
  }
}

// ── _GridLayout ───────────────────────────────────────────────────────────────

class _GridLayout extends StatelessWidget {
  const _GridLayout({
    required this.tiles,
    required this.editMode,
    required this.onRemove,
    required this.onAddTap,
    this.onTileTap,
  });

  final List<MetricTileData> tiles;
  final bool editMode;
  final ValueChanged<MetricTileData> onRemove;
  final VoidCallback onAddTap;
  final ValueChanged<MetricTileData>? onTileTap;

  @override
  Widget build(BuildContext context) {
    // Cap visible tiles at 9 (3×3). Extras scroll underneath.
    final visibleCount = tiles.length.clamp(0, 9);
    final layout = computeGridLayout(visibleCount);
    final scrollable = tiles.length > 9;

    // When in edit mode, each tile shows a badge that extends 8px outside
    // its top-right corner. Add top padding to the first row so the badge
    // is not clipped by the section header above.
    Widget grid = Padding(
      padding: EdgeInsets.only(top: editMode ? AppDimens.spaceSm : 0),
      child: Column(
      children: [
        // Rows from layout
        ...() {
          int idx = 0;
          return layout.map((cols) {
            final rowTiles = tiles.skip(idx).take(cols).toList();
            idx += cols;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.spaceXs),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var tIdx = 0; tIdx < rowTiles.length; tIdx++) ...[
                      Expanded(
                        child: MetricTile(
                          data: rowTiles[tIdx],
                          inEditMode: editMode,
                          onRemove: () => onRemove(rowTiles[tIdx]),
                          onTap: onTileTap != null
                              ? () => onTileTap!(rowTiles[tIdx])
                              : null,
                        ),
                      ),
                      if (tIdx < rowTiles.length - 1)
                        const SizedBox(width: AppDimens.spaceXs),
                    ],
                  ],
                ),
              ),
            );
          }).toList();
        }(),
        // Extra tiles beyond 9 — same row structure, scroll reveals them
        if (scrollable) ..._extraRows(tiles.skip(9).toList()),
        // Add tile in edit mode
        if (editMode)
          Padding(
            padding: const EdgeInsets.only(top: AppDimens.spaceXs),
            child: _AddTile(onTap: onAddTap),
          ),
      ],
      ),
    );

    if (scrollable) {
      // Max height = 3 rows. Each row ≈ 60px tile + 4px gap.
      const maxVisibleHeight = 3 * 60.0 + 2 * 4.0;
      grid = SizedBox(
        height: maxVisibleHeight,
        child: SingleChildScrollView(child: grid),
      );
    }

    return grid;
  }

  List<Widget> _extraRows(List<MetricTileData> extras) {
    final rows = <Widget>[];
    for (var i = 0; i < extras.length; i += 3) {
      final chunk = extras.skip(i).take(3).toList();
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceXs),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var tIdx = 0; tIdx < chunk.length; tIdx++) ...[
                  Expanded(
                    child: MetricTile(
                      data: chunk[tIdx],
                      inEditMode: editMode,
                      onRemove: () => onRemove(chunk[tIdx]),
                      onTap: onTileTap != null
                          ? () => onTileTap!(chunk[tIdx])
                          : null,
                    ),
                  ),
                  if (tIdx < chunk.length - 1)
                    const SizedBox(width: AppDimens.spaceXs),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return rows;
  }
}

// ── _AddPromptTile ────────────────────────────────────────────────────────────

class _AddPromptTile extends StatelessWidget {
  const _AddPromptTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(
            color: colors.border,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(AppDimens.shapeSm),
        ),
        child: Center(
          child: Text(
            '+ Add metric',
            style: AppTextStyles.labelMedium.copyWith(
              color: colors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── _AddTile ──────────────────────────────────────────────────────────────────

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: colors.primary.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(AppDimens.shapeSm),
          color: colors.primary.withValues(alpha: 0.05),
        ),
        child: Center(
          child: Text(
            '+',
            style: AppTextStyles.displaySmall.copyWith(
              color: colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
