# Tile Sizing Uniformity & Fullscreen Navigation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all tiles of the same type render at a consistent aspect-ratio height, and replace the inline expand behaviour with direct navigation to `MetricDetailScreen`.

**Architecture:** Two independent changes. (1) `AspectRatio` wrappers in `_buildTappableTile` enforce uniform tile heights; `MetricTile`'s column fills the constrained height. `SliverMasonryGrid` is masonry — it measures each child's height and advances columns independently, so `AspectRatio` children work correctly: the grid provides the bounded column width, `AspectRatio` computes height from it, and the grid advances by that height. (2) The entire inline-expand system (`_expandedTileId` state, `TileExpandedView`, three params on `TileGrid`/`_TileGridBox`) is deleted; `onTileTap` navigates directly via `context.push`.

**Tech Stack:** Flutter / Dart, go_router (`context.push`), `flutter_staggered_grid_view` (masonry grid).

**Spec:** `docs/superpowers/specs/2026-03-21-tile-sizing-and-fullscreen-nav-design.md`

---

## File Map

| File | What changes |
|------|-------------|
| `lib/features/data/presentation/widgets/metric_tile.dart` | `Column` → `MainAxisSize.max`; remove `minHeight` `BoxConstraints` |
| `lib/features/data/presentation/widgets/tile_grid.dart` | Add `_tileAspectRatio` helper + `AspectRatio` in `_buildTappableTile`; remove `expandedTileId`/`onViewDetails`/`onAskCoach` params; remove `TileExpandedView` branch from `_buildTileContent` |
| `lib/features/data/presentation/health_dashboard_screen.dart` | Remove `_expandedTileId`, `_onViewDetails`, `_onAskCoach`; simplify `_onTileTap`; update `SearchOverlay.onTileSelected`; remove 3 params from `_TileGridBox` call site and class |
| `lib/features/data/presentation/widgets/tile_expanded_view.dart` | **Deleted** |
| `test/features/data/presentation/health_dashboard_screen_test.dart` | Add navigation test in its own group; delete expand/collapse group; delete expand-dependent Ask Coach test |
| `test/features/data/presentation/widgets/interaction_test.dart` | Delete `TileExpandedView` group and its import |

---

## Task 1: Fix MetricTile to fill its parent height

**Files:**
- Modify: `lib/features/data/presentation/widgets/metric_tile.dart`

- [ ] **Step 1: Remove the `constraints` argument from the `Container` in `_buildContent`**

  In `_buildContent`, the `Container` currently starts:
  ```dart
  return Container(
    constraints: BoxConstraints(
      minHeight: isSquare ? 120 : 0,
    ),
    decoration: BoxDecoration(
  ```
  Remove the entire `constraints:` argument (the `BoxConstraints(...)` block). The `Container` should now start directly with `decoration:`:
  ```dart
  return Container(
    decoration: BoxDecoration(
  ```

- [ ] **Step 2: Change the `Column`'s `mainAxisSize` to `MainAxisSize.max` in `_buildTileContent`**

  In the loaded-state branch of `_buildTileContent`, the `Column` currently has:
  ```dart
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
  ```
  Change `MainAxisSize.min` to `MainAxisSize.max`:
  ```dart
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.max,
    children: [
  ```

- [ ] **Step 3: Run the metric_tile widget tests**

  ```bash
  cd zuralog && flutter test test/features/data/presentation/widgets/metric_tile_test.dart
  ```
  Expected: all pass. These tests run `MetricTile` in isolation with no `AspectRatio` parent, so all assertions (including hidden-state zero-size) remain valid.

- [ ] **Step 4: Run the full data feature tests**

  ```bash
  flutter test test/features/data/
  ```
  Expected: same pass/fail count as before this task. The one pre-existing failure (`Ask Coach category CTA`) is unrelated.

- [ ] **Step 5: Commit**

  ```bash
  git add lib/features/data/presentation/widgets/metric_tile.dart
  git commit -m "fix(data): MetricTile Column fills parent height — remove minHeight, use MainAxisSize.max"
  ```

---

## Task 2: Add aspect-ratio sizing to the normal-mode grid

**Files:**
- Modify: `lib/features/data/presentation/widgets/tile_grid.dart`

