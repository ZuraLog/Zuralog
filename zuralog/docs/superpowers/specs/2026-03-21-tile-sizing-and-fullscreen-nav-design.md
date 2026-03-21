# Tile Sizing Uniformity & Fullscreen Navigation — Design Spec

**Date:** 2026-03-21
**Branch:** feature/data-tab-viz-system

---

## Problem Statement

1. **Non-uniform tile heights.** Tiles of the same `TileSize` vary in height because they size to their content, causing gaps in the masonry grid.
2. **Broken inline expand.** Tapping a tile replaces it in-place with `TileExpandedView`, disrupting the grid. Replace with fullscreen navigation to `MetricDetailScreen`.

---

## Solution 1 — Aspect-Ratio Tile Sizing

### Ratios

| TileSize | `AspectRatio.aspectRatio` | Effect |
|----------|--------------------------|--------|
| `square` | `1.0` | height = column width |
| `tall`   | `0.5` | height = 2 × column width |
| `wide`   | `2.0` | height = full-row-width ÷ 2 (~179pt on a 390pt screen) |

Responsive to any device width. Wide tiles at 2:1 produce a comfortable landscape-card height.

### Where to apply

`AspectRatio` is applied **only in `_buildTappableTile`** in `tile_grid.dart`. This covers both masonry-band tiles and full-width wide-band tiles since both paths go through `_buildTappableTile` in normal mode.

**Edit mode (`_buildEditTile`, `_buildEditHiddenTile`) is excluded.** Edit mode renders tiles in a full-width vertical reorderable list — applying the same ratios there would make a square tile as tall as the screen is wide. Edit mode keeps content-driven heights.

```dart
// In _buildTappableTile:
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

double _tileAspectRatio(TileSize size) => switch (size) {
  TileSize.square => 1.0,
  TileSize.tall   => 0.5,
  TileSize.wide   => 2.0,
};
```

### `MetricTile` fix

Two changes in `metric_tile.dart`:

1. **Remove `minHeight` constraint** from the `Container` in `_buildContent`:
   ```dart
   // REMOVE:
   constraints: BoxConstraints(minHeight: isSquare ? 120 : 0),
   ```
   The `AspectRatio` parent now enforces a concrete height, making `minHeight` redundant.

2. **Change `Column` to `MainAxisSize.max`** in `_buildTileContent`:
   ```dart
   // CHANGE:
   mainAxisSize: MainAxisSize.min  →  mainAxisSize: MainAxisSize.max
   ```
   This makes the column fill its `AspectRatio`-determined height. The `Expanded` wrapper around `buildTileVisualization` (added in the previous commit) now has a bounded height to expand into on all tile sizes — this is the key beneficiary of the change.

---

## Solution 2 — Remove Inline Expand; Navigate Fullscreen

### Behaviour change

Tapping **any non-hidden tile** (regardless of `TileDataState`) navigates to `MetricDetailScreen` via `context.push('/data/metric/${tileId.name}')`. Edit mode taps remain a no-op (existing guard: `if (_isEditMode) return`). `MetricDetailScreen` is already responsible for rendering appropriate state (no source, syncing, no data for range).

### What is deleted

**`tile_expanded_view.dart`** — the entire file is deleted.

**From `TileGrid` (`tile_grid.dart`):**
- Parameters: `expandedTileId`, `onViewDetails`, `onAskCoach`
- The `isExpanded`/`TileExpandedView` branch inside `_buildTileContent` (lines 101–133)

**From `_TileGridBox` (`health_dashboard_screen.dart`):**
- Parameters: `expandedTileId`, `onViewDetails`, `onAskCoach`
- Their forwarding calls to `TileGrid`

**From `_HealthDashboardScreenState` (`health_dashboard_screen.dart`):**
- `TileId? _expandedTileId` field
- `void _onViewDetails(TileId tileId)` method
- `void _onAskCoach(TileId tileId, String primaryValue)` method
- The `_expandedTileId = null` line inside `_enterEditMode` (rest of the `setState` block stays)
- The `_expandedTileId = null` line inside `CategoryFilterChips.onSelected` (rest of that `setState` block stays — `_globalTimeRangeSnapshot`, `_categoryTimeRange` logic is unaffected)

