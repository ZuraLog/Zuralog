# Today Tab Part 5 — Inline Log Panels Implementation Plan

> **For agentic workers:** REQUIRED: Use `superpowers:subagent-driven-development` (if subagents available) or `superpowers:executing-plans` to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the four inline log panels (Water, Wellness, Weight, Steps) to the real API — adding missing repository methods, a new `GET /api/v1/quick-log/latest` backend endpoint, a `latestLogValuesProvider` Flutter provider, unit awareness in the Water panel, pre-fill + delta in the Weight panel, a real sync banner in the Steps panel, and proper error handling throughout.

**Architecture:** The Cloud Brain is the single source of truth for all metric values — it already deduplicates data ingested from Apple Health, Health Connect, Strava, and manual entries. Panels read pre-fill data from a new `GET /api/v1/quick-log/latest` endpoint (Cloud Brain), never from the native health bridge directly. All four save paths call typed POST endpoints that already exist on the backend; the only Flutter-side gap is three missing repository methods (`logWater`, `logWellness`, `logWeight`) and the wiring inside `_PanelView`. Error handling follows the existing steps panel pattern: on failure the sheet stays open and a snackbar is shown; `todayLogSummaryProvider` is never invalidated on failure.

**Tech Stack:** Flutter 3 / Dart, Riverpod, FastAPI / SQLAlchemy async, Python 3.12, pytest, flutter test

---

## File Map

### Backend (Cloud Brain)

| Action | File |
|--------|------|
| Modify | `cloud-brain/app/api/v1/quick_log_routes.py` — add `GET /quick-log/latest` endpoint and `LatestLogResponse` Pydantic schema |
| Modify | `cloud-brain/tests/api/v1/test_quick_log_routes.py` — add tests for the new endpoint |

### Flutter — repository layer

| Action | File |
|--------|------|
| Modify | `zuralog/lib/features/today/data/today_repository.dart` — add `logWater`, `logWellness`, `logWeight`, `getLatestLogValues` to interface and implementation |
| Modify | `zuralog/lib/features/today/data/mock_today_repository.dart` — stub the four new methods |

### Flutter — provider layer

| Action | File |
|--------|------|
| Modify | `zuralog/lib/features/today/providers/today_providers.dart` — add `latestLogValuesProvider` |

### Flutter — panels

| Action | File |
|--------|------|
| Modify | `zuralog/lib/shared/widgets/log_panels/z_water_log_panel.dart` — unit awareness (oz/ml), real `logWater` call |
| Modify | `zuralog/lib/shared/widgets/log_panels/z_wellness_log_panel.dart` — real `logWellness` call, error handling |
| Modify | `zuralog/lib/shared/widgets/log_panels/z_weight_log_panel.dart` — pre-fill from `latestLogValuesProvider`, delta indicator, last-unit persistence, real `logWeight` call |
| Modify | `zuralog/lib/shared/widgets/log_panels/z_steps_log_panel.dart` — real sync banner from `latestLogValuesProvider`, goal display from `dailyGoalsProvider`, "Confirm Steps" label |

### Flutter — sheet wiring

| Action | File |
|--------|------|
| Modify | `zuralog/lib/shared/widgets/sheets/z_log_grid_sheet.dart` — wire `onSave` callbacks for water, wellness, weight to real repository calls with error handling |

### Flutter — tests

| Action | File |
|--------|------|
| Modify | `zuralog/test/features/today/providers/today_log_summary_provider_test.dart` — add `latestLogValuesProvider` tests |
| Create | `zuralog/test/shared/widgets/log_panels/z_water_log_panel_test.dart` |
| Create | `zuralog/test/shared/widgets/log_panels/z_wellness_log_panel_test.dart` |
| Create | `zuralog/test/shared/widgets/log_panels/z_weight_log_panel_test.dart` |
| Create | `zuralog/test/shared/widgets/log_panels/z_steps_log_panel_test.dart` |

---

## Chunk 1 — Backend: `GET /quick-log/latest` endpoint

### Task 1: Add the `GET /quick-log/latest` endpoint to `quick_log_routes.py`

**Files:**
- Modify: `cloud-brain/app/api/v1/quick_log_routes.py`

The endpoint accepts an optional `types` query param (comma-separated metric type strings, e.g. `?types=weight,steps`). It queries the `quick_logs` table for the most recent row per requested type for the authenticated user (across all time, not just today). Returns a dict keyed by type.

Response shape example:
```json
{
  "weight": { "value_kg": 78.4, "logged_at": "2026-03-15T08:22:00Z", "source": "apple_health" },
  "steps":  { "steps": 9420, "logged_at": "2026-03-16T11:00:00Z", "source": "health_connect" }
}
```

- `weight` entry: `value_kg` from `log.value`, `logged_at` from `log.logged_at`, `source` from `log.data.get('source', 'manual')`.
- `steps` entry: `steps` as int from `log.value`, `logged_at`, `source` from `log.data.get('source', 'manual')`.
- If a type has never been logged, it is absent from the response — no null keys.
- If `types` query param is absent or empty, return an empty dict (do not return all types — that would be an unbounded query).
- Validate each requested type against `VALID_METRIC_TYPES`; return 422 for any unknown type.
- Rate limit: 60/minute per user.

- [ ] **Step 1.1: Write failing tests first**

In `cloud-brain/tests/api/v1/test_quick_log_routes.py`, add the following tests (append to existing file — do not replace it):