- [ ] **Step 1: Add the `_tileAspectRatio` helper inside the `TileGrid` class**

  Add this method inside the `TileGrid` class body, after the `_colorOverride` helper and before `_buildTileContent`:
  ```dart
  double _tileAspectRatio(TileSize size) => switch (size) {
    TileSize.square => 1.0,
    TileSize.tall   => 0.5,   // height = 2 × column width
    TileSize.wide   => 2.0,   // height = full-row-width ÷ 2
  };
  ```

- [ ] **Step 2: Wrap `_buildTappableTile` content in `AspectRatio`**

  The current implementation is:
  ```dart
  Widget _buildTappableTile(BuildContext context, TileId id) {
    return GestureDetector(
      onTap: () => onTileTap(id),
      child: _buildTileContent(context, id),
    );
  }
  ```
  Replace with (note: `_effectiveSize` is already defined on the class):
  ```dart
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
  ```
  `_buildEditTile` and `_buildEditHiddenTile` are **not** changed — edit mode uses a full-width vertical list where these ratios would produce incorrectly large tiles.

- [ ] **Step 3: Run flutter analyze**

  ```bash
  flutter analyze lib/features/data/presentation/widgets/tile_grid.dart
  ```
  Expected: no errors.

- [ ] **Step 4: Run the full data feature tests**

  ```bash
  flutter test test/features/data/
  ```
  Expected: same result as after Task 1.

- [ ] **Step 5: Commit**

  ```bash
  git add lib/features/data/presentation/widgets/tile_grid.dart
  git commit -m "feat(data): uniform tile heights via AspectRatio — square 1:1, tall 1:2, wide 2:1"
  ```

---

## Task 3: Write the failing navigation test (TDD)

**Files:**
- Modify: `test/features/data/presentation/health_dashboard_screen_test.dart`

The new test goes in its **own group**, placed **after** the existing `'Tile expand/collapse'` group (not inside it — that group will be deleted in Task 5 and the new test must survive that deletion).

- [ ] **Step 1: Add a new `'Tile tap navigation'` group after the expand/collapse group**

  Find the closing `});` of the `'Tile expand/collapse'` group (around line 562). After it, add:
  ```dart
  // ── Tile tap navigation ──────────────────────────────────────────────────────

  group('Tile tap navigation', () {
    testWidgets('tapping a loaded tile navigates to MetricDetailScreen',
        (tester) async {
      final tiles = [
        TileData(
          tileId: TileId.steps,
          dataState: TileDataState.loaded,
          lastUpdated: '2026-03-19T12:00:00Z',
          primaryValue: '8,432',
        ),
        ...TileId.values
            .where((id) => id != TileId.steps)
            .map((id) => TileData(
                  tileId: id,
                  dataState: TileDataState.noSource,
                )),
      ];
      final container = _container(tiles: tiles);
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('8,432').first);
      await tester.pumpAndSettle();

      expect(_lastRoute, '/data/metric/steps');
    });
  });
  ```
  How `_lastRoute` works: the test app's `GoRouter` sets `_lastRoute = '/data/metric/${state.pathParameters['id']}'` when navigating to that route, so a push to `/data/metric/steps` produces `_lastRoute == '/data/metric/steps'`.

- [ ] **Step 2: Run the new test and confirm it FAILS**

  ```bash
  flutter test test/features/data/presentation/health_dashboard_screen_test.dart \
    --name "tapping a loaded tile navigates to MetricDetailScreen"
  ```
  Expected: FAIL — because `_onTileTap` currently expands inline; `_lastRoute` remains `''`.

---

## Task 4: Remove the inline expand system

**Files:**
- Modify: `lib/features/data/presentation/widgets/tile_grid.dart`
- Modify: `lib/features/data/presentation/health_dashboard_screen.dart`
- Delete: `lib/features/data/presentation/widgets/tile_expanded_view.dart`

These changes must be made together — removing params from `TileGrid` immediately causes compile errors in `_TileGridBox` until it is updated too.

### 4a — `tile_grid.dart`

- [ ] **Step 1: Delete the `TileExpandedView` import**

  Remove this line near the top of the file:
  ```dart
  import 'package:zuralog/features/data/presentation/widgets/tile_expanded_view.dart';
  ```

