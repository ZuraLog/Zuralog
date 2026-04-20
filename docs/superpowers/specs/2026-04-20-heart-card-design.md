# Heart Section Design
**Date:** 2026-04-20
**Status:** Approved — proceed to implementation planning
**Scope:** Full Heart section — Today tab card wired to real data, detail screen, All-Data screen, backend endpoints

---

## 1. What We Are Building

The Heart section is the third complete health section in ZuraLog, following Sleep and Nutrition. It surfaces cardiovascular health data from HealthKit (iOS) and Health Connect (Android). It follows the identical three-screen framework defined in `docs/superpowers/specs/2026-04-20-health-sections-framework-design.md`.

**Three screens:**
1. `HeartPillarCard` on the Today tab — already exists as a hardwired widget, needs to be connected to real provider data
2. `HeartDetailScreen` — reached by tapping the pillar card; shows today's hero metrics, trend charts, and AI summary
3. `HeartAllDataScreen` — reached from the detail screen via "View All Data →"; shows all 8 metrics across extended time ranges

---

## 2. Data & Metrics

### Source table

All heart metrics are read from `daily_summaries`. Every metric listed below is already registered in `metric_definitions` with its aggregation rule. No new database tables or migrations are required — data flows in through the existing unified ingest pipeline (`POST /api/v1/ingest/bulk` → `aggregation_service` → `daily_summaries`).

### The 8 metrics

| Display label | `metric_type` key | Unit | Aggregation | DB category |
|---|---|---|---|---|
| Resting HR | `resting_heart_rate` | bpm | avg | heart |
| HRV | `hrv_ms` | ms | avg | heart |
| Avg Heart Rate | `heart_rate_avg` | bpm | avg | heart |
| Respiratory Rate | `respiratory_rate` | brpm | avg | heart |
| VO2 Max | `vo2_max` | mL/kg/min | latest | heart |
| Blood Oxygen | `spo2` | % | avg | vitals |
| Blood Pressure (Sys) | `blood_pressure_systolic` | mmHg | avg | vitals |
| Blood Pressure (Dia) | `blood_pressure_diastolic` | mmHg | avg | vitals |

SpO2 and blood pressure are categorized as `vitals` in `metric_definitions`, but the Heart routes query by `metric_type` key directly — the category field is irrelevant to these routes.

### Blood pressure handling

Blood pressure is always a pair (systolic + diastolic). In the All-Data screen, it occupies one tab labeled "Blood Pressure" that renders two lines on a single chart. This requires a small extension to `AllDataMetricTab` (see Flutter section). Both values live in the `daily_summaries` table and are returned as separate keys in the backend response (`bp_systolic` and `bp_diastolic`).

---

## 3. Backend — `cloud-brain/app/api/v1/heart_routes.py`

New file. Mirrors `sleep_routes.py` exactly in structure and rate limits.

### Constants

```python
_HEART_METRIC_TYPES = [
    "resting_heart_rate",
    "hrv_ms",
    "heart_rate_avg",
    "respiratory_rate",
    "vo2_max",
    "spo2",
    "blood_pressure_systolic",
    "blood_pressure_diastolic",
]

_METRIC_TO_ALL_DATA_KEY: dict[str, str] = {
    "resting_heart_rate":      "resting_hr",
    "hrv_ms":                  "hrv",
    "heart_rate_avg":          "avg_hr",
    "respiratory_rate":        "respiratory_rate",
    "vo2_max":                 "vo2_max",
    "spo2":                    "spo2",
    "blood_pressure_systolic": "bp_systolic",
    "blood_pressure_diastolic":"bp_diastolic",
}

_ALL_DATA_RANGE_DAYS: dict[str, int] = {
    "7d": 7, "30d": 30, "3m": 90, "6m": 180, "1y": 365,
}

_SOURCE_DISPLAY: dict[str, tuple[str, str]] = {
    "oura":           ("Oura Ring",      "#EC4899"),
    "fitbit":         ("Fitbit",         "#00B0B9"),
    "polar":          ("Polar",          "#D10019"),
    "withings":       ("Withings",       "#00B5AD"),
    "apple_health":   ("Apple Health",   "#FF375F"),
    "health_connect": ("Health Connect", "#4CAF50"),
    "manual":         ("Manual",         "#5E5CE6"),
}
```

### `GET /api/v1/heart/summary` — rate limit: 120/minute

Returns today's heart metrics for the authenticated user, plus an AI summary from the `insights` table.

**Response schema:**

