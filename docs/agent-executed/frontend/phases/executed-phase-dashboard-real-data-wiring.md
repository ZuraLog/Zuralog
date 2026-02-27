# Executed Phase: Dashboard Real Data Wiring

**Branch:** `feat/dashboard-real-data-wiring`
**Merged:** 2026-02-28
**Plan file:** `.opencode/plans/2026-02-27-dashboard-real-data-wiring.md`

---

## Summary

Replaced all mock/fake data in the Zuralog Flutter dashboard with real health data queried from HealthKit (iOS) / Health Connect (Android), with Cloud Brain API as fallback. All 117 metrics are wired. Metrics with no available data render in a visually dimmed "empty state." Tapping a no-data metric navigates to the Integrations tab with a contextual banner.

---

## What Was Actually Built

### 1. `RealMetricDataRepository` (new file)
- Native-first data strategy: reads from `HealthRepository` (HealthKit/Health Connect) first, with a 5-second timeout per call (`_readNativeWithTimeout` using `Future.any`).
- Cloud Brain fallback via `AnalyticsRepository` for the four Cloud-supported metrics: steps, calories, sleep, weight.
- Covers all 117 registered metrics. Unsupported metrics naturally return an empty `MetricSeries` (zero data points).
- `getTodaySnapshots` returns a `Map<String, double>` of metric ID → today's value; absent = no data.
- `getMetricSeries` constructs 7-day or 30-day `MetricSeries` with correct `MetricStats` (min/max/average/total).

### 2. Provider wiring (`metric_series_provider.dart`)
- `metricDataRepositoryProvider` now resolves to `RealMetricDataRepository` (was `MetricDataRepository` mock).
- `metricSeriesProvider` and `categorySnapshotProvider` unchanged in structure; now powered by real data.
- Original `MetricDataRepository` mock is preserved (not deleted) for test provider overrides.

### 3. Category cards — empty-state design (`category_card.dart`)
- Added `hasData: bool = true` field to `MetricPreview`.
- `CategoryCard.build` sorts previews: data-present first, no-data last (within the 4-preview limit).
- `_MetricPreviewRow` renders a dimmed row at **38% opacity** with a `'—'` value and an `Icons.add_circle_outline_rounded` trailing icon when `hasData == false`.

### 4. Dashboard screen — empty states & navigation (`dashboard_screen.dart`)
- `_CategoryCardLoader._dataPreviews`: metrics absent from the real snapshot get `hasData: false`.
- `_EssentialStatTile`: detects `series.dataPoints.isEmpty` after load completes; renders the tile at **45% opacity** with a grey badge, `'—'` value, and `+` icon. Tapping navigates to Integrations with context.
- `_CategoryCardLoader` data handler: when all previews are `hasData: false`, wraps `CategoryCard` in `Opacity(0.45)`, hides the mini graph, and routes tap to Integrations.
- Added `_navigateToIntegrationsWithContext(context, ref, metricLabel)` helper.

### 5. Integration context banner
- Created `integration_context_provider.dart` — `StateProvider<String?>` holding the contextual banner label.
- `IntegrationsHubScreen`: renders a dismissible banner below the search bar when the provider has a non-null value. Auto-clears after 10 seconds via `initState` timer. Manually dismissible with an `×` button.

### 6. Unit tests (`real_metric_data_repository_test.dart`)
- 5 tests, no generated mocks (manual stubs: `_ZeroHealthBridge`, `_UnavailableApiClient`).
- Covers: unknown metric ID → empty series, zeroed stats, zero steps → no data point, empty snapshots for zeroed/null reads, empty snapshots for completely unknown metric IDs.

---

## Deviations from the Original Plan

| Plan Assumption | Actual Reality | Resolution |
|---|---|---|
| `getFlightsClimbed(date)` | `getFlights(date)` | Used correct method name |
| `getHeartRate(start, end)` → `List` | `getHeartRate()` → `double?` (single value) | Adapted to single-value read |
| `getBloodPressure(start, end)` → `List` | `getBloodPressure()` → `Map<String, dynamic>?` | Adapted; extracts `systolic`/`diastolic` |
| `getDistance()` → `double?` | `getDistance(DateTime)` → `double` (non-nullable) | Handled 0.0 as "no data" |
| `WeeklyTrends.dates: List<DateTime>` | `List<String>` (ISO-8601) | Used `DateTime.parse()` in converter |
| Test `_UnavailableApiClient.get` returned `Future<dynamic>` | Must return `Future<Response<dynamic>>` | Fixed; added `dio` import to test |
| Pull-to-refresh needed explicit wiring (Tasks 8–9) | Already functional via Riverpod provider invalidation | No code changes needed |
| Timeout resilience needed separate task (Task 9) | Already implemented in Task 1 via `_readNativeWithTimeout` | No code changes needed |

---

## Verification Results

- `flutter analyze`: **0 issues**
- Unit tests: **5/5 passed**
- Branch merged to `main` with `--no-ff`

---

## Next Steps

The dashboard now has a complete real-data pipeline. Future work could include:

- **iOS/Android device testing**: Verify HealthKit/Health Connect permissions prompt correctly and data flows end-to-end on a real device.
- **Richer Cloud Brain coverage**: Expand `AnalyticsRepository` to serve more than the 4 currently supported metrics.
- **Caching layer**: Add a short-lived cache (e.g., 5-minute TTL) in `RealMetricDataRepository` to avoid redundant native reads on rapid UI refreshes.
- **Metric-specific granularity**: Current weekly trends use simple daily aggregation; hourly granularity could be added for intraday metrics (heart rate, blood pressure).