```python
# --- GET /quick-log/latest ---

@pytest.mark.asyncio
async def test_latest_returns_empty_when_no_types_param(auth_client):
    """Empty types param returns empty dict."""
    response = await auth_client.get("/api/v1/quick-log/latest")
    assert response.status_code == 200
    assert response.json() == {}


@pytest.mark.asyncio
async def test_latest_returns_most_recent_weight(auth_client, db_session, test_user_id):
    """Returns the most recent weight entry across all time."""
    older = QuickLog(
        id=str(uuid.uuid4()), user_id=test_user_id,
        metric_type="weight", value=75.0,
        data={"value_kg": 75.0}, logged_at="2026-01-01T08:00:00Z",
    )
    newer = QuickLog(
        id=str(uuid.uuid4()), user_id=test_user_id,
        metric_type="weight", value=78.4,
        data={"value_kg": 78.4, "source": "apple_health"},
        logged_at="2026-03-15T08:22:00Z",
    )
    db_session.add_all([older, newer])
    await db_session.commit()

    response = await auth_client.get("/api/v1/quick-log/latest?types=weight")
    assert response.status_code == 200
    body = response.json()
    assert "weight" in body
    assert body["weight"]["value_kg"] == pytest.approx(78.4)
    assert body["weight"]["source"] == "apple_health"


@pytest.mark.asyncio
async def test_latest_absent_when_type_never_logged(auth_client):
    """A type the user has never logged is absent from the response."""
    response = await auth_client.get("/api/v1/quick-log/latest?types=weight")
    assert response.status_code == 200
    assert "weight" not in response.json()


@pytest.mark.asyncio
async def test_latest_returns_steps_with_source(auth_client, db_session, test_user_id):
    """Steps entry includes steps count and source."""
    log = QuickLog(
        id=str(uuid.uuid4()), user_id=test_user_id,
        metric_type="steps", value=9420.0,
        data={"steps": 9420, "mode": "override", "source": "health_connect"},
        logged_at="2026-03-16T11:00:00Z",
    )
    db_session.add(log)
    await db_session.commit()

    response = await auth_client.get("/api/v1/quick-log/latest?types=steps")
    assert response.status_code == 200
    body = response.json()
    assert body["steps"]["steps"] == 9420
    assert body["steps"]["source"] == "health_connect"


@pytest.mark.asyncio
async def test_latest_rejects_unknown_type(auth_client):
    """Returns 422 for an unrecognised metric type."""
    response = await auth_client.get("/api/v1/quick-log/latest?types=banana")
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_latest_cannot_see_other_users_data(auth_client, db_session):
    """Data from another user is not returned."""
    other_log = QuickLog(
        id=str(uuid.uuid4()), user_id="other-user-999",
        metric_type="weight", value=90.0,
        data={"value_kg": 90.0},
        logged_at="2026-03-16T10:00:00Z",
    )
    db_session.add(other_log)
    await db_session.commit()

    response = await auth_client.get("/api/v1/quick-log/latest?types=weight")
    assert response.status_code == 200
    assert "weight" not in response.json()  # not visible to auth_client's user
```

- [ ] **Step 1.2: Run tests to verify they fail**

```bash
cd cloud-brain && pytest tests/api/v1/test_quick_log_routes.py -k "test_latest" -v
```

Expected: All six tests FAIL with `404 Not Found` or similar — the endpoint does not exist yet.

- [ ] **Step 1.3: Implement the endpoint**

Add the following to `cloud-brain/app/api/v1/quick_log_routes.py`, after the existing `get_summary_today` endpoint (around line 1078):

```python
# ---------------------------------------------------------------------------
# Latest values endpoint
# ---------------------------------------------------------------------------


@router.get("/latest", summary="Get the most recent log entry per requested metric type")
@limiter.limit("60/minute")
async def get_latest_log_values(
    request: Request,
    types: str = "",
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return the most recent quick-log entry for each requested metric type.

    The Cloud Brain is the authoritative deduplicated source — data ingested
    from Apple Health, Health Connect, Strava, and manual entries is all
    surfaced here.

    Args:
        request: The incoming FastAPI request (required by slowapi limiter).
        types: Comma-separated list of metric type strings (e.g. 'weight,steps').
               If absent or empty, returns an empty dict.
        user_id: Authenticated user ID (injected by dependency).
        db: Async database session.

    Returns:
        Dict keyed by metric type. Each value is a dict with type-specific
        fields plus ``logged_at`` and ``source``.
        Types that have never been logged are absent from the response.

    Raises:
        HTTPException: 422 if any requested type is not in VALID_METRIC_TYPES.
    """
    if not types or not types.strip():
        return {}

    requested = [t.strip() for t in types.split(",") if t.strip()]
    for t in requested:
        if t not in VALID_METRIC_TYPES:
            raise HTTPException(
                status_code=422,
                detail=f"Invalid metric type '{t}'. Must be one of: {sorted(VALID_METRIC_TYPES)}.",
            )

    result: dict = {}
    for metric_type in requested:
        row = await db.execute(
            select(QuickLog)
            .where(QuickLog.user_id == user_id, QuickLog.metric_type == metric_type)
            .order_by(QuickLog.logged_at.desc())
            .limit(1)
        )
        log = row.scalars().first()
        if log is None:
            continue

        logged_at_str = (
            log.logged_at.isoformat() if hasattr(log.logged_at, "isoformat")
            else str(log.logged_at)
        )
        source = (log.data or {}).get("source", "manual")

        if metric_type == "weight":
            result["weight"] = {
                "value_kg": log.value,
                "logged_at": logged_at_str,
                "source": source,
            }
        elif metric_type == "steps":
            result["steps"] = {
                "steps": int(log.value or 0),
                "logged_at": logged_at_str,
                "source": source,
            }
        else:
            # Generic fallback for other types — value + logged_at + source
            result[metric_type] = {
                "value": log.value,
                "text_value": log.text_value,
                "logged_at": logged_at_str,
                "source": source,
            }

    return result
```

- [ ] **Step 1.4: Run tests to verify they pass**

```bash
cd cloud-brain && pytest tests/api/v1/test_quick_log_routes.py -k "test_latest" -v
```

Expected: All six tests PASS.

- [ ] **Step 1.5: Run full quick-log test suite to confirm nothing regressed**

```bash
cd cloud-brain && pytest tests/api/v1/test_quick_log_routes.py -v
```

Expected: All existing tests PASS.

- [ ] **Step 1.6: Commit**

```bash
git add cloud-brain/app/api/v1/quick_log_routes.py cloud-brain/tests/api/v1/test_quick_log_routes.py
git commit -m "feat: add GET /quick-log/latest endpoint for cross-time last-known values"
```

---

## Chunk 2 — Flutter repository: add missing methods

### Task 2: Add `logWater`, `logWellness`, `logWeight`, `getLatestLogValues` to the repository

**Files:**
- Modify: `zuralog/lib/features/today/data/today_repository.dart`
- Modify: `zuralog/lib/features/today/data/mock_today_repository.dart`

- [ ] **Step 2.1: Add methods to `TodayRepositoryInterface`**

Open `zuralog/lib/features/today/data/today_repository.dart`. After the existing `logSteps` signature in the interface (around line 132), add:

```dart
/// Submit a water intake log entry.
Future<void> logWater({
  required double amountMl,
  String? vesselKey,
});

/// Submit a wellness check-in.
///
/// At least one of [mood], [energy], or [stress] must be non-null.
Future<void> logWellness({
  double? mood,
  double? energy,
  double? stress,
  String? notes,
});

/// Submit a body weight log entry. Always in kg — caller converts.
Future<void> logWeight({required double valueKg});

/// Fetch the most recent log entry for each of the requested [types].
///
/// Returns a map keyed by metric type. Types the user has never logged
/// are absent. The Cloud Brain is the single source of truth — all
/// data ingested from connected health apps is surfaced here.
///
/// Example:
/// ```dart
/// final latest = await repo.getLatestLogValues({'weight', 'steps'});
/// // latest['weight'] → { 'value_kg': 78.4, 'logged_at': '...', 'source': 'apple_health' }
/// ```
Future<Map<String, dynamic>> getLatestLogValues(Set<String> types);
```

- [ ] **Step 2.2: Add implementations to `TodayRepository`**

In the same file, after `logSteps` implementation (around line 439), add:

```dart
@override
Future<void> logWater({
  required double amountMl,
  String? vesselKey,
}) async {
  await _api.post('/api/v1/quick-log/water', data: {
    'amount_ml': amountMl,
    'vessel_key': ?vesselKey,
    'logged_at': DateTime.now().toUtc().toIso8601String(),
  });
}

