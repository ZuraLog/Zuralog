# Loading States, Skeleton Screens & Empty States — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every static, missing, or misleading loading/empty/error state in the data feature with animated skeleton screens, clear empty states with recovery CTAs, and consistent visual staleness treatment.

**Architecture:** A new shared `AppShimmer` + `ShimmerBox` widget pair (using `ShaderMask` + `LinearGradient`) provides a single left-to-right sweep animation reused across all skeleton screens. Each skeleton's internal layout mirrors the real content structure. All error states gain retry buttons; all empty chart states gain iconography and CTAs.

**Tech Stack:** Flutter, `flutter_test`, Riverpod (ProviderScope not needed for any widget in this plan — all tested widgets are standalone or wrapped in plain `MaterialApp`), existing `AppColors`/`AppColorsOf` theme tokens.

**Spec:** `docs/superpowers/specs/2026-03-21-loading-states-design.md`

---

## File Map

| File | Status | Responsibility |
|------|--------|---------------|
| `lib/core/widgets/shimmer.dart` | **Create** | `AppShimmer` scope + `ShimmerBox` placeholder shape |
| `lib/features/data/presentation/health_dashboard_screen.dart` | Modify | Upgrade `_CardSkeleton`, add `_DashboardSkeletonBox`, fix cross-fade |
| `lib/features/data/presentation/widgets/health_score_strip.dart` | Modify | Animate `_SkeletonRow` with `AppShimmer` |
| `lib/features/data/presentation/widgets/tile_empty_states.dart` | Modify | Rewrite `SyncingTileContent`; staleness in `NoDataForRangeTileContent` |
| `lib/features/data/presentation/widgets/metric_tile.dart` | Modify | Update `noDataForRange` semantics label |
| `lib/features/data/presentation/metric_detail_screen.dart` | Modify | Skeleton load state; AppBar title fix; error retry; empty/single-point CTAs |
| `lib/features/data/domain/tile_visualization_config.dart` | Modify | Add `hasChartData` getter to sealed class and chart-type subclasses |
| `lib/features/data/presentation/widgets/tile_visualizations.dart` | Modify | Add `_VizEmptyPlaceholder` + upstream `hasChartData` check |
| `test/core/widgets/shimmer_test.dart` | **Create** | Tests for `AppShimmer` + `ShimmerBox` |
| `test/features/data/presentation/widgets/metric_tile_test.dart` | Modify | Update `SyncingTileContent` + `NoDataForRangeTileContent` groups |
| `test/features/data/presentation/metric_detail_screen_test.dart` | **Create** | Tests for loading skeleton, error retry, empty/single-point states |
| `test/features/data/domain/tile_visualization_config_test.dart` | Modify | Add `hasChartData` tests |
| `test/features/data/presentation/widgets/tile_visualizations_test.dart` | Modify | Update BarChartViz dispatch test; add empty-config test |

---

## Task 1: Create `AppShimmer` + `ShimmerBox`

**Files:**
- Create: `lib/core/widgets/shimmer.dart`
- Create: `test/core/widgets/shimmer_test.dart`

### Background
`AppShimmer` is a `StatefulWidget` that wraps its child in a `ShaderMask`. The mask applies a `LinearGradient` whose `begin`/`end` alignments are animated from left-off-screen to right-off-screen, creating a synchronized left-to-right sweep over all `ShimmerBox` children simultaneously. `ShimmerBox` is a plain stateless `Container` filled with `Colors.white` — the `ShaderMask` replaces that white with the shimmer gradient.

**Critical:** `ShimmerBox` children MUST use `Colors.white` (fully opaque) as fill. The `ShaderMask` with `BlendMode.srcIn` uses the child's alpha as a mask — transparent fills would produce a faint/invisible shimmer.

- [ ] **Step 1.1: Write failing tests**

```dart
// test/core/widgets/shimmer_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/core/widgets/shimmer.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: ThemeData.light(), home: Scaffold(body: child));

void main() {
  group('AppShimmer', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        _wrap(SizedBox(
          width: 200, height: 100,
          child: AppShimmer(
            child: ShimmerBox(height: 20, width: 80),
          ),
        )),
      );
      await tester.pump();
      expect(find.byType(AppShimmer), findsOneWidget);
    });

    testWidgets('animation progresses — pumping frames does not throw',
        (tester) async {
      await tester.pumpWidget(
        _wrap(SizedBox(
          width: 200, height: 100,
          child: AppShimmer(child: ShimmerBox(height: 20, width: 80)),
        )),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      // Verify widget still present after animation frames — no ticker error
      expect(find.byType(AppShimmer), findsOneWidget);
    });
  });

  group('ShimmerBox', () {
    testWidgets('renders with fixed height and width', (tester) async {
      await tester.pumpWidget(
        _wrap(AppShimmer(child: ShimmerBox(height: 20, width: 80))),
      );
      await tester.pump();
      expect(find.byType(ShimmerBox), findsOneWidget);
    });

    testWidgets('renders as circle when isCircle is true', (tester) async {
      await tester.pumpWidget(
        _wrap(AppShimmer(child: ShimmerBox(height: 24, isCircle: true))),
      );
      await tester.pump();
      final container =
          tester.widget<Container>(find.descendant(
            of: find.byType(ShimmerBox),
            matching: find.byType(Container),
          ).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('fills parent when no dimensions provided (inside Expanded)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(AppShimmer(
          child: SizedBox(
            width: 100, height: 50,
            child: Column(
              children: [
                Expanded(child: ShimmerBox()),
              ],
            ),
          ),
        )),
      );
      await tester.pump();
      expect(find.byType(ShimmerBox), findsOneWidget);
    });
  });
}
```

- [ ] **Step 1.2: Run tests — expect FAIL (file does not exist yet)**

```
flutter test test/core/widgets/shimmer_test.dart
```
Expected: compilation error — `'package:zuralog/core/widgets/shimmer.dart'` not found.

- [ ] **Step 1.3: Create `lib/core/widgets/shimmer.dart`**

```dart
/// Zuralog — Shared shimmer animation widgets.
///
/// [AppShimmer] wraps any child in a left-to-right shimmer sweep using
/// [ShaderMask] + [LinearGradient]. [ShimmerBox] is a plain white placeholder
/// shape — [AppShimmer] applies the animated gradient over it.
///
/// Usage:
/// ```dart
/// AppShimmer(
///   child: Column(children: [
///     ShimmerBox(height: 12, width: 80),
///     ShimmerBox(height: 24, widthFraction: 0.6),
///   ]),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';