### What changes

**`_onTileTap`** (`health_dashboard_screen.dart`):
```dart
// BEFORE:
void _onTileTap(TileId tileId) {
  if (_isEditMode) return;
  setState(() {
    if (_expandedTileId == tileId) {
      _expandedTileId = null;
    } else {
      _expandedTileId = tileId;
    }
  });
}

// AFTER:
void _onTileTap(TileId tileId) {
  if (_isEditMode) return;
  context.push('/data/metric/${tileId.name}');
}
```

**`SearchOverlay.onTileSelected`** callback (`health_dashboard_screen.dart`):
```dart
// BEFORE:
onTileSelected: (tileId) {
  setState(() {
    _showSearch = false;
    _expandedTileId = tileId;            // REMOVE
    ref.read(tileFilterProvider.notifier).state = null;  // REMOVE
    _categoryTimeRange = null;           // REMOVE
  });
},

// AFTER:
onTileSelected: (tileId) {
  setState(() => _showSearch = false);
  context.push('/data/metric/${tileId.name}');
},
```
Three lines are removed from the `setState` block: `_expandedTileId = tileId`, `ref.read(tileFilterProvider.notifier).state = null`, and `_categoryTimeRange = null`. All three were only needed to make the expanded tile visible in the grid — navigating away from the dashboard makes them irrelevant. On `context.pop`, the dashboard restores with whatever filter state it had before the search.

**`_TileGridBox` call site** (inside the screen's `build`):
- Remove `expandedTileId: _expandedTileId`
- Remove `onViewDetails: _onViewDetails`
- Remove `onAskCoach: _onAskCoach`

---

## Files Changed

| File | Change |
|------|--------|
| `lib/features/data/presentation/widgets/tile_grid.dart` | Add `AspectRatio` in `_buildTappableTile`; add `_tileAspectRatio` helper; remove `expandedTileId`/`onViewDetails`/`onAskCoach` params; remove `TileExpandedView` branch from `_buildTileContent` |
| `lib/features/data/presentation/widgets/metric_tile.dart` | `Column` → `MainAxisSize.max`; remove `minHeight` `BoxConstraints` |
| `lib/features/data/presentation/health_dashboard_screen.dart` | Remove `_expandedTileId`, `_onViewDetails`, `_onAskCoach`; update `_onTileTap`; update search overlay callback; clean up isolated `_expandedTileId = null` lines; remove 3 params from `_TileGridBox` |
| `lib/features/data/presentation/widgets/tile_expanded_view.dart` | **Deleted** |

---

## What Is NOT Changed

- `MetricDetailScreen` — no changes; handles all tile IDs and data states
- `_buildEditTile` and `_buildEditHiddenTile` — edit mode layout is unchanged; both still call `_buildTileContent` which after the branch removal will always render `MetricTile`
- `buildTileVisualization` and all viz widgets
- `CategoryFilterChips` logic other than the single `_expandedTileId = null` line
- `_enterEditMode` logic other than the single `_expandedTileId = null` line

---

## Testing

| File | Action |
|------|--------|
| `test/features/data/presentation/widgets/metric_tile_test.dart` | Pass unchanged — tests `MetricTile` in isolation (no `AspectRatio` parent), so all assertions including hidden-state zero-size remain valid |
| `test/features/data/presentation/widgets/interaction_test.dart` | Delete the `TileExpandedView` group (lines 52–175) **and** its import (`tile_expanded_view.dart`). Preserve the `SearchOverlay` group entirely |
| `test/features/data/presentation/health_dashboard_screen_test.dart` | Delete the entire `'Tile expand/collapse'` group (lines 469–562) and the `'Ask Coach from expanded tile'` test within the `'Ask Coach'` group. Preserve the `'Ask Coach category CTA'` test (unrelated to inline expand). Add one new test: tapping a loaded tile calls `context.push('/data/metric/<id>')` |
| All other data feature tests | Unaffected |