@override
Future<void> logWellness({
  double? mood,
  double? energy,
  double? stress,
  String? notes,
}) async {
  await _api.post('/api/v1/quick-log/wellness', data: {
    'mood': ?mood,
    'energy': ?energy,
    'stress': ?stress,
    'notes': ?notes,
    'logged_at': DateTime.now().toUtc().toIso8601String(),
  });
}

@override
Future<void> logWeight({required double valueKg}) async {
  await _api.post('/api/v1/quick-log/weight', data: {
    'value_kg': valueKg,
    'logged_at': DateTime.now().toUtc().toIso8601String(),
  });
}

@override
Future<Map<String, dynamic>> getLatestLogValues(Set<String> types) async {
  if (types.isEmpty) return const {};
  final typesParam = types.join(',');
  final response = await _api.get(
    '/api/v1/quick-log/latest',
    queryParameters: {'types': typesParam},
  );
  return (response.data as Map<String, dynamic>?) ?? const {};
}
```

- [ ] **Step 2.3: Add stubs to `MockTodayRepository`**

Open `zuralog/lib/features/today/data/mock_today_repository.dart`. Add the four new methods (no-op stubs for logWater, logWellness, logWeight; empty map for getLatestLogValues):

```dart
@override
Future<void> logWater({
  required double amountMl,
  String? vesselKey,
}) async {}

@override
Future<void> logWellness({
  double? mood,
  double? energy,
  double? stress,
  String? notes,
}) async {}

@override
Future<void> logWeight({required double valueKg}) async {}

@override
Future<Map<String, dynamic>> getLatestLogValues(Set<String> types) async {
  return const {};
}
```

- [ ] **Step 2.4: Run analyze to verify no broken interface**

```bash
cd zuralog && flutter analyze lib/features/today/data/
```

Expected: No issues.

- [ ] **Step 2.5: Commit**

```bash
git add zuralog/lib/features/today/data/today_repository.dart zuralog/lib/features/today/data/mock_today_repository.dart
git commit -m "feat: add logWater, logWellness, logWeight, getLatestLogValues to TodayRepository"
```

---

## Chunk 3 — Flutter provider: `latestLogValuesProvider`

### Task 3: Add `latestLogValuesProvider` to `today_providers.dart`

**Files:**
- Modify: `zuralog/lib/features/today/providers/today_providers.dart`

- [ ] **Step 3.1: Write the failing test first**

Open `zuralog/test/features/today/providers/today_log_summary_provider_test.dart` and append:

```dart
// --- latestLogValuesProvider ---

