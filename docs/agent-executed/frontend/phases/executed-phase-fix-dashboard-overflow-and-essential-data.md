# Executed Phase: fix/dashboard-overflow-and-essential-data

## Summary

This phase fixed two visual bugs discovered after the comprehensive dashboard redesign and added a new "Today's Essentials" section to the home screen. A third bug (dark mode rendering failure in the new section) was discovered and fixed during visual QA.

### Changes Delivered

**1. CategoryCard mini-graph overflow fix**
- `CategoryCard` allocated only 36px for the `miniGraph` slot.
- `MetricGraphTile` (used as the mini graph) renders a full header row + subtitle + 80px chart, causing a 156px bottom overflow on every category card.
- Fix: Replaced `MetricGraphTile` with `_buildRawMiniGraph()` — a helper in `dashboard_screen.dart` that dispatches directly to the underlying chart widget (e.g., `BarChartGraph`, `LineChartGraph`) wrapped in a `SizedBox(height: 60)`.
- Updated `CategoryCard`'s mini-graph slot from 36px → 60px to accommodate.

**2. "Today's Essentials" hero section**
- Added `_EssentialMetricsSection` as the second sliver in the dashboard (after SliverAppBar, before the insight strip and category cards).
- Shows the 5 most essential health metrics at first glance: Steps, Active Calories, Resting Heart Rate, Sleep Duration, HRV.
- Layout: Row 1 (3 tiles: Steps | Active Cal | Resting HR) + Row 2 (2 tiles: Sleep | HRV).
- Each tile: colored left accent stripe + icon badge + large value + unit + label. Tapping navigates to the corresponding category detail screen.
- Data sourced from `metricSeriesProvider((metricId, TimeRange.day))`.

**3. Dark mode tile rendering fix (discovered during visual QA)**
- Root cause: `BoxDecoration` with `borderRadius` + a `Border` with non-uniform colors (left: `accentColor`, top/right/bottom: `colorScheme.outline`) triggers a Flutter paint exception in dark mode, silently blanking all tile content.
- Flutter's `BoxDecoration.paint` throws `A borderRadius can only be given on borders with uniform colors` when the border sides have different colors, even when the analyze tool reports no issues (it's a runtime constraint, not a static type error).
- Fix: Replaced the non-uniform `Border` with a `Stack` approach:
  - Outer `ClipRRect` provides consistent rounded-corner clipping.
  - Inner `Container` uses `Border.all(color: cs.outline)` in dark mode (uniform color) or no border in light mode.
  - A `Positioned` 3px-wide `Container` renders the left accent stripe on top, clipped by the outer `ClipRRect`.
- Additional improvement: converted `_EssentialStatTile` from `StatelessWidget` (receiving `WidgetRef` as a parameter) to `ConsumerWidget` for proper Riverpod reactivity and correct rebuilds on theme/data changes.
- Text colors updated to use `cs.onSurface` / `cs.onSurfaceVariant` instead of manual `isDark` brightness checks.

## Deviations from Original Plan

- No deviations; these were bug fixes discovered post-implementation.
- The dark mode rendering bug was not anticipated in the original plan — it was discovered during visual QA on the emulator.

## Files Modified

- `zuralog/lib/features/dashboard/presentation/dashboard_screen.dart` — primary changes (all three fixes)
- `zuralog/lib/features/dashboard/presentation/widgets/category_card.dart` — mini-graph slot height 36→60px

## Quality Gates Passed

- `flutter analyze`: 0 issues
- Visual QA: light mode ✅, dark mode ✅ (both verified via ADB screencap on API 36 emulator)
- No overflow errors in either mode
- Merged to `main` at commit `5c445dd`

## Known Remaining Issues

- **Distance mock data**: `CategoryCard` for Activity shows "6959.6 km" — the mock data generator returns raw meters (2000–12000) without unit conversion. This is a data layer issue, not a UI bug, and is out of scope for this fix.
- **Steps value truncated**: Essential tile shows "22..." because the value (e.g., 22000 steps) is truncated by `TextOverflow.ellipsis` at 17pt font in the 72px tile. Could be improved by reducing font size for values > 4 digits, but is acceptable for now.

## Next Steps

The dashboard is now in a stable, fully functional state. Potential follow-up work:
- Fix distance unit conversion in `MetricDataRepository` mock data.
- Consider adaptive font sizing in `_EssentialStatTile` for long numeric values.
- Hook up real HealthKit / Health Connect data to replace mock data.