// ── AppShimmer ─────────────────────────────────────────────────────────────────

/// Wraps [child] in an animated left-to-right shimmer sweep.
///
/// Uses [ShaderMask] + [LinearGradient] so all [ShimmerBox] descendants are
/// animated in perfect sync from a single [AnimationController].
///
/// Child shapes MUST use opaque fill (e.g. [Colors.white]) — [BlendMode.srcIn]
/// uses the child's alpha channel as the mask for the gradient.
///
/// Does NOT apply [ExcludeSemantics] internally — callers provide their own
/// [Semantics] wrapper with an appropriate label.
class AppShimmer extends StatefulWidget {
  const AppShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _animation.value; // 0.0 → 1.0, eased
        // Sweep gradient from left-off-screen (-2) to right-off-screen (+2)
        final begin = Alignment(-2.0 + 4.0 * t, 0);
        final end = Alignment(-1.0 + 4.0 * t, 0);
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: begin,
            end: end,
            colors: [
              colors.shimmerBase,
              colors.shimmerHighlight,
              colors.shimmerBase,
            ],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ── ShimmerBox ─────────────────────────────────────────────────────────────────

/// A stateless placeholder shape for use inside [AppShimmer].
///
/// Renders as a solid white [Container] (the [ShaderMask] replaces white with
/// the shimmer gradient). When [height] and [width] are both omitted, the
/// widget expands to fill its parent — use inside [Expanded] for chart-area
/// placeholders.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.height,
    this.width,
    this.widthFraction,
    this.borderRadius,
    this.isCircle = false,
  });

  /// Fixed height. Omit when inside [Expanded] (fills available space).
  final double? height;

  /// Fixed width. Omit to let parent constrain.
  final double? width;

  /// Fractional width 0–1. Uses [FractionallySizedBox] when provided.
  /// Mutually exclusive with [width].
  final double? widthFraction;

  /// Corner radius. Defaults to `BorderRadius.circular(4)`.
  /// Ignored when [isCircle] is true.
  final BorderRadius? borderRadius;

  /// Renders as a circle (`BoxShape.circle`). [height] is used as diameter.
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      height: height,
      width: widthFraction != null ? null : width,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle
            ? null
            : (borderRadius ?? BorderRadius.circular(4)),
      ),
    );

    if (widthFraction != null) {
      return FractionallySizedBox(
        widthFactor: widthFraction,
        alignment: Alignment.centerLeft,
        child: box,
      );
    }
    return box;
  }
}
```

- [ ] **Step 1.4: Run tests — expect PASS**

```
flutter test test/core/widgets/shimmer_test.dart
```
Expected: All 4 tests pass.

- [ ] **Step 1.5: Commit**

```
git add lib/core/widgets/shimmer.dart test/core/widgets/shimmer_test.dart
git commit -m "feat(core): add AppShimmer + ShimmerBox for consistent skeleton animation"
```

---

## Task 2: Upgrade `_CardSkeleton` + Dashboard Cross-fade

**Files:**
- Modify: `lib/features/data/presentation/health_dashboard_screen.dart`

### Background
`_CardSkeleton` is currently a static 120px blank rectangle. We replace it with an animated layout-aware skeleton. We also fix the cross-fade regression: the loading state currently lives outside the `AnimatedSwitcher`, so loading→loaded snaps rather than cross-fading. We extract the loading content into `_DashboardSkeletonBox` and move it inside the switcher.

**Scope:** Only the final `else if (tilesAsync.isLoading) / else` pair changes. The `allNoSource` and `allNoSource + hasNetworkError` branches above are untouched.

- [ ] **Step 2.1: Update `_CardSkeleton` in `health_dashboard_screen.dart`**

Locate `_CardSkeleton` (currently around line 816). Replace the entire class:

```dart
// ── Skeleton widgets ──────────────────────────────────────────────────────────

/// Animated layout-aware skeleton for a single metric tile card.
///
/// Internal structure mirrors [MetricTile]'s loaded layout:
/// header row → value → unit → chart area.
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Semantics(
      label: 'Loading dashboard metrics',
      excludeSemantics: true,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          boxShadow: colors.isDark ? null : AppDimens.cardShadowLight,
        ),
        padding: const EdgeInsets.all(12),
        child: AppShimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: dot + name + spacer + icon slot
              Row(
                children: [
                  ShimmerBox(height: 8, width: 8, isCircle: true),
                  const SizedBox(width: 6),
                  ShimmerBox(height: 8, width: 64),
                  const Spacer(),
                  ShimmerBox(height: 14, width: 14),
                ],
              ),
              const SizedBox(height: 8),
              // Primary value
              ShimmerBox(height: 28, width: 56),
              const SizedBox(height: 4),
              // Unit label
              ShimmerBox(height: 8, width: 36),
              const SizedBox(height: 8),
              // Chart area — fills remaining height
              Expanded(
                child: ShimmerBox(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Box widget wrapping 6 [_CardSkeleton]s — used in [AnimatedSwitcher].
class _DashboardSkeletonBox extends StatelessWidget {
  const _DashboardSkeletonBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading dashboard metrics',
      excludeSemantics: true,
      child: Column(
        children: List.generate(6, (_) => const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceXs,
          ),
          child: _CardSkeleton(),
        )),
      ),
    );
  }
}
```

- [ ] **Step 2.2: Fix the cross-fade in `_buildLoadingSlivers` area**

Find the section inside `build()` that reads (around line 435):
```dart
else if (tilesAsync.isLoading)
  _buildLoadingSlivers()
else
  SliverToBoxAdapter(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: _TileGridBox(
        key: ValueKey(activeFilter),
        ...
      ),
    ),
  ),
```

Replace with:
```dart
else
  SliverToBoxAdapter(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: tilesAsync.isLoading
          ? const _DashboardSkeletonBox(key: ValueKey('loading'))
          : _TileGridBox(
              key: ValueKey(activeFilter),
              orderedTileIds: filteredTileIds,
              tiles: tileMap,
              layout: layout,
              isEditMode: _isEditMode,
              onTileTap: _onTileTap,
              onSizeChanged: _onSizeChanged,
              onVisibilityToggled: _onVisibilityToggled,
              onColorPick: _onColorPick,
              onReorder: _onReorder,
            ),
    ),
  ),