group('latestLogValuesProvider', () {
  test('returns empty map when types set is empty', () async {
    final container = ProviderContainer(overrides: [
      todayRepositoryProvider.overrideWithValue(MockTodayRepository()),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(
      latestLogValuesProvider(const {}).future,
    );
    expect(result, isEmpty);
  });

  test('returns map from repository for requested types', () async {
    final mockRepo = _MockRepoWithLatestValues({
      'weight': {'value_kg': 78.4, 'logged_at': '2026-03-15T08:22:00Z', 'source': 'apple_health'},
    });
    final container = ProviderContainer(overrides: [
      todayRepositoryProvider.overrideWithValue(mockRepo),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(
      latestLogValuesProvider(const {'weight'}).future,
    );
    expect(result['weight']?['value_kg'], closeTo(78.4, 0.01));
    expect(result['weight']?['source'], 'apple_health');
  });
});

// Helper mock for latestLogValuesProvider tests
class _MockRepoWithLatestValues extends MockTodayRepository {
  _MockRepoWithLatestValues(this._data);
  final Map<String, dynamic> _data;

  @override
  Future<Map<String, dynamic>> getLatestLogValues(Set<String> types) async {
    return Map.fromEntries(
      _data.entries.where((e) => types.contains(e.key)),
    );
  }
}
```

- [ ] **Step 3.2: Run test to verify it fails**

```bash
cd zuralog && flutter test test/features/today/providers/today_log_summary_provider_test.dart -v
```

Expected: FAIL — `latestLogValuesProvider` not defined.

- [ ] **Step 3.3: Add `latestLogValuesProvider` to `today_providers.dart`**

Open `zuralog/lib/features/today/providers/today_providers.dart`. After `stepsLogModeProvider` at the end of the file, add:

```dart
// ── Latest Log Values ─────────────────────────────────────────────────────────

/// The most recent logged value per requested metric type, across all time.
///
/// The Cloud Brain is the deduplicated source of truth — values ingested from
/// Apple Health, Health Connect, Strava, and manual entries are all surfaced
/// here.
///
/// Keyed by a [Set<String>] of metric type strings. The provider fetches
/// all requested types in a single API call.
///
/// Returns an empty map if [types] is empty or the request fails.
/// Individual types the user has never logged are absent from the returned map.
///
/// Automatically re-fetches whenever [todayLogSummaryProvider] is invalidated
/// (i.e. after any successful log submission), keeping pre-fill values fresh.
final latestLogValuesProvider =
    FutureProvider.family<Map<String, dynamic>, Set<String>>((ref, types) async {
  // Establish a reactive dependency so this provider auto-refreshes when
  // a new log is submitted (same invalidation trigger as todayLogSummaryProvider).
  ref.watch(todayLogSummaryProvider);

  if (types.isEmpty) return const {};
  final repo = ref.read(todayRepositoryProvider);
  try {
    return await repo.getLatestLogValues(types);
  } catch (e, st) {
    debugPrint('latestLogValuesProvider failed: $e\n$st');
    return const {};
  }
});
```

- [ ] **Step 3.4: Run test to verify it passes**

```bash
cd zuralog && flutter test test/features/today/providers/today_log_summary_provider_test.dart -v
```

Expected: All tests PASS.

- [ ] **Step 3.5: Run analyze**

```bash
cd zuralog && flutter analyze lib/features/today/providers/today_providers.dart
```

Expected: No issues.

- [ ] **Step 3.6: Commit**

```bash
git add zuralog/lib/features/today/providers/today_providers.dart zuralog/test/features/today/providers/today_log_summary_provider_test.dart
git commit -m "feat: add latestLogValuesProvider backed by GET /quick-log/latest"
```

---

## Chunk 4 — ZWaterLogPanel: unit awareness and real save

### Task 4: Wire real `logWater` call and add oz/ml unit awareness to `ZWaterLogPanel`

**Files:**
- Modify: `zuralog/lib/shared/widgets/log_panels/z_water_log_panel.dart`
- Modify: `zuralog/lib/shared/widgets/sheets/z_log_grid_sheet.dart`
- Create: `zuralog/test/shared/widgets/log_panels/z_water_log_panel_test.dart`

**Unit conversion constants (at top of panel file, below `_kVessels`):**

| Vessel | ml | oz (approx) |
|--------|-----|------|
| Small cup | 150 | 5 |
| Glass | 250 | 8 |
| Bottle | 500 | 17 |
| Large bottle | 750 | 25 |

1 oz = 29.5735 ml (use `const double _kOzToMl = 29.5735`)

- [ ] **Step 4.1: Write failing widget tests**

Create `zuralog/test/shared/widgets/log_panels/z_water_log_panel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/log_panels/z_water_log_panel.dart';

// Minimal test helper — wraps the panel in a ProviderScope with stubs
Widget _wrap(Widget child, {UnitsSystem units = UnitsSystem.metric}) {
  return ProviderScope(
    overrides: [
      todayLogSummaryProvider.overrideWith(
        (ref) async => TodayLogSummary.empty,
      ),
      unitsSystemProvider.overrideWithValue(units),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('ZWaterLogPanel', () {
    testWidgets('Save button disabled before vessel selection', (tester) async {
      double? savedAmount;
      await tester.pumpWidget(_wrap(ZWaterLogPanel(
        onSave: (ml) => savedAmount = ml,
        onBack: () {},
      )));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(savedAmount, isNull);
    });

    testWidgets('Selecting Glass chip sets 250 ml and enables Save', (tester) async {
      double? savedAmount;
      await tester.pumpWidget(_wrap(ZWaterLogPanel(
        onSave: (ml) => savedAmount = ml,
        onBack: () {},
      )));
      await tester.pump();

      await tester.tap(find.text('Glass'));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(savedAmount, closeTo(250.0, 0.01));
    });

    testWidgets('Custom chip shows text field; input accepted', (tester) async {
      double? savedAmount;
      await tester.pumpWidget(_wrap(ZWaterLogPanel(
        onSave: (ml) => savedAmount = ml,
        onBack: () {},
      )));
      await tester.pump();

      await tester.tap(find.text('Custom'));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '300');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(savedAmount, closeTo(300.0, 0.01));
    });

    testWidgets('In imperial mode Glass chip shows oz label', (tester) async {
      await tester.pumpWidget(_wrap(
        ZWaterLogPanel(onSave: (_) {}, onBack: () {}),
        units: UnitsSystem.imperial,
      ));
      await tester.pump();

      // Glass vessel should display its oz equivalent label
      expect(find.textContaining('oz'), findsWidgets);
    });

    testWidgets('In imperial mode save converts oz to ml', (tester) async {
      double? savedAmount;
      await tester.pumpWidget(_wrap(
        ZWaterLogPanel(onSave: (ml) => savedAmount = ml, onBack: () {}),
        units: UnitsSystem.imperial,
      ));
      await tester.pump();

      // Tap the Glass chip (8 oz = 236.6 ml)
      await tester.tap(find.textContaining('8 oz'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      // 8 oz * 29.5735 = 236.588 ml
      expect(savedAmount, closeTo(236.6, 1.0));
    });
  });
}
```

- [ ] **Step 4.2: Run tests to verify they fail**

```bash
cd zuralog && flutter test test/shared/widgets/log_panels/z_water_log_panel_test.dart -v
```

Expected: FAIL — imperial mode not yet implemented.

- [ ] **Step 4.3: Implement unit awareness in `z_water_log_panel.dart`**

Add imports to the top of the file (after existing imports):
```dart
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
```

Below the existing `_kVessels` constant, add:

```dart
const double _kOzToMl = 29.5735;

// oz display amounts per vessel (rounded to nearest whole oz)
const _kVesselOz = {
  'small_cup': 5.0,
  'glass': 8.0,
  'bottle': 17.0,
  'large': 25.0,
};
```

In `_ZWaterLogPanelState`, add a helper to compute displayed label and actual ml per vessel:

```dart
/// Returns the display label for a vessel in the current unit system.
String _vesselLabel(_VesselPreset vessel, bool isImperial) {
  if (vessel.ml == null) return 'Custom';
  if (isImperial) {
    final oz = _kVesselOz[vessel.key] ?? (vessel.ml! / _kOzToMl).roundToDouble();
    return '${vessel.label}\n${oz.toStringAsFixed(0)} oz';
  }
  return '${vessel.label}\n${vessel.ml!.toStringAsFixed(0)} ml';
}

/// Returns the amount in ml for a vessel in the current unit system.
/// [displayValue] is used for the custom field — it is already in the
/// user's chosen unit and must be converted.
double _toMl(_VesselPreset vessel, {double? customDisplayValue, required bool isImperial}) {
  if (vessel.ml != null) {
    if (isImperial) {
      final oz = _kVesselOz[vessel.key] ?? (vessel.ml! / _kOzToMl);
      return oz * _kOzToMl;
    }
    return vessel.ml!;
  }
  // Custom: displayValue is in oz (imperial) or ml (metric)
  if (customDisplayValue == null || customDisplayValue <= 0) return 0;
  return isImperial ? customDisplayValue * _kOzToMl : customDisplayValue;
}
```

In `build()`, read `unitsSystemProvider`:

```dart
final isImperial = ref.watch(unitsSystemProvider) == UnitsSystem.imperial;
```

Update the chip labels to use `_vesselLabel(vessel, isImperial)`.

Update `_onCustomChanged` and `_selectVessel` so `_amountMl` always stores ml:

```dart
void _selectVessel(_VesselPreset vessel) {
  final isImperial = ref.read(unitsSystemProvider) == UnitsSystem.imperial;
  setState(() {
    _selectedVesselKey = vessel.key;
    if (vessel.ml != null) {
      _amountMl = _toMl(vessel, isImperial: isImperial);
      _customController.clear();
    } else {
      _amountMl = 0;
    }
  });
}

void _onCustomChanged(String value) {
  final isImperial = ref.read(unitsSystemProvider) == UnitsSystem.imperial;
  final parsed = double.tryParse(value) ?? 0;
  setState(() => _amountMl = isImperial ? parsed * _kOzToMl : parsed);
}
```

Update custom field hint text:

```dart
hintText: isImperial ? 'Enter amount (oz)' : 'Enter amount (ml)',
suffixText: isImperial ? 'oz' : 'ml',
```

Update "X ml today" display to show oz when imperial:

```dart
final todayMl = summary.latestValues['water'] as double?;
final String label;
if (todayMl == null) {
  label = 'Nothing logged yet today';
} else if (isImperial) {
  final oz = todayMl / _kOzToMl;
  label = '${oz.toStringAsFixed(1)} oz logged today';
} else {
  label = '${todayMl.toStringAsFixed(0)} ml logged today';
}
```

- [ ] **Step 4.4: Wire real save in `z_log_grid_sheet.dart`**

In `_PanelView.build()`, replace the water `onSave` no-op with a real call:

```dart
'water' => ZWaterLogPanel(
    onSave: (ml) async {
      try {
        await ref.read(todayRepositoryProvider).logWater(amountMl: ml);
        ref.invalidate(todayLogSummaryProvider);
        onSaved();
      } catch (e) {
        debugPrint('logWater failed: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save water. Please try again.'),
            ),
          );
        }
      }
    },
    onBack: onBack,
  ),
```

Note: change `onSave` signature in `ZWaterLogPanel` from `void Function(double)` to `Future<void> Function(double)` so the caller can `await` it. Update `_handleSave` accordingly:

```dart
// In ZWaterLogPanel widget declaration:
final Future<void> Function(double amountMl) onSave;

// In _handleSave:
Future<void> _handleSave() async {
  await widget.onSave(_amountMl);
}
```

- [ ] **Step 4.5: Run tests**

```bash
cd zuralog && flutter test test/shared/widgets/log_panels/z_water_log_panel_test.dart -v
```

Expected: All tests PASS.

- [ ] **Step 4.6: Run analyze**

```bash
cd zuralog && flutter analyze lib/shared/widgets/log_panels/z_water_log_panel.dart lib/shared/widgets/sheets/z_log_grid_sheet.dart
```

Expected: No issues.

- [ ] **Step 4.7: Commit**

```bash
git add zuralog/lib/shared/widgets/log_panels/z_water_log_panel.dart zuralog/lib/shared/widgets/sheets/z_log_grid_sheet.dart zuralog/test/shared/widgets/log_panels/z_water_log_panel_test.dart
git commit -m "feat: wire logWater API call and add oz/ml unit awareness to ZWaterLogPanel"
```

---

## Chunk 5 — ZWellnessLogPanel: real save

### Task 5: Wire real `logWellness` call in `ZWellnessLogPanel`

**Files:**
- Modify: `zuralog/lib/shared/widgets/log_panels/z_wellness_log_panel.dart`
- Modify: `zuralog/lib/shared/widgets/sheets/z_log_grid_sheet.dart`
- Create: `zuralog/test/shared/widgets/log_panels/z_wellness_log_panel_test.dart`

- [ ] **Step 5.1: Write failing widget tests**

Create `zuralog/test/shared/widgets/log_panels/z_wellness_log_panel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/widgets/log_panels/z_wellness_log_panel.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('ZWellnessLogPanel', () {
    testWidgets('Save button disabled before any slider is touched', (tester) async {
      await tester.pumpWidget(_wrap(ZWellnessLogPanel(
        onSave: (_) async {},
        onBack: () {},
      )));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Moving Mood slider enables Save', (tester) async {
      WellnessLogData? saved;
      await tester.pumpWidget(_wrap(ZWellnessLogPanel(
        onSave: (data) async => saved = data,
        onBack: () {},
      )));
      await tester.pump();

      // Drag the first Slider to trigger a value change
      final slider = tester.widgetList<Slider>(find.byType(Slider)).first;
      final sliderFinder = find.byWidget(slider);
      await tester.drag(sliderFinder, const Offset(20.0, 0.0));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(saved, isNotNull);
      expect(saved!.mood, isNotNull);
      expect(saved!.energy, isNull);
      expect(saved!.stress, isNull);
    });

    testWidgets('Notes field enforces 500 char limit', (tester) async {
      await tester.pumpWidget(_wrap(ZWellnessLogPanel(
        onSave: (_) async {},
        onBack: () {},
      )));
      await tester.pump();

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'A' * 600);
      await tester.pump();

      final controller = tester
          .widget<TextField>(textField)
          .controller;
      expect(controller?.text.length, lessThanOrEqualTo(500));
    });
  });
}
```

- [ ] **Step 5.2: Run tests to verify they fail**

```bash
cd zuralog && flutter test test/shared/widgets/log_panels/z_wellness_log_panel_test.dart -v
```

Expected: FAIL — `onSave` is `void Function(WellnessLogData)` not `Future<void>` yet.

- [ ] **Step 5.3: Update `ZWellnessLogPanel.onSave` signature to async**

In `z_wellness_log_panel.dart`, change:

```dart
// Before:
final void Function(WellnessLogData data) onSave;

// After:
final Future<void> Function(WellnessLogData data) onSave;
```

Update `_handleSave`:

```dart
Future<void> _handleSave() async {
  final data = WellnessLogData(
    mood: _moodTouched ? _moodValue : null,
    energy: _energyTouched ? _energyValue : null,
    stress: _stressTouched ? _stressValue : null,
    notes: _notesController.text.isEmpty ? null : _notesController.text,
  );
  await widget.onSave(data);
}
```

- [ ] **Step 5.4: Wire real save in `z_log_grid_sheet.dart`**

Replace the wellness `onSave` no-op in `_PanelView.build()`:

```dart
'mood' => ZWellnessLogPanel(
    onSave: (data) async {
      try {
        await ref.read(todayRepositoryProvider).logWellness(
          mood: data.mood,
          energy: data.energy,
          stress: data.stress,
          notes: data.notes,
        );
        ref.invalidate(todayLogSummaryProvider);
        onSaved();
      } catch (e) {
        debugPrint('logWellness failed: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save check-in. Please try again.'),
            ),
          );
        }
      }
    },
    onBack: onBack,
  ),