```python
class HeartSource(BaseModel):
    name: str
    icon: str
    brand_color: str

class HeartSummaryResponse(BaseModel):
    has_data: bool
    resting_hr: float | None           # bpm
    hrv_ms: float | None               # ms
    avg_hr: float | None               # bpm
    respiratory_rate: float | None     # brpm
    vo2_max: float | None              # mL/kg/min
    spo2: float | None                 # %
    bp_systolic: float | None          # mmHg
    bp_diastolic: float | None         # mmHg
    resting_hr_vs_7day: float | None   # bpm delta vs 7-day avg (positive = higher than avg)
    hrv_vs_7day: float | None          # ms delta vs 7-day avg
    ai_summary: str | None
    ai_generated_at: str | None
    sources: list[HeartSource]
```

**Logic:**
1. `get_user_local_date(db, user_id)` for today's date (never trust client)
2. Query `DailySummary` where `metric_type.in_(_HEART_METRIC_TYPES)` and `date == local_date` and `is_stale == False`
3. Compute `resting_hr_vs_7day` by querying the 7-day average of `resting_heart_rate` from `DailySummary` (same pattern as `avg_vs_7day_minutes` in sleep)
4. Compute `hrv_vs_7day` from 7-day average of `hrv_ms`
5. Query `Insight` table where `type == "heart_summary"` and `generation_date == local_date` and `dismissed_at IS NULL`, order by `priority ASC`, limit 1
6. Query `HealthEvent.source` (distinct) where `local_date == local_date` and `metric_type.in_(_HEART_METRIC_TYPES)` and `deleted_at IS NULL` for source attribution

### `GET /api/v1/heart/trend?range=7d|30d` — rate limit: 120/minute

Powers the two trend line charts on the detail screen (Resting HR + HRV).

**Response schema:**

```python
class HeartTrendDay(BaseModel):
    date: str
    resting_hr: float | None
    hrv_ms: float | None
    is_today: bool

class HeartTrendResponse(BaseModel):
    range: str
    days: list[HeartTrendDay]
```

**Logic:** Query `DailySummary` where `metric_type.in_(["resting_heart_rate", "hrv_ms"])` for the requested range. Build one `HeartTrendDay` per date found. Days with no data are omitted.

### `GET /api/v1/heart/all-data?range=7d|30d|3m|6m|1y` — rate limit: 60/minute

Powers the All-Data screen. Returns one row per day that has any heart data, with all 8 metrics.

**Response schema:**

```python
class HeartAllDataDayValues(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    resting_hr: float | None = None
    hrv: float | None = None
    avg_hr: float | None = None
    respiratory_rate: float | None = None
    vo2_max: float | None = None
    spo2: float | None = None
    bp_systolic: float | None = None
    bp_diastolic: float | None = None

class HeartAllDataDay(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    date: str
    is_today: bool = False
    values: HeartAllDataDayValues

class HeartAllDataResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    days: list[HeartAllDataDay]
```

**Logic:** Same pattern as `GET /api/v1/sleep/all-data`. Query `DailySummary` for `metric_type.in_(_METRIC_TO_ALL_DATA_KEY.keys())` over the requested date range. Group by date, map metric keys using `_METRIC_TO_ALL_DATA_KEY`, build one `HeartAllDataDay` per date.

### Router registration

Add `from app.api.v1.heart_routes import router as heart_router` and `app.include_router(heart_router, prefix="/api/v1")` in `cloud-brain/app/main.py` (same pattern as `sleep_routes` and `nutrition_routes`).

---

## 4. Flutter Architecture

Mirrors `zuralog/lib/features/sleep/` exactly. New feature folder: `zuralog/lib/features/heart/`.

### 4.1 Domain — `domain/heart_models.dart`

```dart
class HeartSource { name, icon, brandColor }

class HeartDaySummary {
  final bool hasData;
  final double? restingHr;       // bpm
  final double? hrvMs;           // ms
  final double? avgHr;           // bpm
  final double? respiratoryRate; // brpm
  final double? vo2Max;          // mL/kg/min
  final double? spo2;            // %
  final double? bpSystolic;      // mmHg
  final double? bpDiastolic;     // mmHg
  final double? restingHrVs7Day; // bpm delta
  final double? hrvVs7Day;       // ms delta
  final String? aiSummary;
  final DateTime? aiGeneratedAt;
  final List<HeartSource> sources;

  static const HeartDaySummary empty = HeartDaySummary(hasData: false);
  factory HeartDaySummary.fromJson(Map<String, dynamic> json)
}

class HeartTrendDay {
  final String date;
  final double? restingHr;
  final double? hrvMs;
  final bool isToday;

  factory HeartTrendDay.fromJson(Map<String, dynamic> json)
}
```