- [ ] **Step 2: Remove the three params from `TileGrid`'s constructor**

  In the `TileGrid` constructor, delete:
  ```dart
  required this.expandedTileId,
  required this.onViewDetails,
  required this.onAskCoach,
  ```

- [ ] **Step 3: Remove the three fields from `TileGrid`**

  Delete:
  ```dart
  final TileId? expandedTileId;
  final void Function(TileId) onViewDetails;
  final void Function(TileId, String primaryValue) onAskCoach;
  ```

- [ ] **Step 4: Remove the `TileExpandedView` branch from `_buildTileContent`**

  The method opens with an expand check. Delete everything from the `// If the tile is expanded` comment through the closing `}` of that `if` block — including the `isExpanded`, `vizConfig`, `effectiveColor`, and `effectiveExpandedSize` locals that only exist for that branch:
  ```dart
  // DELETE from here...
  final isExpanded = expandedTileId == id;

  // If the tile is expanded, render TileExpandedView.
  if (isExpanded && tileData != null && tileData.dataState == TileDataState.loaded) {
    final vizConfig = tileData.vizConfig;
    final effectiveColor = ...;
    final effectiveExpandedSize = ...;
    return TileExpandedView(...);
  }
  // ...to here (inclusive)
  ```
  After deletion, `_buildTileContent` starts directly with `// Otherwise render MetricTile.` — rename that comment to `// Render MetricTile.`.

### 4b — `health_dashboard_screen.dart`

- [ ] **Step 5: Delete the `_expandedTileId` field**

  Remove:
  ```dart
  TileId? _expandedTileId;
  ```

- [ ] **Step 6: Delete `_onViewDetails` and `_onAskCoach` methods entirely**

  Remove both method bodies:
  ```dart
  void _onViewDetails(TileId tileId) {
    context.push('/data/metric/${tileId.name}');
  }

  void _onAskCoach(TileId tileId, String primaryValue) {
    ref.read(coachPrefillProvider.notifier).state =
        'Tell me about my ${tileId.displayName}: $primaryValue';
    context.go('/coach');
  }
  ```

- [ ] **Step 7: Simplify `_onTileTap`**

  Replace the entire body:
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

- [ ] **Step 8: Remove `_expandedTileId = null` from `_enterEditMode`**

  Inside `_enterEditMode`, the `setState` block has:
  ```dart
  setState(() {
    _isEditMode = true;
    _expandedTileId = null; // collapse any expanded tile  ← DELETE THIS LINE ONLY
    _reorderedDuringEdit = false;
  });
  ```
  Delete only the `_expandedTileId = null;` line and its comment. Leave everything else in the block.

- [ ] **Step 9: Remove `_expandedTileId = null` from `CategoryFilterChips.onSelected`**

  In the `onSelected` callback, the `setState` block starts:
  ```dart
  setState(() {
    _expandedTileId = null;   ← DELETE THIS LINE ONLY
    if (cat != null) {
  ```
  Delete only that one line. All surrounding logic stays unchanged.

- [ ] **Step 10: Update `SearchOverlay.onTileSelected`**

  Replace:
  ```dart
  onTileSelected: (tileId) {
    setState(() {
      _showSearch = false;
      _expandedTileId = tileId;                              // remove
      ref.read(tileFilterProvider.notifier).state = null;   // remove
      _categoryTimeRange = null;                             // remove
    });
  },
  ```
  With:
  ```dart
  onTileSelected: (tileId) {
    setState(() => _showSearch = false);
    context.push('/data/metric/${tileId.name}');
  },
  ```

- [ ] **Step 11: Remove 3 params from the `_TileGridBox` call site**

  Where `_TileGridBox(...)` is constructed in the `build` method, remove:
  ```dart
  expandedTileId: _expandedTileId,
  onViewDetails: _onViewDetails,
  onAskCoach: _onAskCoach,
  ```