```

- [ ] **Step 5.5: Run tests**

```bash
cd zuralog && flutter test test/shared/widgets/log_panels/z_wellness_log_panel_test.dart -v
```

Expected: All tests PASS.

- [ ] **Step 5.6: Run analyze**

```bash
cd zuralog && flutter analyze lib/shared/widgets/log_panels/z_wellness_log_panel.dart lib/shared/widgets/sheets/z_log_grid_sheet.dart
```

Expected: No issues.

- [ ] **Step 5.7: Commit**

```bash
git add zuralog/lib/shared/widgets/log_panels/z_wellness_log_panel.dart zuralog/lib/shared/widgets/sheets/z_log_grid_sheet.dart zuralog/test/shared/widgets/log_panels/z_wellness_log_panel_test.dart
git commit -m "feat: wire logWellness API call in ZWellnessLogPanel"
```

---

## Chunk 6 — ZWeightLogPanel: pre-fill, delta, last-unit persistence, real save

### Task 6: Add pre-fill from `latestLogValuesProvider`, delta indicator, last-unit persistence, and real `logWeight` call

**Files:**
- Modify: `zuralog/lib/shared/widgets/log_panels/z_weight_log_panel.dart`
- Modify: `zuralog/lib/shared/widgets/sheets/z_log_grid_sheet.dart`
- Create: `zuralog/test/shared/widgets/log_panels/z_weight_log_panel_test.dart`

**Logic overview:**

- On panel init, read `latestLogValuesProvider({'weight'})`.
  - If data is present: set `_value = data['weight']['value_kg']`, store it as `_lastLoggedKg`, store `_lastLoggedAt` as the formatted date string, `_lastLoggedSource` as the source string.
  - If absent: keep default `_value = 70.0`, `_lastLoggedKg = null`.
- Unit preference: read `SharedPreferences.getString('weight_log_unit')` first. If set, use it. Otherwise fall back to `unitsSystemProvider`. When the toggle changes, write the new value to SharedPreferences.
- Delta indicator: `(_value - _lastLoggedKg!)`. Show in green if negative (lost), red if positive (gained), grey if zero. Format: "+0.3 kg" / "−0.3 kg" in the display unit.
- "Last logged" text: show `_lastLoggedAt` + source display name. Source display names: `'apple_health'` → "Apple Health", `'health_connect'` → "Health Connect", `'manual'` → omit source.
- `onSave` signature changes to `Future<void> Function(double valueKg)`.

- [ ] **Step 6.1: Write failing tests**

Create `zuralog/test/shared/widgets/log_panels/z_weight_log_panel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/shared/widgets/log_panels/z_weight_log_panel.dart';