### 4.2 Data layer

**`data/heart_repository_interface.dart`**
```dart
abstract interface class HeartRepositoryInterface {
  Future<HeartDaySummary> getHeartSummary();
  Future<List<HeartTrendDay>> getHeartTrend(String range);
  Future<List<AllDataDay>> getHeartAllData(String range);
}
```

**`data/api_heart_repository.dart`**
- `getHeartSummary()` → `GET /api/v1/heart/summary`
- `getHeartTrend(range)` → `GET /api/v1/heart/trend?range={range}` → parses `response.data['days']`
- `getHeartAllData(range)` → `GET /api/v1/heart/all-data?range={range}` → maps `response.data['days']` to `List<AllDataDay>` using the values dict keys (`resting_hr`, `hrv`, `avg_hr`, `respiratory_rate`, `vo2_max`, `spo2`, `bp_systolic`, `bp_diastolic`)

**`data/mock_heart_repository.dart`**

Mock data values (based on realistic wearable readings consistent with seed_demo_data.py):

```dart
// getHeartSummary() returns:
HeartDaySummary(
  hasData: true,
  restingHr: 62.0,
  hrvMs: 48.0,
  avgHr: 74.0,
  respiratoryRate: 14.2,
  vo2Max: 41.5,
  spo2: 97.8,
  bpSystolic: 118.0,
  bpDiastolic: 76.0,
  restingHrVs7Day: -3.0,   // 3 bpm below 7-day avg (trending down = good)
  hrvVs7Day: 4.0,           // 4 ms above 7-day avg (trending up = good)
  aiSummary: 'Your resting heart rate dropped 3 bpm below your weekly average — '
             'a strong sign your cardiovascular system is recovering well. '
             'HRV is also up 4 ms, which suggests yesterday\'s rest day paid off.',
  aiGeneratedAt: DateTime(2026, 4, 20, 5, 0),
  sources: [HeartSource(name: 'Apple Health', icon: 'apple_health', brandColor: '#FF375F')],
)

// getHeartTrend(range) returns 7 days:
// dates: 2026-04-14 through 2026-04-20
// resting_hr: [66, 65, 63, 67, 64, 62, 62]
// hrv_ms:     [42, 44, 46, 40, 45, 48, 48]
// is_today: last entry only

// getHeartAllData(range) returns up to 30 days of AllDataDay entries:
// Each day has all 8 metric keys in its values map.
// Simulate realistic variation using seed-based arithmetic (same pattern as MockSleepRepository).
// today has null values for most metrics (data not yet synced today).
```

### 4.3 Providers — `providers/heart_providers.dart`

```dart
const _useMock = bool.fromEnvironment('USE_MOCK_DATA', defaultValue: false);

final heartRepositoryProvider = Provider<HeartRepositoryInterface>((ref) {
  if (_useMock) return MockHeartRepository();
  return ApiHeartRepository(apiClient: ref.read(apiClientProvider));
});

final heartDaySummaryProvider = FutureProvider<HeartDaySummary>((ref) async {
  try {
    return await ref.read(heartRepositoryProvider).getHeartSummary();
  } catch (_) {
    return HeartDaySummary.empty;
  }
});

final heartTrendProvider =
    FutureProvider.family<List<HeartTrendDay>, String>((ref, range) async {
  try {
    return await ref.read(heartRepositoryProvider).getHeartTrend(range);
  } catch (_) {
    return const [];
  }
});
```

---

## 5. Flutter Screens & Widgets

### 5.1 Shared infrastructure change — `AllDataMetricTab` dual-line support

To support the Blood Pressure tab (two lines on one chart), add two optional fields to `AllDataMetricTab` in `zuralog/lib/shared/all_data/all_data_models.dart`:

```dart
class AllDataMetricTab {
  // existing fields unchanged ...

  // NEW — optional second data series for dual-line charts (e.g. blood pressure)
  final double? Function(AllDataDay day)? secondaryValueExtractor;
  final String? secondaryLabel; // e.g. 'Diastolic'
}
```

`AllDataScreen` renders a second line on the chart when `secondaryValueExtractor` is non-null. All existing tabs are unaffected (both new fields default to null).

### 5.2 `HeartAllDataScreen` — `presentation/all_data/heart_all_data_screen.dart`