```

Then delete the now-unused `_buildLoadingSlivers()` method.

- [ ] **Step 2.3: Add imports at top of `health_dashboard_screen.dart`**

After the existing imports, add:
```dart
import 'package:zuralog/core/widgets/shimmer.dart';
```

- [ ] **Step 2.4: Run the existing dashboard screen tests**

```
flutter test test/features/data/presentation/health_dashboard_screen_test.dart
```
Expected: All existing tests pass (the `isLoading` branch behavior is functionally equivalent).

- [ ] **Step 2.5: Commit**

```
git add lib/features/data/presentation/health_dashboard_screen.dart
git commit -m "feat(data): animated _CardSkeleton + dashboard skeleton→grid cross-fade"
```

---

## Task 3: Animate `_SkeletonRow` in `HealthScoreStrip`

**Files:**
- Modify: `lib/features/data/presentation/widgets/health_score_strip.dart`

### Background
`_SkeletonRow` uses the correct `shimmerBase` color tokens but has no animation. Wrapping its content in `AppShimmer` (and switching fill to `Colors.white`) adds the sweep shimmer with zero structural changes.

- [ ] **Step 3.1: Update `_SkeletonRow`**

Locate `_SkeletonRow` (around line 233). Replace with:

```dart
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Score ring circle
          ShimmerBox(height: 36, width: 36, isCircle: true),
          const SizedBox(width: 10),
          // Score number + "Health Score" label
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShimmerBox(height: 18, width: 32),
              const SizedBox(height: 4),
              ShimmerBox(height: 12, width: 72),
            ],
          ),
          const Spacer(),
          // Stats text area
          ShimmerBox(height: 12, width: 80),
          const SizedBox(width: 12),
          // Chevron placeholder
          ShimmerBox(height: 18, width: 18),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3.2: Add import at top of `health_score_strip.dart`**

```dart
import 'package:zuralog/core/widgets/shimmer.dart';
```

- [ ] **Step 3.3: Run health score strip related tests**