Widget _wrap(
  Widget child, {
  Map<String, dynamic> latestWeight = const {},
}) {
  return ProviderScope(
    overrides: [
      todayLogSummaryProvider.overrideWith(
        (ref) async => TodayLogSummary.empty,
      ),
      latestLogValuesProvider({'weight'}).overrideWith(
        (ref) async => latestWeight.isEmpty
            ? const <String, dynamic>{}
            : {'weight': latestWeight},
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('ZWeightLogPanel', () {
    testWidgets('Shows default value when no previous log exists', (tester) async {
      await tester.pumpWidget(_wrap(ZWeightLogPanel(
        onSave: (_) async {},
        onBack: () {},
      )));
      await tester.pumpAndSettle();

      // Default 70.0 kg should be shown
      expect(find.textContaining('70'), findsOneWidget);
      // Last logged row should show em dash (no previous entry)
      expect(find.textContaining('Last logged: —'), findsOneWidget);
    });

    testWidgets('Pre-fills with latest logged weight from cloud brain', (tester) async {
      await tester.pumpWidget(_wrap(
        ZWeightLogPanel(onSave: (_) async {}, onBack: () {}),
        latestWeight: {
          'value_kg': 78.4,
          'logged_at': '2026-03-15T08:22:00Z',
          'source': 'apple_health',
        },
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('78.4'), findsOneWidget);
      expect(find.textContaining('Apple Health'), findsOneWidget);
    });

    testWidgets('Delta shown after increment', (tester) async {
      await tester.pumpWidget(_wrap(
        ZWeightLogPanel(onSave: (_) async {}, onBack: () {}),
        latestWeight: {
          'value_kg': 78.0,
          'logged_at': '2026-03-15T08:22:00Z',
          'source': 'manual',
        },
      ));
      await tester.pumpAndSettle();

      // Tap + to go to 78.1
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect(find.textContaining('+0.1'), findsOneWidget);
    });

    testWidgets('Save calls onSave with value in kg', (tester) async {
      double? savedKg;
      await tester.pumpWidget(_wrap(ZWeightLogPanel(
        onSave: (kg) async => savedKg = kg,
        onBack: () {},
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(savedKg, isNotNull);
      expect(savedKg, closeTo(70.0, 0.1)); // default
    });
  });
}
```

- [ ] **Step 6.2: Run tests to verify they fail**

```bash
cd zuralog && flutter test test/shared/widgets/log_panels/z_weight_log_panel_test.dart -v
```

Expected: FAIL — pre-fill and delta not yet implemented.

- [ ] **Step 6.3: Implement pre-fill, delta, last-unit persistence in `z_weight_log_panel.dart`**

Add imports at top of file:
```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
```

Add state fields to `_ZWeightLogPanelState`:
```dart
double? _lastLoggedKg;
String? _lastLoggedAt;    // formatted date string, e.g. "15 Mar 2026"
String? _lastLoggedSource; // e.g. "Apple Health"
static const _kWeightUnitKey = 'weight_log_unit';
```

Load last-used unit preference in `didChangeDependencies` (replace current logic):
```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (!_initialized) {
    _initialized = true;
    _loadUnitPreference();
  }
}

Future<void> _loadUnitPreference() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kWeightUnitKey);
  if (saved != null) {
    setState(() => _isKg = saved == 'kg');
  } else {
    // Fall back to unitsSystemProvider
    final units = ref.read(unitsSystemProvider);
    setState(() => _isKg = units == UnitsSystem.metric);
  }
}
```

Persist unit on toggle (update `_UnitChip` tap handlers):
```dart
void _setUnit(bool isKg) async {
  setState(() => _isKg = isKg);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kWeightUnitKey, isKg ? 'kg' : 'lbs');
}
```

Pre-fill from `latestLogValuesProvider` in `build()`:
```dart
// Watch the latest values — pre-fill when data arrives
ref.watch(latestLogValuesProvider(const {'weight'})).whenData((latest) {
  final w = latest['weight'] as Map<String, dynamic>?;
  if (w != null && _lastLoggedKg == null) {
    final kg = (w['value_kg'] as num?)?.toDouble();
    final loggedAt = w['logged_at'] as String?;
    final source = w['source'] as String? ?? 'manual';
    if (kg != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _value = kg.clamp(20.0, 500.0);
            _lastLoggedKg = kg;
            _lastLoggedAt = _formatDate(loggedAt);
            _lastLoggedSource = _sourceDisplayName(source);
          });
        }
      });
    }
  }
});
```

Add helpers:
```dart
String _formatDate(String? iso) {
  if (iso == null) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return '—';
  }
}

String _sourceDisplayName(String source) => switch (source) {
  'apple_health'    => 'Apple Health',
  'health_connect'  => 'Health Connect',
  _                 => '',
};
```

Update the "Last logged" section in `build()`:
```dart
// Last logged row
Center(
  child: Column(
    children: [
      Text(
        _lastLoggedKg == null
            ? 'Last logged: —'
            : 'Last logged: $_lastLoggedAt'
              '${_lastLoggedSource!.isNotEmpty ? " · $_lastLoggedSource" : ""}',
        style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
      ),
      if (_lastLoggedKg != null) ...[
        const SizedBox(height: AppDimens.spaceXs),
        _DeltaIndicator(
          currentKg: _value,
          previousKg: _lastLoggedKg!,
          isKg: _isKg,
        ),
      ],
    ],
  ),
),
```

Add `_DeltaIndicator` private widget at bottom of file:
```dart
class _DeltaIndicator extends StatelessWidget {
  const _DeltaIndicator({
    required this.currentKg,
    required this.previousKg,
    required this.isKg,
  });