Mirrors `SleepAllDataScreen`. Constructs an `AllDataSectionConfig` and passes it to `AllDataScreen`.

**7 tabs in display order:**

| Tab label | id key | Chart type | Unit | Secondary extractor | Empty state |
|---|---|---|---|---|---|
| Resting HR | `resting_hr` | line | bpm | — | Connect a wearable |
| HRV | `hrv` | line | ms | — | Connect a wearable |
| Avg HR | `avg_hr` | line | bpm | — | Connect a wearable |
| Resp. Rate | `respiratory_rate` | line | brpm | — | Connect a wearable |
| VO2 Max | `vo2_max` | line | mL/kg/min | — | Connect a wearable |
| SpO2 | `spo2` | line | % | — | Connect a wearable |
| Blood Pressure | `bp_systolic` | line | mmHg | `bp_diastolic` / "Diastolic" | Connect a source |

All heart metrics are continuous measurements — every tab uses `AllDataChartType.line`.

### 5.3 Detail screen widget stack — `presentation/heart_detail_screen.dart`

Mirrors `SleepDetailScreen`. Uses `CustomScrollView` with `SliverAppBar` (title: 'Heart', pinned) and a single `SliverToBoxAdapter` containing a `ZStaggeredList` with this order:

1. `HeartHeroCard(summary: summary)` — always shown
2. `HeartAiSummaryCard(aiSummary: summary.aiSummary, generatedAt: summary.aiGeneratedAt)`
3. `HeartTrendSection()` — two charts: Resting HR (line) + HRV (line), each with 7d/30d toggle
4. "View All Data →" row — same pattern as `SleepDetailScreen`: label + `ZProBadge(showLock: true)` + arrow icon, taps to `context.pushNamed(RouteNames.heartAllData)`
5. `SizedBox(height: AppDimens.spaceLg)`

No section-specific middle blocks between the hero and AI summary (unlike Sleep which has stage breakdown and sleeping HR). All detailed per-metric data lives in All-Data.

### 5.4 `HeartHeroCard` — `presentation/widgets/heart_hero_card.dart`

Uses `ZuralogCard(variant: ZCardVariant.hero, category: AppColors.categoryHeart)`.

**Data state — hero layout (Option C: both RHR and HRV as co-equal headline pair):**

```
┌─────────────────────────────────────────────────────────┐
│  Heart                                          [source] │
│                                                          │
│  62 bpm           48 ms                                  │
│  Resting HR       HRV                                    │
│                                                          │
│  ↓ 3 bpm vs avg   ↑ 4 ms vs avg                         │
└─────────────────────────────────────────────────────────┘
```

- Both `restingHr` and `hrvMs` displayed at `AppTextStyles.displayLarge` (same as sleep duration)
- Their unit + label in `AppTextStyles.labelSmall` + `colors.textSecondary` below each number
- `restingHrVs7Day` and `hrvVs7Day` shown as directional delta rows (↑ green / ↓ red) using the same `_VsAvgRow` visual pattern from `SleepHeroCard`
- Source attribution chips below, same `_SourceChip` pattern from `SleepHeroCard`

**Empty state:**
```
No heart data yet
Connect a wearable or use Apple Health / Health Connect
to see your heart metrics here.
[Connect wearable]
```

Single CTA chip: "Connect wearable" → `context.pushNamed(RouteNames.settingsIntegrations)`.

### 5.5 `HeartAiSummaryCard` — `presentation/widgets/heart_ai_summary_card.dart`

Identical structure to `SleepAiSummaryCard`. Category color: `AppColors.categoryHeart`.

### 5.6 `HeartTrendSection` — `presentation/widgets/heart_trend_section.dart`

Identical structure to `SleepTrendSection`. Two charts:
- Chart 1: Resting Heart Rate (line, `restingHr` field from `HeartTrendDay`)
- Chart 2: HRV (line, `hrvMs` field from `HeartTrendDay`)

Each chart has an independent 7d/30d toggle. Reads from `heartTrendProvider`.

---

## 6. Today Tab — Wiring `HeartPillarCard`

The `HeartPillarCard` at `zuralog/lib/features/today/presentation/widgets/heart_pillar_card.dart` currently shows hardwired data with a `TODO(backend)` comment.

**Changes:**
1. `HeartPillarCard` accepts `HeartDaySummary summary` as a parameter (replacing hardwired values)
2. Reads `restingHr`, `hrvMs`, and `restingHrVs7Day` from the summary to populate `ZPillarCard` props
3. `TodayFeedScreen` reads `heartDaySummaryProvider` and passes the result to `HeartPillarCard`
4. `HeartPillarCard` onTap wires to `context.pushNamed(RouteNames.heart)` in `today_feed_screen.dart`