```
flutter test test/features/data/presentation/health_dashboard_screen_test.dart
```
Expected: All tests pass (the strip's loading semantics `'Health score. Loading.'` is unchanged — it wraps `_SkeletonRow`, not the inside).

- [ ] **Step 3.4: Commit**

```
git add lib/features/data/presentation/widgets/health_score_strip.dart
git commit -m "feat(data): animate _SkeletonRow in HealthScoreStrip with AppShimmer sweep"
```

---

## Task 4: Rewrite `SyncingTileContent`

**Files:**
- Modify: `lib/features/data/presentation/widgets/tile_empty_states.dart`
- Modify: `test/features/data/presentation/widgets/metric_tile_test.dart`

### Background
`SyncingTileContent` currently has its own `AnimationController` doing a fade pulse over 3 uniform bars. We rewrite it to use `AppShimmer` with a layout that mirrors a real tile (header row → value → unit → chart area). This makes it stateless — no own `AnimationController` needed.

**Breaking change to existing tests:**
- `'renders "Syncing..." text'` — will fail (label removed)
- `'renders shimmer bar containers'` — will fail (old keys removed)
- `'animation runs...'` — behavior changes (no own ticker; `AppShimmer` provides animation)

- [ ] **Step 4.1: Update the `SyncingTileContent` group in `metric_tile_test.dart`**

Find the `group('SyncingTileContent', ...)` block (around line 79) and replace with:

```dart
group('SyncingTileContent', () {
  testWidgets('renders without error', (tester) async {
    await tester.pumpWidget(
      _wrap(const SizedBox(
        width: 150, height: 150,
        child: SyncingTileContent(),
      )),
    );
    await tester.pump();
    expect(find.byType(SyncingTileContent), findsOneWidget);
  });

  testWidgets('contains AppShimmer', (tester) async {
    await tester.pumpWidget(
      _wrap(const SizedBox(
        width: 150, height: 150,
        child: SyncingTileContent(),
      )),
    );
    await tester.pump();
    expect(find.byType(AppShimmer), findsOneWidget);
  });

  testWidgets('animation runs — pumping frames does not throw',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const SizedBox(
        width: 150, height: 150,
        child: SyncingTileContent(),
      )),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    // AppShimmer repeats indefinitely — do NOT pumpAndSettle.
    expect(find.byType(SyncingTileContent), findsOneWidget);
  });
});
```

Add the shimmer import to the test file:
```dart
import 'package:zuralog/core/widgets/shimmer.dart';
```

- [ ] **Step 4.2: Run updated tests — expect FAIL on old assertions**

```
flutter test test/features/data/presentation/widgets/metric_tile_test.dart --name "SyncingTileContent"
```
Expected: FAIL — `find.text('Syncing...')` and `find.byKey(Key('shimmer_bar_0'))` etc. in old tests, OR the new tests fail because `AppShimmer` doesn't exist inside `SyncingTileContent` yet.

- [ ] **Step 4.3: Rewrite `SyncingTileContent` in `tile_empty_states.dart`**

Find and replace the entire `SyncingTileContent` class (around lines 122–233). Also remove the private `_ShimmerBar` widget (replaced by `ShimmerBox`):

```dart
// ── SyncingTileContent ────────────────────────────────────────────────────────

/// Content area for a tile in the [TileDataState.syncing] state.
///
/// Shows an animated shimmer skeleton whose layout mirrors a loaded tile:
/// header row → primary value → unit → chart area.
/// Uses [AppShimmer] for the sweep animation — no own [AnimationController].
class SyncingTileContent extends StatelessWidget {
  const SyncingTileContent({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: category dot + metric name + spacer + emoji icon
          Row(
            children: [
              ShimmerBox(height: 8, width: 8, isCircle: true),
              const SizedBox(width: 6),
              ShimmerBox(height: 8, width: 80),
              const Spacer(),
              ShimmerBox(height: 14, width: 14),
            ],
          ),
          const SizedBox(height: 8),
          // Primary value
          ShimmerBox(height: 28, width: 60),
          const SizedBox(height: 4),
          // Unit label
          ShimmerBox(height: 8, width: 40),
          const SizedBox(height: 8),
          // Chart area — fills remaining height
          Expanded(
            child: ShimmerBox(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}
```

Add the shimmer import to `tile_empty_states.dart`:
```dart
import 'package:zuralog/core/widgets/shimmer.dart';
```

Remove the `_ShimmerBar` private widget that follows the class (it is replaced by `ShimmerBox`). It exists between `SyncingTileContent` and `NoDataForRangeTileContent`.

- [ ] **Step 4.4: Run tests — expect PASS**

```
flutter test test/features/data/presentation/widgets/metric_tile_test.dart
```
Expected: All tests pass (old `SyncingTileContent` tests replaced by new ones; other groups unchanged).

- [ ] **Step 4.5: Commit**

```
git add lib/features/data/presentation/widgets/tile_empty_states.dart \
        test/features/data/presentation/widgets/metric_tile_test.dart
git commit -m "feat(data): rewrite SyncingTileContent — layout-aware AppShimmer skeleton"
```

---

## Task 5: `NoDataForRangeTileContent` Staleness Treatment

**Files:**
- Modify: `lib/features/data/presentation/widgets/tile_empty_states.dart`
- Modify: `lib/features/data/presentation/widgets/metric_tile.dart`
- Modify: `test/features/data/presentation/widgets/metric_tile_test.dart`

### Background
The current `NoDataForRangeTileContent` looks identical to a loaded tile. We add an amber history icon + amber "Last: Xd ago" text to communicate staleness clearly. We also update `MetricTile`'s semantic label for `noDataForRange`.

No existing test asserts the old semantic label string (confirmed by search), so no semantic-label test breaks.

- [ ] **Step 5.1: Add staleness tests to `metric_tile_test.dart`**

Inside the `group('NoDataForRangeTileContent', ...)` block, add after the existing tests:

```dart
testWidgets('shows history icon for staleness signal', (tester) async {
  await tester.pumpWidget(
    _wrap(
      NoDataForRangeTileContent(
        lastKnownValue: '8,432',
        lastUpdated: DateTime.now()
            .subtract(const Duration(days: 2))
            .toIso8601String(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byIcon(Icons.history_rounded), findsOneWidget);
});

testWidgets('"Last:" label uses amber statusConnecting color', (tester) async {
  await tester.pumpWidget(
    _wrap(
      NoDataForRangeTileContent(
        lastKnownValue: '8,432',
        lastUpdated: DateTime.now()
            .subtract(const Duration(days: 2))
            .toIso8601String(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The "Last:" text should be rendered with statusConnecting (amber) color.
  final lastText = tester.widgetList<Text>(
    find.textContaining('Last:'),
  ).first;
  expect(lastText.style?.color, equals(AppColors.statusConnecting));
});
```

- [ ] **Step 5.2: Run — expect FAIL on new tests**

```
flutter test test/features/data/presentation/widgets/metric_tile_test.dart --name "NoDataForRangeTileContent"
```
Expected: The two new tests fail — no history icon, no amber color yet.

- [ ] **Step 5.3: Update `NoDataForRangeTileContent` in `tile_empty_states.dart`**

Find the `build()` method of `NoDataForRangeTileContent` (around line 271). Replace:

```dart
@override
Widget build(BuildContext context) {
  final colors = AppColorsOf(context);
  final relTime = _relativeTime(lastUpdated);

  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        lastKnownValue,
        style: AppTextStyles.displayMedium.copyWith(
          color: colors.textPrimary,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Last: $relTime',
        style: AppTextStyles.labelSmall.copyWith(
          color: colors.textTertiary,
        ),
      ),
    ],
  );
}
```

With:

```dart
@override
Widget build(BuildContext context) {
  final colors = AppColorsOf(context);
  final relTime = _relativeTime(lastUpdated);

  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Value at reduced opacity — signals "this is not live data"
      Opacity(
        opacity: 0.65,
        child: Text(
          lastKnownValue,
          style: AppTextStyles.displayMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ),
      const SizedBox(height: 4),
      // Amber history row — signals staleness.
      // ExcludeSemantics: the icon is decorative; the tile's Semantics label
      // (updated in Step 5.4) already communicates staleness to screen readers.
      ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history_rounded,
              size: 11,
              color: AppColors.statusConnecting,
            ),
            const SizedBox(width: 3),
            Text(
              'Last: $relTime',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.statusConnecting,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
```

- [ ] **Step 5.4: Update `noDataForRange` semantics label in `metric_tile.dart`**

Find the `label` switch in `MetricTile.build()` (around line 106). Update the `noDataForRange` case:

```dart
TileDataState.noDataForRange =>
    '${tileId.displayName}: last known value ${primaryValue ?? '—'}, data may be outdated',
```

- [ ] **Step 5.5: Run tests — expect PASS**

```
flutter test test/features/data/presentation/widgets/metric_tile_test.dart
```
Expected: All tests pass.

- [ ] **Step 5.6: Commit**

```
git add lib/features/data/presentation/widgets/tile_empty_states.dart \
        lib/features/data/presentation/widgets/metric_tile.dart \
        test/features/data/presentation/widgets/metric_tile_test.dart
git commit -m "feat(data): stale data treatment in NoDataForRangeTileContent — amber icon + dim value"
```

---

## Task 6: `MetricDetailScreen` — Loading Skeleton + AppBar Fix

**Files:**
- Modify: `lib/features/data/presentation/metric_detail_screen.dart`
- Create: `test/features/data/presentation/metric_detail_screen_test.dart`

### Background
Currently loading shows a bare `CircularProgressIndicator` and the AppBar title disappears (`SizedBox.shrink()`). We replace both:
- AppBar immediately shows the formatted `metricId` (e.g. `"heart_rate_resting"` → `"Heart Rate Resting"`) using a `_formatMetricId()` helper.
- Body shows `_MetricDetailSkeleton` — an `AppShimmer`-animated layout matching the screen structure.
- A wrapping `AnimatedSwitcher` cross-fades between skeleton and loaded content.

- [ ] **Step 6.1: Write failing tests**

```dart
// test/features/data/presentation/metric_detail_screen_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/widgets/shimmer.dart';
import 'package:zuralog/features/data/presentation/metric_detail_screen.dart';

/// Minimal provider override that puts [metricDetailProvider] in loading state.
/// We test the loading/error/empty UI by testing the sub-widgets directly
/// rather than mocking the full Riverpod graph.

Widget _wrapWidget(Widget child) => MaterialApp(
  theme: ThemeData.light(),
  home: Scaffold(body: child),
);

void main() {
  group('formatMetricIdForDisplay helper', () {
    test('converts snake_case to Title Case', () {
      expect(formatMetricIdForDisplay('steps'), 'Steps');
      expect(formatMetricIdForDisplay('heart_rate_resting'), 'Heart Rate Resting');
      expect(formatMetricIdForDisplay('sleep_duration'), 'Sleep Duration');
    });
  });

  group('_MetricDetailSkeleton', () {
    testWidgets('renders AppShimmer', (tester) async {
      await tester.pumpWidget(
        _wrapWidget(const MetricDetailSkeleton(metricId: 'steps')),
      );
      await tester.pump();
      expect(find.byType(AppShimmer), findsOneWidget);
    });

    testWidgets('renders without error for multi-word metricId', (tester) async {
      await tester.pumpWidget(
        _wrapWidget(
          const MetricDetailSkeleton(metricId: 'heart_rate_resting'),
        ),
      );
      await tester.pump();
      expect(find.byType(MetricDetailSkeleton), findsOneWidget);
    });
  });
}
```

> **Note on naming:** The tests reference `formatMetricIdForDisplay` and `MetricDetailSkeleton` as public names. In the implementation these will be package-private (no underscore prefix for export) OR we test them via the screen. If you prefer keeping them private, test via the screen by providing a mock `metricDetailProvider`. Either approach works — the simplest is to make the helper and skeleton widget visible to tests with public names (still in the same file).

- [ ] **Step 6.2: Run — expect FAIL**

```
flutter test test/features/data/presentation/metric_detail_screen_test.dart
```
Expected: compilation error — `formatMetricIdForDisplay` and `MetricDetailSkeleton` not exported.

- [ ] **Step 6.3: Add `_formatMetricId` helper and `_MetricDetailSkeleton` to `metric_detail_screen.dart`**

Add the helper function near the top of the file (after the `_kCoachPrefillMaxLength` constant):

```dart
// ── MetricId formatter ────────────────────────────────────────────────────────

/// Formats a snake_case [metricId] slug as human-readable Title Case.
///
/// Exposed as [formatMetricIdForDisplay] (without underscore) so widget tests
/// can assert it directly.
///
/// Examples: `"steps"` → `"Steps"`, `"heart_rate_resting"` → `"Heart Rate Resting"`.
String formatMetricIdForDisplay(String metricId) => metricId
    .split('_')
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
```

Add the skeleton widget near the bottom of the file (before the `_AskCoachButton` class):

```dart
// ── _MetricDetailSkeleton ─────────────────────────────────────────────────────

/// Layout skeleton for [MetricDetailScreen] while data is loading.
///
/// Mirrors the real screen structure: time-range chips → stats row → chart card
/// → source attribution. Animated via [AppShimmer].
///
/// Exposed without underscore prefix so widget tests can reference it directly.
class MetricDetailSkeleton extends StatelessWidget {
  const MetricDetailSkeleton({super.key, required this.metricId});

  final String metricId;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Semantics(
      label: 'Loading ${formatMetricIdForDisplay(metricId)} data',
      excludeSemantics: true,
      child: AppShimmer(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            AppDimens.bottomNavHeight + AppDimens.spaceMd,
          ),
          children: [
            // Time range selector row — 4 pill placeholders
            Row(
              children: [
                for (int i = 0; i < 4; i++) ...[
                  ShimmerBox(
                    height: 28, width: 52,
                    borderRadius: BorderRadius.circular(AppDimens.radiusChip),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                ],
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            // Stats row card
            Container(
              height: 88,
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimens.shapeMd),
              ),
              child: const ShimmerBox(
                borderRadius: BorderRadius.zero,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            // Chart card
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimens.shapeMd),
              ),
              child: const ShimmerBox(
                borderRadius: BorderRadius.zero,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            // Source attribution row
            Row(
              children: [
                ShimmerBox(height: 14, width: 14, isCircle: true),
                const SizedBox(width: AppDimens.spaceXs),
                ShimmerBox(height: 12, width: 120),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

Add import at the top of `metric_detail_screen.dart`:
```dart
import 'package:zuralog/core/widgets/shimmer.dart';
```

- [ ] **Step 6.4: Update `MetricDetailScreen.build()` to use skeleton + fix AppBar**

Locate the `ZuralogScaffold` in `MetricDetailScreen.build()` (around line 93). Replace:

```dart
return ZuralogScaffold(
  appBar: AppBar(
    title: detailAsync.when(
      data: (d) => Text(d.series.displayName, style: AppTextStyles.displaySmall),
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => Text(widget.metricId, style: AppTextStyles.displaySmall),
    ),
  ),
  body: detailAsync.when(
    loading: () => Center(
      child: CircularProgressIndicator(color: colors.primary),
    ),
    error: (e, _) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 40, color: AppColors.textTertiary),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Could not load metric',
            style:
                AppTextStyles.bodyLarge.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    ),
    data: (detail) => _MetricDetailBody(
      detail: detail,
      selectedRange: _selectedRange,
      customRange: _customRange,
      showRawTable: _showRawTable,
      onRangeChanged: (r) =>
          setState(() => _selectedRange = r),
      onCustomRangePicked: (range) => setState(() {
        _customRange = range;
        _selectedRange = TimeRange.custom;
      }),
      onToggleRawTable: () =>
          setState(() => _showRawTable = !_showRawTable),
    ),
  ),
);
```

With:

```dart
// Format metric ID immediately for AppBar — shown during loading, replaced when data arrives.
final formattedId = formatMetricIdForDisplay(widget.metricId);