  final double currentKg;
  final double previousKg;
  final bool isKg;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final deltaKg = currentKg - previousKg;
    if (deltaKg.abs() < 0.05) {
      return Text(
        'No change from last entry',
        style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
      );
    }
    final display = isKg
        ? deltaKg.abs().toStringAsFixed(1)
        : (deltaKg.abs() * 2.20462).toStringAsFixed(1);
    final unit = isKg ? 'kg' : 'lbs';
    final sign = deltaKg > 0 ? '+' : '−';
    final color = deltaKg > 0
        ? AppColors.categoryHeart   // red — gained
        : AppColors.categoryActivity; // green — lost
    return Text(
      '$sign$display $unit from last entry',
      style: AppTextStyles.bodySmall.copyWith(color: color),
    );
  }
}
```

Update `onSave` signature to async:
```dart
final Future<void> Function(double valueKg) onSave;
```

Update `_handleSave`:
```dart
Future<void> _handleSave() async {
  await widget.onSave(_value);
}
```

- [ ] **Step 6.4: Wire real save in `z_log_grid_sheet.dart`**

Replace the weight `onSave` no-op in `_PanelView.build()`:

```dart
'weight' => ZWeightLogPanel(
    onSave: (kg) async {
      try {
        await ref.read(todayRepositoryProvider).logWeight(valueKg: kg);
        ref.invalidate(todayLogSummaryProvider);
        onSaved();
      } catch (e) {
        debugPrint('logWeight failed: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save weight. Please try again.'),
            ),
          );
        }
      }
    },
    onBack: onBack,
  ),
```

- [ ] **Step 6.5: Run tests**

```bash
cd zuralog && flutter test test/shared/widgets/log_panels/z_weight_log_panel_test.dart -v
```

Expected: All tests PASS.

- [ ] **Step 6.6: Run analyze**

```bash
cd zuralog && flutter analyze lib/shared/widgets/log_panels/z_weight_log_panel.dart lib/shared/widgets/sheets/z_log_grid_sheet.dart
```

Expected: No issues.

- [ ] **Step 6.7: Commit**

```bash
git add zuralog/lib/shared/widgets/log_panels/z_weight_log_panel.dart zuralog/lib/shared/widgets/sheets/z_log_grid_sheet.dart zuralog/test/shared/widgets/log_panels/z_weight_log_panel_test.dart
git commit -m "feat: add pre-fill, delta indicator, unit persistence, and logWeight call to ZWeightLogPanel"
```

---

## Chunk 7 — ZStepsLogPanel: real sync banner, goal display, "Confirm Steps" label

### Task 7: Replace placeholder sync banner with real data from `latestLogValuesProvider`, wire goal display, add "Confirm Steps" label

**Files:**
- Modify: `zuralog/lib/shared/widgets/log_panels/z_steps_log_panel.dart`
- Create: `zuralog/test/shared/widgets/log_panels/z_steps_log_panel_test.dart`

**Logic overview:**

- On panel open, read `latestLogValuesProvider({'steps'})`.
  - If data is present AND `logged_at` is today (compare date portion only):
    - Show sync banner: "✓ Synced from [source display name] — [value] steps today. You can override below."
    - Pre-fill the text controller with the synced value.
    - Track `_syncedSteps` — if the current field value equals `_syncedSteps`, show "Confirm Steps" as the button label; otherwise "Save Steps".
  - If data is absent or not from today: hide the banner entirely (no placeholder text).
- Goal display: read `dailyGoalsProvider`. Find the entry with type `'steps'` (if any). If found: show "Goal: [target] · [percent]% done". If not found: show "Goal: —" (current behaviour — no change needed unless a goal exists).

Source display names are the same as in the weight panel: `'apple_health'` → "Apple Health", `'health_connect'` → "Health Connect", `'manual'` → omit (do not show a banner for manual entries from a previous session).

Note: `_syncedSteps` is an `int?`. "Equals" comparison is exact integer equality.

- [ ] **Step 7.1: Write failing tests**

Create `zuralog/test/shared/widgets/log_panels/z_steps_log_panel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/shared/widgets/log_panels/z_steps_log_panel.dart';

// Today's ISO timestamp for test data
final _todayIso =
    DateTime.now().toUtc().toIso8601String();