- [ ] **Step 12: Remove 3 params from the `_TileGridBox` class**

  In the `_TileGridBox` class at the bottom of the file:

  From the constructor, remove:
  ```dart
  required this.expandedTileId,
  required this.onViewDetails,
  required this.onAskCoach,
  ```
  From the field declarations, remove:
  ```dart
  final TileId? expandedTileId;
  final void Function(TileId) onViewDetails;
  final void Function(TileId, String) onAskCoach;
  ```
  From the `TileGrid(...)` call inside `_TileGridBox.build`, remove:
  ```dart
  expandedTileId: expandedTileId,
  onViewDetails: onViewDetails,
  onAskCoach: onAskCoach,
  ```

### 4c — Delete the file

- [ ] **Step 13: Delete `tile_expanded_view.dart`**

  ```bash
  rm lib/features/data/presentation/widgets/tile_expanded_view.dart
  ```

- [ ] **Step 14: Verify no compile errors**

  ```bash
  flutter analyze lib/features/data/
  ```
  Expected: no errors (pre-existing info-level warnings are fine).

- [ ] **Step 15: Run the navigation test from Task 3 — it must now PASS**

  ```bash
  flutter test test/features/data/presentation/health_dashboard_screen_test.dart \
    --name "tapping a loaded tile navigates to MetricDetailScreen"
  ```
  Expected: PASS — `_lastRoute == '/data/metric/steps'`.

- [ ] **Step 16: Commit**

  ```bash
  git add lib/features/data/presentation/widgets/tile_grid.dart \
          lib/features/data/presentation/health_dashboard_screen.dart
  git rm lib/features/data/presentation/widgets/tile_expanded_view.dart
  git commit -m "feat(data): replace inline expand with fullscreen navigation — tap tile → MetricDetailScreen"
  ```

---

## Task 5: Clean up tests

**Files:**
- Modify: `test/features/data/presentation/widgets/interaction_test.dart`
- Modify: `test/features/data/presentation/health_dashboard_screen_test.dart`

- [ ] **Step 1: Remove the `TileExpandedView` import from `interaction_test.dart`**

  Delete line 13:
  ```dart
  import 'package:zuralog/features/data/presentation/widgets/tile_expanded_view.dart';
  ```

- [ ] **Step 2: Delete the `TileExpandedView` test group from `interaction_test.dart`**

  Delete everything from the section-header comment through the group's closing `});`. In the current file this starts at the comment `// ═══ TileExpandedView tests ═══` (around line 48) and ends at the `});` that closes `group('TileExpandedView', ...)` (around line 175). Delete all of it. The `SearchOverlay` group that follows must remain completely intact.

  Update the file's top-level docstring (line 3) from:
  ```dart
  /// Tests for [TileExpandedView] and [SearchOverlay].
  ```
  to:
  ```dart
  /// Tests for [SearchOverlay].
  ```

- [ ] **Step 3: Delete the `'Tile expand/collapse'` group from `health_dashboard_screen_test.dart`**

  Delete everything from the `// ── Tile expand / collapse ──` section comment through the group's closing `});` (lines 469–562 approximately, inclusive of the comment header and the final `});`).

- [ ] **Step 4: Delete the `'Ask Coach from expanded tile'` test**

  Inside the `group('Ask Coach', ...)` block, delete only the first `testWidgets` — `'Ask Coach from expanded tile sets coachPrefillProvider'` (lines 567–601 approximately). Leave the `'Ask Coach category CTA navigates to /coach with prefill'` test untouched.

- [ ] **Step 5: Run the full data feature test suite**

  ```bash
  flutter test test/features/data/
  ```
  Expected: all tests pass except the one pre-existing failure (`'Ask Coach category CTA navigates to /coach with prefill'` — already failing before this branch, unrelated to these changes).

- [ ] **Step 6: Run flutter analyze across lib and test**

  ```bash
  flutter analyze lib/features/data/ test/features/data/
  ```
  Expected: no errors.

- [ ] **Step 7: Commit**

  ```bash
  git add test/features/data/presentation/widgets/interaction_test.dart \
          test/features/data/presentation/health_dashboard_screen_test.dart
  git commit -m "test(data): remove expand/collapse tests; add tile-tap navigation assertion"
  ```

---

## Done

All tasks complete. The dashboard now has:
- Uniform tile heights on any device (1×1 square, 1×2 tall, 2×1 wide via aspect ratio)
- Tapping a tile navigates directly to `MetricDetailScreen` fullscreen
- Zero inline-expand code remaining in the codebase