return ZuralogScaffold(
  appBar: AppBar(
    title: detailAsync.when(
      data: (d) => Text(d.series.displayName, style: AppTextStyles.displaySmall),
      loading: () => Text(formattedId, style: AppTextStyles.displaySmall),
      error: (_, __) => Text(formattedId, style: AppTextStyles.displaySmall),
    ),
  ),
  body: AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    child: detailAsync.when(
      loading: () => MetricDetailSkeleton(
        key: const ValueKey('loading'),
        metricId: widget.metricId,
      ),
      error: (e, _) => _ErrorBody(
        key: const ValueKey('error'),
        onRetry: () => ref.invalidate(metricDetailProvider(params)),
      ),
      data: (detail) => _MetricDetailBody(
        key: const ValueKey('data'),
        detail: detail,
        selectedRange: _selectedRange,
        customRange: _customRange,
        showRawTable: _showRawTable,
        onRangeChanged: (r) => setState(() => _selectedRange = r),
        onCustomRangePicked: (range) => setState(() {
          _customRange = range;
          _selectedRange = TimeRange.custom;
        }),
        onToggleRawTable: () => setState(() => _showRawTable = !_showRawTable),
      ),
    ),
  ),
);
```

The `params` variable is already computed earlier in `build()` — no change needed there.

**`MetricDetailErrorBody` is defined in Task 7.** To keep the file compilable right now, add this temporary stub at the bottom of `metric_detail_screen.dart` before committing (Task 7 will replace it with the real implementation):

```dart
// STUB — replaced in Task 7
class MetricDetailErrorBody extends StatelessWidget {
  const MetricDetailErrorBody({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

- [ ] **Step 6.5: Run tests — expect PASS (skeleton + formatter tests)**

```
flutter test test/features/data/presentation/metric_detail_screen_test.dart
```
Expected: `_formatMetricId` and `_MetricDetailSkeleton` tests pass.

- [ ] **Step 6.6: Commit**

```
git add lib/features/data/presentation/metric_detail_screen.dart \
        test/features/data/presentation/metric_detail_screen_test.dart
git commit -m "feat(data): MetricDetailScreen loading skeleton + AppBar title fix"
```

---

## Task 7: `MetricDetailScreen` — Error Retry + Empty/Single Data CTAs

**Files:**
- Modify: `lib/features/data/presentation/metric_detail_screen.dart`
- Modify: `test/features/data/presentation/metric_detail_screen_test.dart`

### Background
The error state has no retry button. The 0-data and 1-data-point states are plain text with no icon or CTA. We add `_ErrorBody` widget, and replace the inline plain-text blocks inside `_MetricDetailBodyState.build()` with icon + message + "Try 30 days" CTA.

**Import note:** `TimeRange` in `metric_detail_screen.dart` is from `package:zuralog/shared/widgets/time_range_selector.dart` (values: `days7`, `days30`, `days90`, `custom`). NOT the dashboard `TimeRange` from `data/domain/time_range.dart`.

- [ ] **Step 7.1: Add error/empty tests to `metric_detail_screen_test.dart`**

```dart
group('_ErrorBody', () {
  testWidgets('renders retry button', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _wrapWidget(MetricDetailErrorBody(onRetry: () => retried = true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try Again'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('renders cloud_off icon', (tester) async {
    await tester.pumpWidget(
      _wrapWidget(MetricDetailErrorBody(onRetry: () {})),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
  });
});

group('_MetricDetailEmptyState', () {
  testWidgets('empty data: renders chart icon and Try 30 days button',
      (tester) async {
    var changed = false;
    await tester.pumpWidget(
      _wrapWidget(MetricDetailEmptyState(
        pointCount: 0,
        onExpandRange: () => changed = true,
      )),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.show_chart_rounded), findsOneWidget);
    expect(find.text('Try 30 days'), findsOneWidget);
    await tester.tap(find.text('Try 30 days'));
    await tester.pump();
    expect(changed, isTrue);
  });

  testWidgets('single data point: renders radio button icon and CTA',
      (tester) async {
    await tester.pumpWidget(
      _wrapWidget(MetricDetailEmptyState(
        pointCount: 1,
        onExpandRange: () {},
      )),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    expect(find.text('Try 30 days'), findsOneWidget);
  });
});
```

- [ ] **Step 7.2: Run — expect FAIL**

```
flutter test test/features/data/presentation/metric_detail_screen_test.dart
```
Expected: FAIL — `MetricDetailErrorBody` and `MetricDetailEmptyState` not defined.

- [ ] **Step 7.3: Add `_ErrorBody` (exported as `MetricDetailErrorBody`) to `metric_detail_screen.dart`**

Add after the `MetricDetailSkeleton` class:

```dart
// ── MetricDetailErrorBody ─────────────────────────────────────────────────────

/// Error state for [MetricDetailScreen] with a retry button.
///
/// Exposed without underscore so widget tests can reference it directly.
class MetricDetailErrorBody extends StatelessWidget {
  const MetricDetailErrorBody({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Semantics(
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                'Could not load metric',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                'Check your connection and try again.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.spaceMd),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7.4: Add `MetricDetailEmptyState` to `metric_detail_screen.dart`**

Add after `MetricDetailErrorBody`:

```dart
// ── MetricDetailEmptyState ────────────────────────────────────────────────────

/// Empty/single-data-point state inside [_MetricDetailBody].
///
/// [pointCount] == 0 → "No data for this period"
/// [pointCount] == 1 → "Only one data point available"
///
/// Both variants include a "Try 30 days" CTA via [onExpandRange].
/// Exposed without underscore for testability.
class MetricDetailEmptyState extends StatelessWidget {
  const MetricDetailEmptyState({
    super.key,
    required this.pointCount,
    required this.onExpandRange,
  });

  final int pointCount;
  final VoidCallback onExpandRange;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final isZero = pointCount == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isZero
                ? Icons.show_chart_rounded
                : Icons.radio_button_checked_rounded,
            size: isZero ? 48 : 36,
            color: colors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            isZero
                ? 'No data for this period'
                : 'Only one data point available',
            style: AppTextStyles.bodyLarge.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            isZero
                ? 'Try a different time range to see your data.'
                : 'Expand the time range to see trends.',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          OutlinedButton(
            onPressed: onExpandRange,
            child: const Text('Try 30 days'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7.5: Wire `_ErrorBody` in `MetricDetailScreen.build()`**

The `_ErrorBody(key: ..., onRetry: ...)` reference added in Task 6 now needs to use `MetricDetailErrorBody`:

```dart
error: (e, _) => MetricDetailErrorBody(
  key: const ValueKey('error'),
  onRetry: () => ref.invalidate(metricDetailProvider(params)),
),
```

- [ ] **Step 7.6: Replace inline empty/single-data text in `_MetricDetailBodyState.build()`**

Locate the section inside `_MetricDetailBodyState.build()` around line 272–293:

```dart
if (spots.length == 1) ...[
  const SizedBox(height: AppDimens.spaceLg),
  Center(
    child: Text(
      'Only one data point available',
      style: AppTextStyles.bodyLarge.copyWith(
          color: colors.textSecondary),
    ),
  ),
],

if (spots.isEmpty) ...[
  const SizedBox(height: AppDimens.spaceLg),
  Center(
    child: Text(
      'No data for this period',
      style: AppTextStyles.bodyLarge.copyWith(
          color: colors.textSecondary),
    ),
  ),
],
```

Replace with:

```dart
if (spots.length == 1)
  MetricDetailEmptyState(
    pointCount: 1,
    onExpandRange: () => widget.onRangeChanged(TimeRange.days30),
  ),

if (spots.isEmpty)
  MetricDetailEmptyState(
    pointCount: 0,
    onExpandRange: () => widget.onRangeChanged(TimeRange.days30),
  ),
```

`widget.onRangeChanged` (with `widget.` prefix) is correct because this code lives inside `_MetricDetailBodyState`.

- [ ] **Step 7.7: Run all metric detail tests**

```
flutter test test/features/data/presentation/metric_detail_screen_test.dart
```
Expected: All tests pass.

- [ ] **Step 7.8: Commit**

```
git add lib/features/data/presentation/metric_detail_screen.dart \
        test/features/data/presentation/metric_detail_screen_test.dart
git commit -m "feat(data): MetricDetailScreen error retry + empty/single-data CTAs"
```

---

## Task 8: `TileVisualizationConfig.hasChartData` + `_VizEmptyPlaceholder`

**Files:**
- Modify: `lib/features/data/domain/tile_visualization_config.dart`
- Modify: `lib/features/data/presentation/widgets/tile_visualizations.dart`
- Modify: `test/features/data/domain/tile_visualization_config_test.dart`
- Modify: `test/features/data/presentation/widgets/tile_visualizations_test.dart`

### Background
When a loaded tile's viz config has no data, the chart area silently collapses via `SizedBox.shrink()`. We add a `hasChartData` getter to the sealed class, checked in `buildTileVisualization` before dispatching. When false, a `_VizEmptyPlaceholder` icon is shown instead.

**Existing test break:** `tile_visualizations_test.dart` has:
```dart
test('returns BarChartViz for BarChartConfig', () {
  final config = BarChartConfig(bars: [], ...);  // empty bars!
  expect(widget, isA<BarChartViz>());
})
```
After our change, empty bars → `hasChartData = false` → returns `_VizEmptyPlaceholder`. This test will fail. We fix it by using non-empty bars in the dispatch test, and add a separate test for the empty-config case.

**Do NOT remove the `if (config.points.isEmpty) return SizedBox.shrink()` guards** from individual viz widgets. Those guards are now dead code in the production path (because `buildTileVisualization` never calls the widget with empty data), but they serve as a safety net for direct widget construction (e.g., in other tests). Leaving them in place is correct.

- [ ] **Step 8.1: Add `hasChartData` tests to `tile_visualization_config_test.dart`**

Add a new group at the end of the file:

```dart
group('hasChartData', () {
  test('LineChartConfig: true when points non-empty', () {
    final config = LineChartConfig(
      points: [ChartPoint(date: DateTime(2026, 3, 21), value: 60.0)],
    );
    expect(config.hasChartData, isTrue);
  });

  test('LineChartConfig: false when points empty', () {
    const config = LineChartConfig(points: []);
    expect(config.hasChartData, isFalse);
  });

  test('BarChartConfig: false when bars empty', () {
    const config = BarChartConfig(bars: []);
    expect(config.hasChartData, isFalse);
  });

  test('AreaChartConfig: false when points empty', () {
    const config = AreaChartConfig(points: []);
    expect(config.hasChartData, isFalse);
  });

  test('RingConfig: always true (value-based, not point-list)', () {
    const config = RingConfig(value: 0, maxValue: 10000, unit: 'steps');
    expect(config.hasChartData, isTrue);
  });

  test('StatCardConfig: always true', () {
    const config = StatCardConfig(value: '—', unit: '');
    expect(config.hasChartData, isTrue);
  });

  test('DualValueConfig: always true (renders values regardless of optional points)', () {
    const config = DualValueConfig(
      value1: '120', label1: 'SYS', value2: '78', label2: 'DIA',
    );
    expect(config.hasChartData, isTrue);
  });

  test('DotRowConfig: false when points empty', () {
    const config = DotRowConfig(points: []);
    expect(config.hasChartData, isFalse);
  });

  test('CalendarGridConfig: false when days empty', () {
    const config = CalendarGridConfig(days: [], totalDays: 30);
    expect(config.hasChartData, isFalse);
  });

  test('HeatmapConfig: false when cells empty', () {
    const config = HeatmapConfig(
      cells: [],
      colorLow: Color(0xFFFFFFFF),
      colorHigh: Color(0xFF000000),
      legendLabel: 'Activity',
    );
    expect(config.hasChartData, isFalse);
  });
});
```

- [ ] **Step 8.2: Run — expect FAIL**

```
flutter test test/features/data/domain/tile_visualization_config_test.dart
```
Expected: FAIL — `hasChartData` getter does not exist yet.

- [ ] **Step 8.3: Add `hasChartData` to `tile_visualization_config.dart`**

Update the sealed base class and add overrides. In the sealed class:

```dart
sealed class TileVisualizationConfig {
  const TileVisualizationConfig();

  /// Whether this config has sufficient data to render a chart.
  ///
  /// [buildTileVisualization] checks this before dispatching — returning
  /// [_VizEmptyPlaceholder] when false. Default is `true` (configs
  /// that are value-based, not point-list-based, always render).
  bool get hasChartData => true;
}
```

Override in chart-type subclasses (add after each class's existing fields):

```dart
// LineChartConfig — add after positiveIsUp field:
@override
bool get hasChartData => points.isNotEmpty;

// BarChartConfig — add after showAvgLine field:
@override
bool get hasChartData => bars.isNotEmpty;

// AreaChartConfig — add after positiveIsUp field:
@override
bool get hasChartData => points.isNotEmpty;

// DotRowConfig — add after invertedScale field:
@override
bool get hasChartData => points.isNotEmpty;

// CalendarGridConfig — add after totalDays field:
@override
bool get hasChartData => days.isNotEmpty;

// HeatmapConfig — add after legendLabel field:
@override
bool get hasChartData => cells.isNotEmpty;
```

`RingConfig`, `GaugeConfig`, `FillGaugeConfig`, `SegmentedBarConfig`, `StatCardConfig`, `DualValueConfig` keep the default `true`.

- [ ] **Step 8.4: Run config tests — expect PASS**

```
flutter test test/features/data/domain/tile_visualization_config_test.dart
```
Expected: All tests pass.

- [ ] **Step 8.5: Update `tile_visualizations_test.dart`**

Fix the broken dispatch test (currently uses empty `BarChartConfig`):

```dart
test('returns BarChartViz for BarChartConfig', () {
  // Non-empty bars required — empty bars → hasChartData=false → _VizEmptyPlaceholder
  final config = BarChartConfig(
    bars: [BarPoint(label: 'Mon', value: 8000, isToday: false)],
    showAvgLine: false,
  );
  final widget = buildTileVisualization(
    config: config,
    categoryColor: Colors.blue,
    size: TileSize.square,
  );
  expect(widget, isA<BarChartViz>());
});
```

Add a new test for the empty-config placeholder:

```dart
test('returns _VizEmptyPlaceholder for empty LineChartConfig', () {
  const config = LineChartConfig(points: []);
  final widget = buildTileVisualization(
    config: config,
    categoryColor: Colors.blue,
    size: TileSize.square,
  );
  // The exact type is private, so we check it is NOT a LineChartViz
  expect(widget, isNot(isA<LineChartViz>()));
});

test('returns _VizEmptyPlaceholder for empty BarChartConfig', () {
  const config = BarChartConfig(bars: []);
  final widget = buildTileVisualization(
    config: config,
    categoryColor: Colors.blue,
    size: TileSize.square,
  );
  expect(widget, isNot(isA<BarChartViz>()));
});
```

Add import to the test file:
```dart
import 'package:zuralog/features/data/presentation/widgets/viz/line_chart_viz.dart';
```

- [ ] **Step 8.6: Run — expect FAIL (dispatch guard not added yet)**

```
flutter test test/features/data/presentation/widgets/tile_visualizations_test.dart
```
Expected: The `'returns BarChartViz for BarChartConfig'` test now passes (non-empty bars). The new placeholder tests fail (still returns `BarChartViz` / `LineChartViz` for empty configs).

- [ ] **Step 8.7: Add `_VizEmptyPlaceholder` + guard to `tile_visualizations.dart`**

Replace the entire `buildTileVisualization` function and add the placeholder widget:

```dart
// ── _VizEmptyPlaceholder ──────────────────────────────────────────────────────

/// Shown in place of a chart when [TileVisualizationConfig.hasChartData] is
/// false — prevents silent chart-area collapse.
class _VizEmptyPlaceholder extends StatelessWidget {
  const _VizEmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Center(
      child: Icon(
        Icons.show_chart_rounded,
        size: 20,
        color: colors.textTertiary.withValues(alpha: 0.35),
      ),
    );
  }
}

// ── buildTileVisualization ────────────────────────────────────────────────────

/// Dispatches to the correct viz widget based on [config] type and [size].
///
/// Returns [_VizEmptyPlaceholder] when [config.hasChartData] is false,
/// preventing silent chart-area collapse on loaded tiles with no data.
Widget buildTileVisualization({
  required TileVisualizationConfig config,
  required Color categoryColor,
  required TileSize size,
}) {
  if (!config.hasChartData) return const _VizEmptyPlaceholder();

  return switch (config) {
    LineChartConfig()    => LineChartViz(config: config, color: categoryColor, size: size),
    BarChartConfig()     => BarChartViz(config: config, color: categoryColor, size: size),
    AreaChartConfig()    => AreaChartViz(config: config, color: categoryColor, size: size),
    RingConfig()         => RingViz(config: config, color: categoryColor, size: size),
    GaugeConfig()        => GaugeViz(config: config, color: categoryColor, size: size),
    SegmentedBarConfig() => SegmentedBarViz(config: config, color: categoryColor, size: size),
    FillGaugeConfig()    => FillGaugeViz(config: config, color: categoryColor, size: size),
    DotRowConfig()       => DotRowViz(config: config, color: categoryColor, size: size),
    CalendarGridConfig() => CalendarGridViz(config: config, color: categoryColor, size: size),
    HeatmapConfig()      => HeatmapViz(config: config, color: categoryColor, size: size),
    StatCardConfig()     => StatCardViz(config: config, color: categoryColor, size: size),
    DualValueConfig()    => DualValueViz(config: config, color: categoryColor, size: size),
  };
}
```

Add import:
```dart
import 'package:zuralog/core/theme/app_colors.dart';
```

- [ ] **Step 8.8: Run all viz and config tests — expect PASS**

```
flutter test test/features/data/domain/tile_visualization_config_test.dart test/features/data/presentation/widgets/tile_visualizations_test.dart
```
Expected: All tests pass.

- [ ] **Step 8.9: Run the full test suite to catch any regressions**

```
flutter test
```
Expected: All tests pass. If a viz widget test fails with "empty points returns the wrong type" — that test is testing the viz widget DIRECTLY (not via `buildTileVisualization`). The individual viz widget guards (`SizedBox.shrink()`) are still in place, so direct-construction tests should still pass.

- [ ] **Step 8.10: Commit**

```
git add lib/features/data/domain/tile_visualization_config.dart \
        lib/features/data/presentation/widgets/tile_visualizations.dart \
        test/features/data/domain/tile_visualization_config_test.dart \
        test/features/data/presentation/widgets/tile_visualizations_test.dart
git commit -m "feat(data): hasChartData guard + _VizEmptyPlaceholder — no more silent chart collapse"
```

---

## Final Verification

- [ ] **Run the full test suite**

```
flutter test
```
Expected: All tests pass. No regressions.

- [ ] **Verify hot-reload works**

```
flutter run
```
Navigate to Data tab, observe:
- Dashboard loading shows animated shimmer skeletons with header/value/chart structure (not blank rectangles)
- Health Score Strip loading is animated
- Syncing tiles show layout-aware shimmer (not 3 uniform bars)
- `noDataForRange` tiles show amber history icon + dimmed value
- Metric detail loading shows skeleton (not spinner); AppBar shows formatted name
- Metric detail error shows "Try Again" button
- Empty metric periods show chart icon + "Try 30 days" CTA

- [ ] **Final commit / tag**

```
git tag loading-states-complete
```

---

## What Was NOT Changed (out of scope)

- Individual viz widget `SizedBox.shrink()` guards — kept as defensive code for direct widget construction
- `GhostTileContent` — already working well; the "Connect" button is deliberately static (no animation beyond Material ink splash)
- `OnboardingEmptyState` — already the best state in the system; explicitly out of scope
- Third-party `shimmer` package — not needed; built with Flutter's `ShaderMask`
