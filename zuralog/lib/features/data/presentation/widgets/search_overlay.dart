/// Zuralog — SearchOverlay widget.
///
/// A full-screen search overlay that appears when the search icon is tapped in
/// the data tab app bar. Filters the 20 metric tiles by display name or
/// category name and renders matching tiles in a 2-column grid.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/presentation/widgets/metric_tile.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_visualizations.dart';

// ── SearchOverlay ─────────────────────────────────────────────────────────────

/// Full-screen search overlay for the data dashboard.
///
/// Filters [tiles] by whether [TileId.displayName] or
/// [TileId.category.displayName] contains the query (case-insensitive).
/// Non-matching tiles are hidden; clearing the query restores all 20.
class SearchOverlay extends ConsumerStatefulWidget {
  const SearchOverlay({
    super.key,
    required this.tiles,
    required this.onClose,
    required this.onTileSelected,
  });

  /// Full list of [TileData] from the dashboard provider.
  final List<TileData> tiles;

  /// Called when the user dismisses the overlay (back button or Escape key).
  final VoidCallback onClose;

  /// Called when the user taps a search result tile.
  final void Function(TileId) onTileSelected;

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _keyFocusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _query = _controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _keyFocusNode.dispose();
    super.dispose();
  }

  // ── Filtering ────────────────────────────────────────────────────────────────

  List<TileData> get _filtered {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return widget.tiles;
    return widget.tiles.where((tile) {
      final nameMatch = tile.tileId.displayName.toLowerCase().contains(q);
      final catMatch =
          tile.tileId.category.displayName.toLowerCase().contains(q);
      return nameMatch || catMatch;
    }).toList();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final filtered = _filtered;

    return KeyboardListener(
      focusNode: _keyFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose();
        }
      },
      child: Material(
        color: colors.background,
        child: SafeArea(
          child: Column(
            children: [
              // ── Search bar ───────────────────────────────────────────────
              _SearchBar(
                controller: _controller,
                onClose: widget.onClose,
                colors: colors,
              ),

              // ── Results ──────────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(colors: colors)
                    : _ResultsGrid(
                        tiles: filtered,
                        onTileSelected: widget.onTileSelected,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _SearchBar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onClose,
    required this.colors,
  });

  final TextEditingController controller;
  final VoidCallback onClose;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onClose,
            tooltip: 'Close search',
          ),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search metrics…',
                filled: true,
                fillColor: colors.inputBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.shapeSm), // 12px
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.shapeSm),
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => controller.clear(),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _ResultsGrid ──────────────────────────────────────────────────────────────

class _ResultsGrid extends StatelessWidget {
  const _ResultsGrid({
    required this.tiles,
    required this.onTileSelected,
  });

  final List<TileData> tiles;
  final void Function(TileId) onTileSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppDimens.spaceSm,
        mainAxisSpacing: AppDimens.spaceSm,
        childAspectRatio: 1.0,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, index) {
        final tile = tiles[index];
        return GestureDetector(
          onTap: () => onTileSelected(tile.tileId),
          child: _SearchResultTile(tile: tile),
        );
      },
    );
  }
}

// ── _SearchResultTile ─────────────────────────────────────────────────────────

/// A compact search result card that always shows the tile's display name.
///
/// Used in [_ResultsGrid] instead of [MetricTile] directly so the tile name
/// text is always present regardless of data state, enabling find.text() to
/// locate tiles by name in tests and in UI.
class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.tile});

  final TileData tile;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        boxShadow: colors.isDark ? null : AppDimens.cardShadowLight,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Tile display name — always visible
          Text(
            tile.tileId.displayName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Category name
          Text(
            tile.tileId.category.displayName,
            style: TextStyle(
              fontSize: 11,
              color: colors.textTertiary,
            ),
          ),
          const Spacer(),
          // MetricTile content for loaded tiles; otherwise a small placeholder
          if (tile.dataState == TileDataState.loaded)
            Builder(builder: (context) {
              final vizConfig = tile.vizConfig;
              final effectiveColor = categoryColor(tile.tileId.category);
              return MetricTile(
                tileId: tile.tileId,
                dataState: tile.dataState,
                size: TileSize.square,
                visualization: vizConfig != null
                    ? buildTileVisualization(
                        config: vizConfig,
                        categoryColor: effectiveColor,
                        size: TileSize.square,
                      )
                    : null,
                primaryValue: tile.primaryValue,
                unit: tile.unit,
              );
            })
          else
            Icon(
              Icons.show_chart_rounded,
              size: 24,
              color: colors.textTertiary,
            ),
        ],
      ),
    );
  }
}

// ── _EmptyState ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors});

  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: colors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'No metrics found',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check your integrations',
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