Widget _wrap(
  Widget child, {
  Map<String, dynamic> latestSteps = const {},
  List<DailyGoal> goals = const [],
}) {
  return ProviderScope(
    overrides: [
      stepsLogModeProvider.overrideWith(() => _StubModeNotifier()),
      todayLogSummaryProvider.overrideWith(
        (ref) async => TodayLogSummary.empty,
      ),
      latestLogValuesProvider({'steps'}).overrideWith(
        (ref) async => latestSteps.isEmpty
            ? const <String, dynamic>{}
            : {'steps': latestSteps},
      ),
      dailyGoalsProvider.overrideWith(
        (ref) async => goals,
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

// Minimal stub notifier so stepsLogModeProvider resolves synchronously
class _StubModeNotifier extends StepsLogModeNotifier {
  @override
  Future<StepsLogMode> build() async => StepsLogMode.add;
}

void main() {
  group('ZStepsLogPanel sync banner', () {
    testWidgets('Shows no banner when no synced data', (tester) async {
      await tester.pumpWidget(_wrap(ZStepsLogPanel(
        onSave: (_, __) async {},
        onBack: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Synced'), findsNothing);
      expect(find.textContaining('will appear here'), findsNothing);
    });

    testWidgets('Shows sync banner and pre-fills when today data is available', (tester) async {
      await tester.pumpWidget(_wrap(
        ZStepsLogPanel(onSave: (_, __) async {}, onBack: () {}),
        latestSteps: {
          'steps': 9420,
          'logged_at': _todayIso,
          'source': 'apple_health',
        },
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Apple Health'), findsOneWidget);
      expect(find.textContaining('9420'), findsWidgets);
    });

    testWidgets('Button shows Confirm Steps when value matches synced', (tester) async {
      await tester.pumpWidget(_wrap(
        ZStepsLogPanel(onSave: (_, __) async {}, onBack: () {}),
        latestSteps: {
          'steps': 9420,
          'logged_at': _todayIso,
          'source': 'health_connect',
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Steps'), findsOneWidget);
    });

    testWidgets('Button reverts to Save Steps when value is changed', (tester) async {
      await tester.pumpWidget(_wrap(
        ZStepsLogPanel(onSave: (_, __) async {}, onBack: () {}),
        latestSteps: {
          'steps': 9420,
          'logged_at': _todayIso,
          'source': 'apple_health',
        },
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '8000');
      await tester.pump();

      expect(find.text('Save Steps'), findsOneWidget);
    });
  });

  group('ZStepsLogPanel goal display', () {
    testWidgets('Shows Goal dash when no step goal configured', (tester) async {
      await tester.pumpWidget(_wrap(ZStepsLogPanel(
        onSave: (_, __) async {},
        onBack: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Goal: —'), findsOneWidget);
    });

    testWidgets('Shows goal progress when step goal exists', (tester) async {
      await tester.pumpWidget(_wrap(
        ZStepsLogPanel(onSave: (_, __) async {}, onBack: () {}),
        goals: [
          DailyGoal(
            id: 'goal-steps-1',
            label: 'Steps',
            target: 10000,
            current: 6200,
            unit: 'steps',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('10,000'), findsOneWidget);
      expect(find.textContaining('62%'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 7.2: Run tests to verify they fail**

```bash
cd zuralog && flutter test test/shared/widgets/log_panels/z_steps_log_panel_test.dart -v
```

Expected: FAIL — banner and goal logic not yet implemented.

- [ ] **Step 7.3: Implement sync banner, goal display, and "Confirm Steps" in `z_steps_log_panel.dart`**

> **Before editing:** Confirm the step count state field is named `_steps` (int) at line 47 of `z_steps_log_panel.dart` and the text controller is `_controller` at line 48. The implementation below uses these exact names.

Add state fields:
```dart
int? _syncedSteps;   // steps value from the sync banner, null if no synced data today
```

In `build()`, read `latestLogValuesProvider({'steps'})` and `dailyGoalsProvider`:

```dart
// Read latest synced steps value
ref.watch(latestLogValuesProvider(const {'steps'})).whenData((latest) {
  final s = latest['steps'] as Map<String, dynamic>?;
  if (s != null && _syncedSteps == null) {
    final steps = (s['steps'] as num?)?.toInt();
    final loggedAt = s['logged_at'] as String?;
    final source = s['source'] as String? ?? 'manual';
    final isToday = _isToday(loggedAt);
    if (steps != null && isToday && source != 'manual') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _syncedSteps = steps;
            _steps = steps;
            _controller.text = steps.toString();
          });
        }
      });
    }
  }
});

final goals = ref.watch(dailyGoalsProvider).valueOrNull ?? const [];
// DailyGoal has no 'type' field — match by unit or label as the canonical
// identifier for a step goal. (DailyGoal fields: id, label, current, target, unit)
final stepGoal = goals.where(
  (g) => g.unit.toLowerCase() == 'steps' || g.label.toLowerCase() == 'steps',
).firstOrNull;
```

Add helper:
```dart
bool _isToday(String? iso) {
  if (iso == null) return false;
  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  } catch (_) {
    return false;
  }
}

String _sourceDisplayName(String source) => switch (source) {
  'apple_health'   => 'Apple Health',
  'health_connect' => 'Health Connect',
  _                => '',
};
```

Replace the static sync banner widget in `build()` with a conditional:

```dart
// Sync banner — shown only when today's synced data is available
if (_syncedSteps != null) ...[
  Container(
    padding: const EdgeInsets.all(AppDimens.spaceMd),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
    ),
    child: ref.watch(latestLogValuesProvider(const {'steps'})).when(
      data: (latest) {
        final s = latest['steps'] as Map<String, dynamic>?;
        final source = _sourceDisplayName(
          (s?['source'] as String?) ?? 'manual',
        );
        return Text(
          '✓ Synced from $source — ${_syncedSteps!} steps today. '
          'You can override below.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    ),
  ),
  const SizedBox(height: AppDimens.spaceMd),
],
```

Replace the static "Goal: —" text with:

```dart
Text(
  stepGoal == null
      ? 'Goal: —'
      : 'Goal: ${_formatStepGoal(stepGoal.target)} · '
        '${(stepGoal.current / stepGoal.target * 100).round()}% done',
  style: AppTextStyles.bodySmall.copyWith(color: colors.textTertiary),
),
```

Add helper:
```dart
String _formatStepGoal(double target) {
  final n = target.toInt();
  if (n >= 1000) {
    return '${(n ~/ 1000)},${(n % 1000).toString().padLeft(3, '0')}';
  }
  return n.toString();
}
```

Update save button label:
```dart
child: Text(
  (_syncedSteps != null && _steps == _syncedSteps)
      ? 'Confirm Steps'
      : 'Save Steps',
  style: AppTextStyles.labelLarge,
),
```

Update `_onChanged` to trigger rebuild so "Confirm Steps" / "Save Steps" switches reactively:
```dart
void _onChanged(String value) {
  final parsed = int.tryParse(value) ?? 0;
  setState(() => _steps = parsed);
}
```

- [ ] **Step 7.4: Run tests**

```bash
cd zuralog && flutter test test/shared/widgets/log_panels/z_steps_log_panel_test.dart -v
```

Expected: All tests PASS.

- [ ] **Step 7.5: Run analyze**

```bash
cd zuralog && flutter analyze lib/shared/widgets/log_panels/z_steps_log_panel.dart
```

Expected: No issues.

- [ ] **Step 7.6: Commit**

```bash
git add zuralog/lib/shared/widgets/log_panels/z_steps_log_panel.dart zuralog/test/shared/widgets/log_panels/z_steps_log_panel_test.dart
git commit -m "feat: add real sync banner, goal display, and Confirm Steps label to ZStepsLogPanel"
```

---

## Chunk 8 — Final verification

### Task 8: Full analyze + test run, then docs update

- [ ] **Step 8.1: Run full Flutter analyze**

```bash
cd zuralog && flutter analyze
```

Expected: Zero issues. Fix any before proceeding.

- [ ] **Step 8.2: Run full Flutter test suite**

```bash
cd zuralog && flutter test
```

Expected: All tests PASS. Fix any failures before proceeding.

- [ ] **Step 8.3: Run full backend test suite**

```bash
cd cloud-brain && pytest --tb=short -q
```

Expected: All tests PASS. Fix any failures before proceeding.

- [ ] **Step 8.4: Invoke `docs` subagent to update documentation**

Ask the `docs` subagent to update:
- `docs/roadmap.md` — mark Part 5 inline panels as complete
- `docs/implementation-status.md` — add entry for Part 5 completion
- `docs/screens.md` — update inline panel entries to reflect live API calls, unit awareness, and pre-fill behaviour

Provide the subagent with the plan file path and the spec file path as context.

- [ ] **Step 8.5: Commit documentation updates**

Use the `git` subagent:

```bash
git add docs/
git commit -m "docs: update roadmap and implementation status for Part 5 inline panels"
```

- [ ] **Step 8.6: Confirm branch is up to date and ready for review**

```bash
git log --oneline -10
git status
```

Expected: Clean working tree. All Part 5 commits visible in the log.