**Pillar card data mapping:**
- `headline`: `summary.restingHr?.round().toString() ?? '–'`
- `headlineUnit`: `'bpm'`
- `contextStat`: `'Resting'`
- `secondaryStats`:
  - `PillarStat(label: 'HRV', value: summary.hrvMs != null ? '${summary.hrvMs!.round()} ms' : '–')`
  - `PillarStat(label: 'vs avg', value: ...)` — formatted delta from `restingHrVs7Day`
- Empty state: if `!summary.hasData`, pillar card shows `'–'` headline and empty secondary stats

---

## 7. Routing Changes

### `route_names.dart` — add 4 constants

```dart
// ── Heart Detail (pushed over shell) ──────────────────────────────────────────
static const String heart     = 'heart';
static const String heartPath = '/heart';

// ── Heart All-Data ────────────────────────────────────────────────────────────
static const String heartAllData     = 'heartAllData';
static const String heartAllDataPath = '/heart/all-data';
```

Also update the route tree comment at the top of the file to include:
```
/// /heart                          → HeartDetailScreen (pushed over shell)
///   /heart/all-data               → HeartAllDataScreen
```

### `app_router.dart` — add GoRoute

Add alongside the existing `/sleep` GoRoute (outside the StatefulShellRoute, pushed over the shell):

```dart
// ── Heart Detail (pushed over shell) ─────────────────────────────────────────
import 'package:zuralog/features/heart/presentation/heart_detail_screen.dart';
import 'package:zuralog/features/heart/presentation/all_data/heart_all_data_screen.dart';

GoRoute(
  path: RouteNames.heartPath,
  name: RouteNames.heart,
  pageBuilder: (context, state) => const MaterialPage(
    child: SentryErrorBoundary(
      module: 'heart.detail',
      child: HeartDetailScreen(),
    ),
  ),
  routes: [
    GoRoute(
      path: 'all-data',
      name: RouteNames.heartAllData,
      builder: (context, state) => const SentryErrorBoundary(
        module: 'heart.all_data',
        child: HeartAllDataScreen(),
      ),
    ),
  ],
),
```

---

## 8. What Is Out of Scope

- Blood pressure manual logging — Heart reads from synced wearable/device data only
- Real-time HR monitoring or intraday HR curves — those require HealthEvent queries, not DailySummary
- ECG data — no metric definition exists for this yet
- Cross-metric correlations (e.g. "HRV vs sleep") — that is the Trends tab
- Heart rate zones (zone 1–5) — that is the Fitness/Activity section

---

## 9. File Checklist

**New files — backend:**
- `cloud-brain/app/api/v1/heart_routes.py`

**Modified files — backend:**
- `cloud-brain/app/main.py` — register heart router

**New files — Flutter:**
- `zuralog/lib/features/heart/domain/heart_models.dart`
- `zuralog/lib/features/heart/data/heart_repository_interface.dart`
- `zuralog/lib/features/heart/data/api_heart_repository.dart`
- `zuralog/lib/features/heart/data/mock_heart_repository.dart`
- `zuralog/lib/features/heart/providers/heart_providers.dart`
- `zuralog/lib/features/heart/presentation/heart_detail_screen.dart`
- `zuralog/lib/features/heart/presentation/widgets/heart_hero_card.dart`
- `zuralog/lib/features/heart/presentation/widgets/heart_ai_summary_card.dart`
- `zuralog/lib/features/heart/presentation/widgets/heart_trend_section.dart`
- `zuralog/lib/features/heart/presentation/all_data/heart_all_data_screen.dart`

**Modified files — Flutter:**
- `zuralog/lib/shared/all_data/all_data_models.dart` — add `secondaryValueExtractor` + `secondaryLabel` to `AllDataMetricTab`
- `zuralog/lib/shared/all_data/all_data_screen.dart` — render second line when `secondaryValueExtractor` is present
- `zuralog/lib/features/today/presentation/widgets/heart_pillar_card.dart` — accept real summary, remove hardwired data
- `zuralog/lib/features/today/presentation/today_feed_screen.dart` — read `heartDaySummaryProvider`, pass to `HeartPillarCard`, wire onTap to `RouteNames.heart`
- `zuralog/lib/core/router/route_names.dart` — add heart + heartAllData constants
- `zuralog/lib/core/router/app_router.dart` — add heart GoRoute with all-data child
